#!/usr/bin/env bash
# scripts/mk-sd-image.sh —— 生成可烧写 SD 卡镜像
#
# 仿 sd-fuse_rk3588 风格：
#   1) 收集 buildroot 输出（u-boot.itb / boot.img / rootfs.ext4）
#   2) 写 parameter.txt（分区表）
#   3) 用 mkfs.ext4 出 rootfs.img
#   4) 用 truncate + cat 拼成完整 SD 卡镜像
#   5) 压缩为 .img.xz + sha256

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_banner "mk-sd-image  VENDOR=$VENDOR  VARIANT=$VARIANT"

IMG_OUT="${OUTPUT}/images"
mkdir -p "$IMG_OUT"
DATE="$(date +%Y%m%d)"

# 找到 buildroot 的 output 目录（按 vendor/variant 命名）
BR_OUTPUT_DIR="${OUTPUT}/rk3588-${VARIANT}"
[[ -d "$BR_OUTPUT_DIR" ]] || rkb_die "Buildroot 输出不存在：$BR_OUTPUT_DIR（先 make build）"

IMAGES_DIR="${BR_OUTPUT_DIR}/images"
[[ -d "$IMAGES_DIR" ]] || rkb_die "Buildroot images 目录不存在：$IMAGES_DIR"

# 收集镜像文件
rkb_section "收集镜像文件"
UBOOT_ITB="$(ls "$IMAGES_DIR"/u-boot.itb 2>/dev/null | head -1)"
BOOT_IMG="$(ls "$IMAGES_DIR"/boot.img 2>/dev/null | head -1)"
ROOTFS_IMG="$(ls "$IMAGES_DIR"/rootfs.ext4 2>/dev/null | head -1)"
[[ -n "$ROOTFS_IMG" ]] || rkb_die "找不到 rootfs.ext4"

rkb_log info "  u-boot:  ${UBOOT_ITB:-<missing>}"
rkb_log info "  boot:    ${BOOT_IMG:-<missing>}"
rkb_log info "  rootfs:  ${ROOTFS_IMG}"

# parameter.txt
rkb_section "生成 parameter.txt"
PARAM_FILE="${IMG_OUT}/parameter-${VARIANT}.txt"
cat > "$PARAM_FILE" <<EOF
FIRMWARE_VER: $(cat "${RKB_ROOT}/VERSION")
MACHINE_MODEL: RK3588-${VARIANT}
MACHINE_ID: 007
MANUFACTURER: rkbuild
MAGIC: 0x5041524B
ATAG: 0x00200800
MACHINE: 0xffffffff
CHECK_MASK: 0x80
PWR_HOLD: 0
# Format: id start_sec size_sec
# 0:uboot, 1:boot, 2:rootfs, 3:oem, 4:userdata
CMDLINE: mtdparts=rk3588-nor0:0x800000@0x0(uboot),0x100000@0x800000(boot)
EOF

# SD 卡镜像
rkb_section "拼接 SD 卡镜像"
SD_RAW="${IMG_OUT}/rk3588-${VARIANT}-raw-${DATE}.img"
SD_XZ="${IMG_OUT}/rk3588-${VARIANT}-sd-${DATE}.img.xz"

# 估算大小：rootfs + 256MB headroom
ROOTFS_BYTES="$(stat -c%s "$ROOTFS_IMG")"
TOTAL_BYTES=$(( ROOTFS_BYTES + 256 * 1024 * 1024 ))

truncate -s "$TOTAL_BYTES" "$SD_RAW"

# 写入分区表（sector 0..63，预留）
dd if=/dev/zero of="$SD_RAW" bs=512 count=64 conv=notrunc status=none

# 写入 rootfs（offset 0x800000 = 8 MiB）
dd if="$ROOTFS_IMG" of="$SD_RAW" bs=1M seek=8 conv=notrunc status=none

# 可选：写入 boot.img
if [[ -n "$BOOT_IMG" ]]; then
    dd if="$BOOT_IMG" of="$SD_RAW" bs=1M seek=4 conv=notrunc status=none
fi

# 可选：写入 u-boot
if [[ -n "$UBOOT_ITB" ]]; then
    dd if="$UBOOT_ITB" of="$SD_RAW" bs=1M seek=0 conv=notrunc status=none
fi

# 压缩
rkb_section "压缩为 .img.xz"
xz -T"${JOBS}" -9 "$SD_RAW" -c > "$SD_XZ"
rm -f "$SD_RAW"

sha256sum "$SD_XZ" > "${SD_XZ}.sha256"

rkb_ok "SD 镜像：${SD_XZ}"
rkb_log info "SHA256：$(cat "${SD_XZ}.sha256")"
rkb_log info "烧写：sudo xzcat ${SD_XZ} | dd of=/dev/sdX bs=4M status=progress"