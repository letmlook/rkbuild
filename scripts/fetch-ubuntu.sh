#!/usr/bin/env bash
# scripts/fetch-ubuntu.sh —— 拉取 Rockchip 官方 Ubuntu 22.04 构建所需源码
#
# 与 Buildroot 流程独立：
#   - Rockchip BSP kernel（rockchip-linux/kernel）
#   - rkbin（DDR init / BL31）
#   - mainline U-Boot（用于 GPT + extlinux 启动 Ubuntu）
#   - mpp / rknpu2（SDK 的 external/ 与运行时）
#   - Ubuntu Base 22.04 arm64 tarball
#   - FriendlyARM GCC 11.3 aarch64 工具链（glibc 2.35，与 jammy 匹配）
#
# 仅支持 VENDOR=rockchip；其他 vendor 暂不提供 Ubuntu 支持。

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_ubuntu_assert
rkb_banner "fetch-ubuntu  VENDOR=$VENDOR  ROOTFS=$ROOTFS  BOARD=$BOARD"

KERNEL_REPO="$(rkb_vendor_get KERNEL_REPO)"
KERNEL_BRANCH="$(rkb_vendor_get KERNEL_BRANCH)"
RKBIN_REPO="$(rkb_vendor_get RKBIN_REPO)"
RKBIN_BRANCH="$(rkb_vendor_get RKBIN_BRANCH)"
MPP_REPO="$(rkb_vendor_get MPP_REPO)"
MPP_BRANCH="$(rkb_vendor_get MPP_BRANCH)"
RKNPU2_REPO="$(rkb_vendor_get RKNPU2_REPO)"
RKNPU2_BRANCH="$(rkb_vendor_get RKNPU2_BRANCH)"
TOOLCHAIN_URL="$(rkb_vendor_get TOOLCHAIN_URL)"
TOOLCHAIN_DIRNAME="$(rkb_vendor_get TOOLCHAIN_DIRNAME)"
UBUNTU_UBOOT_REPO="$(rkb_ubuntu_vendor_get UBUNTU_UBOOT_REPO)"
UBUNTU_UBOOT_BRANCH="$(rkb_ubuntu_vendor_get UBUNTU_UBOOT_BRANCH)"
UBUNTU_BASE_URL="$(rkb_ubuntu_base_url)"
UBUNTU_BASE_SHA256="$(rkb_ubuntu_vendor_get UBUNTU_BASE_SHA256)"

[[ -n "$TOOLCHAIN_DIRNAME" ]] || TOOLCHAIN_DIRNAME="11.3-aarch64"
[[ -n "$UBUNTU_UBOOT_REPO" ]] || rkb_die "vendors/rockchip.ini 未配置 UBUNTU_UBOOT_REPO"
[[ -n "$UBUNTU_UBOOT_BRANCH" ]] || rkb_die "vendors/rockchip.ini 未配置 UBUNTU_UBOOT_BRANCH"
[[ -n "$UBUNTU_BASE_URL" ]] || rkb_die "vendors/rockchip.ini 未配置 UBUNTU_BASE_URL"

if ! rkb_network_ok github.com; then
    rkb_warn "GitHub 不可达；将尝试镜像。若失败请配置代理后重试。"
fi
if ! rkb_network_ok ports.ubuntu.com; then
    rkb_warn "ports.ubuntu.com 不可达；构造 rootfs 时 apt 可能失败。可在 vendors/rockchip.ini 改 UBUNTU_PORTS_MIRROR。"
fi

mkdir -p "$UBUNTU_SRC_DIR" "$UBUNTU_DL_DIR" "$UBUNTU_WORK"

# git clone，GitHub 直连失败时自动走 gh-proxy
rkb_ubuntu_git_clone() {
    local url="$1" dst="$2" branch="$3"
    if [[ -d "$dst" ]]; then
        rkb_log info "已存在：$dst（跳过 clone）"
        return 0
    fi
    if rkb_git_clone "$url" "$dst" "$branch"; then
        return 0
    fi
    if [[ "$url" == *"github.com"* && "$url" != *"gh-proxy.com"* ]]; then
        rkb_warn "直连克隆失败，改用 gh-proxy 重试：$url"
        rm -rf "$dst"
        rkb_git_clone "https://gh-proxy.com/${url}" "$dst" "$branch"
    else
        rkb_die "git clone 失败：$url"
    fi
}

# 1) kernel / rkbin / mpp / rknpu2
rkb_section "kernel → ${UBUNTU_SRC_DIR}/kernel"
rkb_ubuntu_git_clone "$KERNEL_REPO" "${UBUNTU_SRC_DIR}/kernel" "$KERNEL_BRANCH"

rkb_section "rkbin → ${UBUNTU_SRC_DIR}/rkbin"
rkb_ubuntu_git_clone "$RKBIN_REPO" "${UBUNTU_SRC_DIR}/rkbin" "$RKBIN_BRANCH"

rkb_section "mpp → ${UBUNTU_SRC_DIR}/mpp"
rkb_ubuntu_git_clone "$MPP_REPO" "${UBUNTU_SRC_DIR}/mpp" "$MPP_BRANCH"

rkb_section "rknpu2 → ${UBUNTU_SRC_DIR}/rknpu2"
rkb_ubuntu_git_clone "$RKNPU2_REPO" "${UBUNTU_SRC_DIR}/rknpu2" "$RKNPU2_BRANCH"

# 2) mainline U-Boot（固定 tag，保证 generic-rk3588 + bootstd/extlinux 可用）
rkb_section "u-boot(mainline) → ${UBUNTU_SRC_DIR}/u-boot-mainline"
rkb_ubuntu_git_clone "$UBUNTU_UBOOT_REPO" "${UBUNTU_SRC_DIR}/u-boot-mainline" "$UBUNTU_UBOOT_BRANCH"

# 3) Ubuntu Base（带 SHA256 校验）
rkb_section "Ubuntu Base $(rkb_ubuntu_version) arm64"
base_tarball="$(rkb_ubuntu_base_tarball)"
rkb_download "$UBUNTU_BASE_URL" "$base_tarball" "$UBUNTU_BASE_SHA256"
rkb_ok "Ubuntu Base 已就绪：${base_tarball}"

# 4) 交叉工具链
rkb_section "toolchain (${TOOLCHAIN_DIRNAME})"
mkdir -p "${UBUNTU_SRC_DIR}/prebuilts/gcc/linux-x86/aarch64"
toolchain_root="${UBUNTU_SRC_DIR}/prebuilts/gcc/linux-x86/aarch64"
toolchain_dir="${toolchain_root}/FriendlyARM/toolchain/${TOOLCHAIN_DIRNAME}"
archive_name="$(basename "$TOOLCHAIN_URL")"
archive_path="${UBUNTU_DL_DIR}/${archive_name}"

if [[ ! -x "${toolchain_dir}/bin/aarch64-cortexa53-linux-gnu-gcc" ]]; then
    fetch_url="$TOOLCHAIN_URL"
    if [[ "$fetch_url" == *"github.com"* && "$fetch_url" != *"gh-proxy.com"* ]]; then
        fetch_url="https://gh-proxy.com/${fetch_url}"
        rkb_log info "GitHub 工具链 URL 走 gh-proxy"
    fi
    # 校验已有压缩包；损坏则重下
    if [[ -f "$archive_path" ]] && ! tar -tJf "$archive_path" >/dev/null 2>&1; then
        rkb_warn "工具链压缩包损坏，重新下载"
        rm -f "$archive_path"
    fi
    rkb_download "$fetch_url" "$archive_path"
    rkb_log info "解压工具链到 ${toolchain_root}"
    tar -xJf "$archive_path" -C "$toolchain_root" --strip-components=1
fi

[[ -x "${toolchain_dir}/bin/aarch64-cortexa53-linux-gnu-gcc" ]] \
    || rkb_die "工具链解压后未找到 gcc：${toolchain_dir}/bin/aarch64-cortexa53-linux-gnu-gcc"
"${toolchain_dir}/bin/aarch64-cortexa53-linux-gnu-gcc" --version | head -1
rkb_ok "工具链就绪：${toolchain_dir}"

# 5) 校验板级配置
rkb_ubuntu_board_ini >/dev/null
rkb_log info "板级 DTB     : $(rkb_ubuntu_board_get KERNEL_DTB)"
rkb_log info "U-Boot defconfig: $(rkb_ubuntu_board_get UBOOT_DEFCONFIG)"
rkb_log info "U-Boot TPL   : $(rkb_ubuntu_uboot_tpl)"
rkb_log info "U-Boot BL31  : $(rkb_ubuntu_uboot_bl31)"

rkb_ok "fetch-ubuntu 完成。下一步：make build ROOTFS=ubuntu VARIANT=${VARIANT}"
