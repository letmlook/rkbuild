#!/usr/bin/env bash
# scripts/ubuntu-build.sh —— 编译 Rockchip 官方 Ubuntu 22.04 镜像组件
#
# 产出（dist/ubuntu/）：
#   kernel/            kernel build tree（O=）
#   u-boot/            U-Boot build tree（O=）
#   images/Image       内核
#   images/<dtb>       板级 DTB
#   images/u-boot-rockchip.bin / idbloader.img / u-boot.itb
#   rootfs/            Ubuntu 22.04 rootfs 目录
#
# 之后用 make image ROOTFS=ubuntu 生成可烧写 SD 卡镜像。
#
# 仅支持 VENDOR=rockchip。

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_ubuntu_assert
rkb_ubuntu_require_root "$@"
rkb_ubuntu_check_host

ROOTFS_DIR="${UBUNTU_WORK}/rootfs"
KOUT="${UBUNTU_WORK}/kernel"
UB_OUT="${UBUNTU_WORK}/u-boot"
IMAGES_DIR="${UBUNTU_WORK}/images"
ROOTFS_STAMP="${UBUNTU_WORK}/.rootfs-ready"
KREL=""

KERNEL_SRC="$(rkb_ubuntu_kernel_source)"
UBOOT_SRC="$(rkb_ubuntu_uboot_source)"
RKBIN_DIR="$(rkb_ubuntu_rkbin_dir)"
CROSS="$(rkb_ubuntu_cross_compile)"
KERNEL_DEFCONFIG="$(rkb_ubuntu_board_get KERNEL_DEFCONFIG)"
KERNEL_DTB="$(rkb_ubuntu_board_get KERNEL_DTB)"
UBOOT_DEFCONFIG="$(rkb_ubuntu_board_get UBOOT_DEFCONFIG)"
UBUNTU_CONSOLE="$(rkb_ubuntu_board_get UBUNTU_CONSOLE)"
[[ -n "$KERNEL_DEFCONFIG" ]] || rkb_die "板级配置缺少 KERNEL_DEFCONFIG"
[[ -n "$KERNEL_DTB" ]] || rkb_die "板级配置缺少 KERNEL_DTB"
[[ -n "$UBOOT_DEFCONFIG" ]] || rkb_die "板级配置缺少 UBOOT_DEFCONFIG"
[[ -n "$UBUNTU_CONSOLE" ]] || UBUNTU_CONSOLE="ttyS2,1500000n8"

UBUNTU_USER="${UBUNTU_USER:-rkbuild}"
UBUNTU_PASSWORD="${UBUNTU_PASSWORD:-rkbuild}"
UBUNTU_TZ="${UBUNTU_TZ:-UTC}"
UBUNTU_HOSTNAME="${UBUNTU_HOSTNAME:-rk3588-ubuntu-${VARIANT}}"
UBUNTU_ROOTFS_REUSE="${UBUNTU_ROOTFS_REUSE:-0}"

rkb_banner "ubuntu-build  VENDOR=$VENDOR  ROOTFS=$ROOTFS  VARIANT=$VARIANT  BOARD=$BOARD"

# ---- 依赖检查 ----
rkb_require_dir "$KERNEL_SRC"
rkb_require_dir "$UBOOT_SRC"
rkb_require_dir "$RKBIN_DIR"
[[ -x "${CROSS}gcc" ]] || rkb_die "交叉工具链不可执行：${CROSS}gcc（先 make fetch ROOTFS=ubuntu）"
[[ -f "$(rkb_ubuntu_base_tarball)" ]] || rkb_die "Ubuntu Base 未下载（先 make fetch ROOTFS=ubuntu）"

mkdir -p "$UBUNTU_WORK" "$KOUT" "$UB_OUT" "$IMAGES_DIR"

cleanup() {
    local rc=$?
    if [[ -d "$ROOTFS_DIR" ]]; then
        rkb_ubuntu_umount_rootfs "$ROOTFS_DIR" 2>/dev/null || true
    fi
    if (( rc != 0 )); then
        rkb_log error "ubuntu-build 失败 rc=$rc"
    fi
}
trap cleanup EXIT INT TERM

# ===========================================================================
# 1) 内核
# ===========================================================================
rkb_section "内核：${KERNEL_SRC} (${KERNEL_DEFCONFIG})"
KCONFIG_STAMP="${KOUT}/.rkbuild-defconfig"
if [[ ! -f "${KOUT}/.config" || "$(cat "$KCONFIG_STAMP" 2>/dev/null)" != "$KERNEL_DEFCONFIG" ]]; then
    rkb_log info "生成内核 .config（$KERNEL_DEFCONFIG）"
    make -C "$KERNEL_SRC" O="$KOUT" ARCH=arm64 CROSS_COMPILE="$CROSS" \
        "$KERNEL_DEFCONFIG"
    # 先追加板级/Ubuntu 启动选项，再追加 Docker 内核选项；重复项由 olddefconfig 合并
    cat "${RKB_ROOT}/ubuntu/kernel-fragment.config" >> "${KOUT}/.config"
    cat "${RKB_ROOT}/overlay/fragments/rkbuild_docker_kernel.config" >> "${KOUT}/.config"
    printf '%s\n' "$KERNEL_DEFCONFIG" > "$KCONFIG_STAMP"
fi
make -C "$KERNEL_SRC" O="$KOUT" ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig

KREL="$(rkb_ubuntu_kernelrelease "$KOUT" "$KERNEL_SRC")"
[[ -n "$KREL" ]] || rkb_die "无法取得内核版本（kernelrelease 为空）"
rkb_log info "内核版本：$KREL；开始编译 Image/dtbs/modules（-j${JOBS}）"

make -C "$KERNEL_SRC" O="$KOUT" ARCH=arm64 CROSS_COMPILE="$CROSS" \
    -j"$JOBS" Image dtbs modules

KERNEL_IMAGE="${KOUT}/arch/arm64/boot/Image"
KERNEL_DTB_PATH="${KOUT}/arch/arm64/boot/dts/rockchip/${KERNEL_DTB}"
[[ -f "$KERNEL_IMAGE" ]] || rkb_die "内核 Image 不存在：$KERNEL_IMAGE"
[[ -f "$KERNEL_DTB_PATH" ]] || rkb_die "DTB 不存在：$KERNEL_DTB_PATH
可用 DTB 示例：
$(find "${KOUT}/arch/arm64/boot/dts/rockchip/" -maxdepth 1 -name '*.dtb' -printf '%f\n' 2>/dev/null | head -20)"

install -m 0644 "$KERNEL_IMAGE" "${IMAGES_DIR}/Image"
install -m 0644 "$KERNEL_DTB_PATH" "${IMAGES_DIR}/${KERNEL_DTB}"
install -m 0644 "${KOUT}/System.map" "${IMAGES_DIR}/System.map"
install -m 0644 "${KOUT}/.config" "${IMAGES_DIR}/kernel.config"
rkb_ok "内核编译完成：${IMAGES_DIR}/Image + ${KERNEL_DTB}"

# ===========================================================================
# 2) Ubuntu rootfs
# ===========================================================================
if [[ "$UBUNTU_ROOTFS_REUSE" == "1" && -d "$ROOTFS_DIR" && -f "$ROOTFS_STAMP" ]]; then
    rkb_section "复用已有 Ubuntu rootfs：$ROOTFS_DIR"
else
    rkb_section "准备 Ubuntu $(rkb_ubuntu_version) rootfs（qemu-user chroot）"
    rkb_ubuntu_extract_base "$ROOTFS_DIR"
    rkb_ubuntu_write_apt_sources "$ROOTFS_DIR"

    mapfile -t UBUNTU_PKGS < <(rkb_ubuntu_package_list "$VARIANT")
    rkb_log info "软件包数量：${#UBUNTU_PKGS[@]}（variant=${VARIANT}）"
    rkb_ubuntu_apt_update_and_install "$ROOTFS_DIR" "${UBUNTU_PKGS[@]}"
    touch "$ROOTFS_STAMP"
fi

# 2.1 内核模块（每次 build 都同步，保证与 Image 匹配）
rkb_section "安装内核模块到 rootfs（$KREL）"
make -C "$KERNEL_SRC" O="$KOUT" ARCH=arm64 CROSS_COMPILE="$CROSS" \
    INSTALL_MOD_PATH="$ROOTFS_DIR" INSTALL_MOD_STRIP=1 \
    -j"$JOBS" modules_install
# modules_install 的 build/source 指向宿主构建目录，目标机上无意义且会泄露路径
rm -f "${ROOTFS_DIR}/lib/modules/${KREL}/build" \
      "${ROOTFS_DIR}/lib/modules/${KREL}/source"
depmod -b "$ROOTFS_DIR" "$KREL"
rkb_ok "内核模块安装完成：${ROOTFS_DIR}/lib/modules/${KREL}"

# 2.2 内核镜像与 System.map 放进 rootfs /boot（便于板端查阅）
mkdir -p "${ROOTFS_DIR}/boot"
install -m 0644 "$KERNEL_IMAGE" "${ROOTFS_DIR}/boot/Image"
install -m 0644 "$KERNEL_DTB_PATH" "${ROOTFS_DIR}/boot/${KERNEL_DTB}"
install -m 0644 "${KOUT}/System.map" "${ROOTFS_DIR}/boot/System.map-${KREL}"
install -m 0644 "${KOUT}/.config" "${ROOTFS_DIR}/boot/config-${KREL}"

# 2.3 叠加 rkbuild 配置
rkb_section "应用 Ubuntu rootfs overlay"
rsync -a "${UBUNTU_OVERLAY_DIR}/" "${ROOTFS_DIR}/"
chmod 0755 "${ROOTFS_DIR}/usr/local/bin/rkbuild-info" \
           "${ROOTFS_DIR}/etc/update-motd.d/99-rkbuild" \
           "${ROOTFS_DIR}/etc/profile.d/rkbuild.sh"

# 2.4 RKNN runtime（rknpu2 仓库内的 aarch64 librknnrt.so + 头文件）
rkb_section "安装 RKNN runtime"
RKNN_LIB="$(find "${UBUNTU_SRC_DIR}/rknpu2" -path '*aarch64/librknnrt.so' -type f 2>/dev/null | head -1 || true)"
RKNN_INC_DIR="$(find "${UBUNTU_SRC_DIR}/rknpu2" -name rknn_api.h -type f 2>/dev/null | head -1 || true)"
if [[ -n "$RKNN_LIB" ]]; then
    install -m 0755 "$RKNN_LIB" "${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/librknnrt.so"
    if [[ -n "$RKNN_INC_DIR" ]]; then
        mkdir -p "${ROOTFS_DIR}/usr/include/rknn"
        install -m 0644 "$(dirname "$RKNN_INC_DIR")"/*.h "${ROOTFS_DIR}/usr/include/rknn/" 2>/dev/null || true
    fi
    rkb_ok "RKNN runtime 已安装（$(basename "$RKNN_LIB")）"
else
    rkb_warn "rknpu2 中未找到 librknnrt.so；跳过 RKNN runtime"
fi

# 2.5 系统配置（chroot）
rkb_section "配置 Ubuntu 系统（用户 / 网络 / systemd / Docker）"
rkb_ubuntu_mount_rootfs "$ROOTFS_DIR"
rkb_ubuntu_install_qemu "$ROOTFS_DIR"
rkb_ubuntu_write_policy_rc "$ROOTFS_DIR"

# hostname / hosts
printf '%s\n' "$UBUNTU_HOSTNAME" > "${ROOTFS_DIR}/etc/hostname"
cat > "${ROOTFS_DIR}/etc/hosts" <<EOF
127.0.0.1       localhost
127.0.1.1       ${UBUNTU_HOSTNAME}
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# fstab：rootfs 使用 GPT 分区标签（PARTLABEL），SD/eMMC 设备名变化不受影响；
# 注意内核无 initramfs 时不支持 root=LABEL=，必须使用 PARTLABEL/PARTUUID。
cat > "${ROOTFS_DIR}/etc/fstab" <<EOF
# <file system>                 <mount point>  <type>  <options>          <dump> <pass>
PARTLABEL=rootfs                /              ext4    defaults,noatime   0      1
EOF

# 时区 / locale
ln -sfn "/usr/share/zoneinfo/${UBUNTU_TZ}" "${ROOTFS_DIR}/etc/localtime"
printf '%s\n' "$UBUNTU_TZ" > "${ROOTFS_DIR}/etc/timezone"
printf 'LANG=C.UTF-8\n' > "${ROOTFS_DIR}/etc/default/locale"
rkb_ubuntu_chroot "$ROOTFS_DIR" locale-gen en_US.UTF-8 zh_CN.UTF-8 >/dev/null 2>&1 || true

# 默认用户与密码（开发镜像；文档要求首次登录修改）
if ! rkb_ubuntu_chroot "$ROOTFS_DIR" id "$UBUNTU_USER" >/dev/null 2>&1; then
    rkb_ubuntu_chroot "$ROOTFS_DIR" useradd -m -s /bin/bash -c "rkbuild user" "$UBUNTU_USER"
fi
# 常用外设组（Ubuntu 默认可能不存在）
for g in gpio i2c spi; do
    rkb_ubuntu_chroot "$ROOTFS_DIR" getent group "$g" >/dev/null 2>&1 \
        || rkb_ubuntu_chroot "$ROOTFS_DIR" groupadd "$g"
done
rkb_ubuntu_chroot "$ROOTFS_DIR" usermod -aG sudo,docker,video,render,dialout,plugdev,gpio,i2c,spi "$UBUNTU_USER" 2>/dev/null \
    || rkb_ubuntu_chroot "$ROOTFS_DIR" usermod -aG sudo,docker,video,render,dialout,plugdev "$UBUNTU_USER"
printf '%s:%s\n' "$UBUNTU_USER" "$UBUNTU_PASSWORD" | rkb_ubuntu_chroot "$ROOTFS_DIR" chpasswd
printf 'root:%s\n' "$UBUNTU_PASSWORD" | rkb_ubuntu_chroot "$ROOTFS_DIR" chpasswd

cat > "${ROOTFS_DIR}/etc/sudoers.d/90-rkbuild" <<EOF
${UBUNTU_USER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "${ROOTFS_DIR}/etc/sudoers.d/90-rkbuild"

# systemd 服务
rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl enable NetworkManager >/dev/null 2>&1 || true
rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl enable systemd-resolved >/dev/null 2>&1 || true
rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl enable ssh >/dev/null 2>&1 || true
rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl enable docker >/dev/null 2>&1 || true
rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl enable containerd >/dev/null 2>&1 || true
rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl enable apparmor >/dev/null 2>&1 || true
rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl enable "serial-getty@${UBUNTU_CONSOLE%%,*}.service" >/dev/null 2>&1 || true

if [[ "$VARIANT" == "gui" ]]; then
    rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl set-default graphical.target >/dev/null 2>&1 || true
    rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl enable lightdm >/dev/null 2>&1 || true
else
    rkb_ubuntu_chroot "$ROOTFS_DIR" systemctl set-default multi-user.target >/dev/null 2>&1 || true
fi

# 网络（netplan 在首次启动时应用；这里生成一次便于检查）
rkb_ubuntu_chroot "$ROOTFS_DIR" netplan generate >/dev/null 2>&1 || true

# rkbuild release / motd
RELEASE_LINE="rkbuild $(cat "${RKB_ROOT}/VERSION") (${VENDOR}/ubuntu-$(rkb_ubuntu_version)/${VARIANT}/${BOARD})"
printf '%s\n' "$RELEASE_LINE" > "${ROOTFS_DIR}/etc/rkbuild-release"
sed -i \
    -e "s|__VENDOR__|${VENDOR}|g" \
    -e "s|__VARIANT__|${VARIANT}|g" \
    -e "s|__BOARD__|${BOARD}|g" \
    -e "s|__RKBUILD_RELEASE__|${RELEASE_LINE}|g" \
    "${ROOTFS_DIR}/etc/update-motd.d/99-rkbuild"

# 删除构建期临时文件
rm -f "${ROOTFS_DIR}/usr/sbin/policy-rc.d"
rkb_ubuntu_umount_rootfs "$ROOTFS_DIR"
rkb_ok "Ubuntu 系统配置完成"

# ===========================================================================
# 3) U-Boot（mainline + bootstd/extlinux）
# ===========================================================================
rkb_section "U-Boot：${UBOOT_DEFCONFIG}（mainline）"
UBOOT_STAMP="${UB_OUT}/.rkbuild-defconfig"
if [[ ! -f "${UB_OUT}/.config" || "$(cat "$UBOOT_STAMP" 2>/dev/null)" != "$UBOOT_DEFCONFIG" ]]; then
    make -C "$UBOOT_SRC" O="$UB_OUT" CROSS_COMPILE="$CROSS" "$UBOOT_DEFCONFIG"
    printf '%s\n' "$UBOOT_DEFCONFIG" > "$UBOOT_STAMP"
fi
make -C "$UBOOT_SRC" O="$UB_OUT" CROSS_COMPILE="$CROSS" olddefconfig

UBOOT_TPL="$(rkb_ubuntu_uboot_tpl)"
UBOOT_BL31="$(rkb_ubuntu_uboot_bl31)"
rkb_log info "ROCKCHIP_TPL=$UBOOT_TPL"
rkb_log info "BL31=$UBOOT_BL31"

make -C "$UBOOT_SRC" O="$UB_OUT" CROSS_COMPILE="$CROSS" \
    -j"$JOBS" BL31="$UBOOT_BL31" ROCKCHIP_TPL="$UBOOT_TPL"

for f in u-boot-rockchip.bin idbloader.img u-boot.itb; do
    if [[ -f "${UB_OUT}/${f}" ]]; then
        install -m 0644 "${UB_OUT}/${f}" "${IMAGES_DIR}/${f}"
    fi
done
[[ -f "${IMAGES_DIR}/u-boot-rockchip.bin" ]] || rkb_die "U-Boot 未生成 u-boot-rockchip.bin"
rkb_ok "U-Boot 编译完成：${IMAGES_DIR}/u-boot-rockchip.bin"

# ===========================================================================
# 4) 收尾
# ===========================================================================
rkb_section "清理 rootfs 构建痕迹"
rkb_ubuntu_finalize_rootfs "$ROOTFS_DIR"

cat > "${UBUNTU_WORK}/build-info.txt" <<EOF
rkbuild        : $(cat "${RKB_ROOT}/VERSION")
vendor         : ${VENDOR}
rootfs         : ubuntu $(rkb_ubuntu_version) ($(rkb_ubuntu_series))
variant        : ${VARIANT}
board          : ${BOARD}
kernel         : ${KREL}
kernel dtb     : ${KERNEL_DTB}
u-boot         : mainline ${UBUNTU_UBOOT_BRANCH:-$(rkb_ubuntu_vendor_get UBUNTU_UBOOT_BRANCH)}
u-boot config  : ${UBOOT_DEFCONFIG}
u-boot tpl     : $(basename "$UBOOT_TPL")
u-boot bl31    : $(basename "$UBOOT_BL31")
built at       : $(date -Iseconds)
EOF

rkb_ok "ubuntu-build 完成。下一步：make image ROOTFS=ubuntu VARIANT=${VARIANT}"
