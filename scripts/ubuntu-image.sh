#!/usr/bin/env bash
# scripts/ubuntu-image.sh —— 把 Ubuntu rootfs + kernel + U-Boot 打包成可烧写 SD 镜像
#
# 镜像布局（GPT）：
#   32 KiB        idbloader + U-Boot（u-boot-rockchip.bin）
#   16 MiB        boot 分区（FAT32，128 MiB）：Image + DTB + extlinux/extlinux.conf
#   144 MiB       rootfs 分区（ext4，PARTLABEL=rootfs）
#
# 启动链：RK3588 BootROM -> idbloader -> U-Boot -> bootstd/extlinux -> Linux
#
# 产出：
#   dist/ubuntu/images/rootfs.ext4
#   dist/ubuntu/images/boot.vfat
#   dist/images/rk3588-ubuntu-<variant>-sd-<date>.img.xz (+ .sha256)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_ubuntu_assert
rkb_ubuntu_require_root "$@"

ROOTFS_DIR="${UBUNTU_WORK}/rootfs"
IMAGES_DIR="${UBUNTU_WORK}/images"
OUT_IMAGES="${OUTPUT}/images"
DATE="$(date +%Y%m%d)"

KERNEL_DTB="$(rkb_ubuntu_board_get KERNEL_DTB)"
UBUNTU_CONSOLE="$(rkb_ubuntu_board_get UBUNTU_CONSOLE)"
[[ -n "$UBUNTU_CONSOLE" ]] || UBUNTU_CONSOLE="ttyS2,1500000n8"

BOOT_PART_MB=128
BOOT_START_MB=16
ROOT_START_MB=$(( BOOT_START_MB + BOOT_PART_MB ))

rkb_banner "ubuntu-image  VENDOR=$VENDOR  ROOTFS=$ROOTFS  VARIANT=$VARIANT  BOARD=$BOARD"

rkb_require_dir "$ROOTFS_DIR"
rkb_require_file "${IMAGES_DIR}/Image"
rkb_require_file "${IMAGES_DIR}/${KERNEL_DTB}"
rkb_require_file "${IMAGES_DIR}/u-boot-rockchip.bin"
rkb_require_cmd mke2fs
rkb_require_cmd mkfs.vfat
rkb_require_cmd mcopy
rkb_require_cmd mmd
rkb_require_cmd parted
rkb_require_cmd xz

mkdir -p "$OUT_IMAGES" "$IMAGES_DIR"

# ---------------------------------------------------------------------------
# 1) rootfs.ext4
# ---------------------------------------------------------------------------
ROOTFS_USED_MB="$(du -sm "$ROOTFS_DIR" | awk '{print $1}')"
ROOTFS_MB=$(( ROOTFS_USED_MB + 512 ))
(( ROOTFS_MB < 2048 )) && ROOTFS_MB=2048
ROOTFS_MB=$(( (ROOTFS_MB + 63) / 64 * 64 ))   # 对齐到 64 MiB
ROOTFS_IMG="${IMAGES_DIR}/rootfs.ext4"

rkb_section "生成 rootfs.ext4（${ROOTFS_MB} MiB，已用 ${ROOTFS_USED_MB} MiB）"
rm -f "$ROOTFS_IMG"
truncate -s "${ROOTFS_MB}M" "$ROOTFS_IMG"
# -d 直接在宿主编目内容，无需 loop mount；禁用 U-Boot 可能不识别的元数据特性
# （部分 e2fsprogs 版本不认识 orphan_file，逐级回退）
if ! mke2fs -q -t ext4 -F -L rkbuild-rootfs \
        -O ^metadata_csum_seed,^orphan_file \
        -d "$ROOTFS_DIR" "$ROOTFS_IMG" 2>/dev/null; then
    if ! mke2fs -q -t ext4 -F -L rkbuild-rootfs \
            -O ^metadata_csum_seed \
            -d "$ROOTFS_DIR" "$ROOTFS_IMG" 2>/dev/null; then
        rkb_warn "当前 mke2fs 不支持禁用 metadata_csum_seed；使用默认 ext4 特性"
        mke2fs -q -t ext4 -F -L rkbuild-rootfs -d "$ROOTFS_DIR" "$ROOTFS_IMG"
    fi
fi
rkb_ok "rootfs.ext4 完成"

# ---------------------------------------------------------------------------
# 2) boot.vfat（FAT32）
# ---------------------------------------------------------------------------
rkb_section "生成 boot.vfat（${BOOT_PART_MB} MiB）"
BOOT_IMG="${IMAGES_DIR}/boot.vfat"
BOOT_STAGE="${UBUNTU_WORK}/boot-partition"
rm -rf "$BOOT_STAGE"
mkdir -p "${BOOT_STAGE}/extlinux"

install -m 0644 "${IMAGES_DIR}/Image" "${BOOT_STAGE}/Image"
# boot 分区内使用固定短文件名，避免 FAT LFN/8.3 差异
install -m 0644 "${IMAGES_DIR}/${KERNEL_DTB}" "${BOOT_STAGE}/board.dtb"

CMDLINE="root=PARTLABEL=rootfs rootwait rw rootfstype=ext4 console=${UBUNTU_CONSOLE} earlycon=uart8250,mmio32,0xfeb50000 clk_ignore_unused loglevel=7 security=apparmor apparmor=1"
cat > "${BOOT_STAGE}/extlinux/extlinux.conf" <<EOF
default rkbuild
prompt 0
timeout 1
label rkbuild
    menu label rkbuild Ubuntu 22.04
    kernel /Image
    devicetree /board.dtb
    append ${CMDLINE}
EOF

rm -f "$BOOT_IMG"
truncate -s "${BOOT_PART_MB}M" "$BOOT_IMG"
mkfs.vfat -F 32 -n RKBOOT "$BOOT_IMG" >/dev/null
mmd -i "$BOOT_IMG" ::/extlinux
mcopy -i "$BOOT_IMG" "${BOOT_STAGE}/Image" ::/Image
mcopy -i "$BOOT_IMG" "${BOOT_STAGE}/board.dtb" ::/board.dtb
mcopy -i "$BOOT_IMG" "${BOOT_STAGE}/extlinux/extlinux.conf" ::/extlinux/extlinux.conf
rkb_ok "boot.vfat 完成"

# ---------------------------------------------------------------------------
# 3) SD 卡镜像
# ---------------------------------------------------------------------------
UBOOT_SIZE="$(stat -c%s "${IMAGES_DIR}/u-boot-rockchip.bin")"
MAX_UBOOT=$(( (BOOT_START_MB - 1) * 1024 * 1024 ))
(( UBOOT_SIZE < MAX_UBOOT )) || rkb_die "u-boot-rockchip.bin 超过 boot 分区前空间（${UBOOT_SIZE} >= ${MAX_UBOOT}）"

ROOTFS_BYTES="$(stat -c%s "$ROOTFS_IMG")"
TOTAL_MB=$(( ROOT_START_MB + ROOTFS_BYTES / 1024 / 1024 + 16 ))
SD_RAW="${IMAGES_DIR}/rk3588-ubuntu-${VARIANT}-sd-${DATE}.img"
SD_XZ="${OUT_IMAGES}/rk3588-ubuntu-${VARIANT}-sd-${DATE}.img.xz"

rkb_section "组装 GPT SD 镜像（${TOTAL_MB} MiB）"
rm -f "$SD_RAW" "$SD_XZ" "${SD_XZ}.sha256"
truncate -s "${TOTAL_MB}M" "$SD_RAW"

# U-Boot（idbloader + itb）写入 32 KiB
dd if="${IMAGES_DIR}/u-boot-rockchip.bin" of="$SD_RAW" bs=512 seek=64 conv=notrunc status=none

# GPT：boot 16MiB..144MiB，rootfs 144MiB..末尾
parted -s "$SD_RAW" mklabel gpt
parted -s "$SD_RAW" unit MiB \
    mkpart boot fat32 "$BOOT_START_MB" "$ROOT_START_MB" \
    set 1 esp on
parted -s "$SD_RAW" unit MiB \
    mkpart rootfs ext4 "$ROOT_START_MB" 100%
parted -s "$SD_RAW" name 1 boot
parted -s "$SD_RAW" name 2 rootfs

# 写入分区内容（不经过 loop 设备）
dd if="$BOOT_IMG" of="$SD_RAW" bs=1M seek="$BOOT_START_MB" conv=notrunc status=none
dd if="$ROOTFS_IMG" of="$SD_RAW" bs=1M seek="$ROOT_START_MB" conv=notrunc status=none

# 简单校验：GPT 分区表
rkb_section "校验镜像"
parted -s "$SD_RAW" unit MiB print

rkb_section "压缩镜像"
xz -T"${JOBS}" -6 -c "$SD_RAW" > "$SD_XZ"
rm -f "$SD_RAW"
( cd "$OUT_IMAGES" && sha256sum "$(basename "$SD_XZ")" > "$(basename "$SD_XZ").sha256" )

rkb_ok "SD 镜像：${SD_XZ}"
rkb_log info "SHA256：$(cat "${SD_XZ}.sha256")"
rkb_log info "烧写：sudo xzcat ${SD_XZ} | dd of=/dev/sdX bs=4M status=progress && sync"
rkb_log info "分区布局：U-Boot@32KiB, boot(FAT)@16MiB, rootfs(ext4,PARTLABEL=rootfs)@144MiB"
