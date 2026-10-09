#!/usr/bin/env bash
# scripts/fetch-rockchip.sh —— 拉 Rockchip 官方风格 BSP + radxa/buildroot

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_banner "fetch-source  VENDOR=$VENDOR  VARIANT=$VARIANT"

# 读 vendor 配置
BUILDROOT_REPO="$(rkb_vendor_get BUILDROOT_REPO)"
BUILDROOT_BRANCH="$(rkb_vendor_get BUILDROOT_BRANCH)"
KERNEL_REPO="$(rkb_vendor_get KERNEL_REPO)"
KERNEL_BRANCH="$(rkb_vendor_get KERNEL_BRANCH)"
UBOOT_REPO="$(rkb_vendor_get UBOOT_REPO)"
UBOOT_BRANCH="$(rkb_vendor_get UBOOT_BRANCH)"
RKBIN_REPO="$(rkb_vendor_get RKBIN_REPO)"
RKBIN_BRANCH="$(rkb_vendor_get RKBIN_BRANCH)"
MPP_REPO="$(rkb_vendor_get MPP_REPO)"
MPP_BRANCH="$(rkb_vendor_get MPP_BRANCH)"
RKNPU2_REPO="$(rkb_vendor_get RKNPU2_REPO)"
RKNPU2_BRANCH="$(rkb_vendor_get RKNPU2_BRANCH)"
TOOLCHAIN_URL="$(rkb_vendor_get TOOLCHAIN_URL)"

# 网络可达性提示
if ! rkb_network_ok github.com; then
    rkb_warn "GitHub 不可达；将尝试代理或镜像。后续 fetch 可能失败。"
fi

mkdir -p "${SRC_DIR}"

# 1) buildroot
rkb_section "buildroot → ${SRC_DIR}/buildroot"
rkb_git_clone "$BUILDROOT_REPO" "${SRC_DIR}/buildroot" "$BUILDROOT_BRANCH"

# 2) kernel
rkb_section "kernel → ${SRC_DIR}/kernel"
rkb_git_clone "$KERNEL_REPO" "${SRC_DIR}/kernel" "$KERNEL_BRANCH"

# 3) u-boot
rkb_section "u-boot → ${SRC_DIR}/u-boot"
rkb_git_clone "$UBOOT_REPO" "${SRC_DIR}/u-boot" "$UBOOT_BRANCH"

# 4) rkbin
rkb_section "rkbin → ${SRC_DIR}/rkbin"
rkb_git_clone "$RKBIN_REPO" "${SRC_DIR}/rkbin" "$RKBIN_BRANCH"

# 5) mpp
rkb_section "mpp → ${SRC_DIR}/mpp"
rkb_git_clone "$MPP_REPO" "${SRC_DIR}/mpp" "$MPP_BRANCH"

# 6) rknpu2
rkb_section "rknpu2 → ${SRC_DIR}/rknpu2"
rkb_git_clone "$RKNPU2_REPO" "${SRC_DIR}/rknpu2" "$RKNPU2_BRANCH"

# 7) toolchain
# 注：URL 可能指向 GitHub raw / Mega.nz / 直链；自动用 gh-proxy 镜像
if [[ -n "$TOOLCHAIN_URL" ]]; then
    rkb_section "toolchain"
    mkdir -p "${SRC_DIR}/prebuilts/gcc/linux-x86/aarch64"
    archive_name="$(basename "$TOOLCHAIN_URL")"
    archive_path="${SRC_DIR}/${archive_name}"
    # GitHub raw 走 gh-proxy
    fetch_url="$TOOLCHAIN_URL"
    if [[ "$fetch_url" == *"github.com"* && "$fetch_url" != *"gh-proxy.com"* ]]; then
        fetch_url="https://gh-proxy.com/${fetch_url}"
        rkb_log info "GitHub URL detected, routing via gh-proxy"
    fi
    rkb_download "$fetch_url" "$archive_path"

    # 解压：FriendlyARM tarball 是 opt/FriendlyARM/toolchain/<name>/
    # 解压到 prebuilts/gcc/linux-x86/aarch64/ 后会得到 prebuilts/gcc/linux-x86/aarch64/opt/FriendlyARM/toolchain/11.3-aarch64/
    # 故用 --strip-components 把顶层 'opt/' 砍掉，最后形成 prebuilts/gcc/linux-x86/aarch64/FriendlyARM/toolchain/11.3-aarch64/
    case "$archive_path" in
        *.tar.xz) tar -xJf "$archive_path" -C "${SRC_DIR}/prebuilts/gcc/linux-x86/aarch64/" --strip-components=1 ;;
        *.tar.bz2) tar -xjf "$archive_path" -C "${SRC_DIR}/prebuilts/gcc/linux-x86/aarch64/" --strip-components=1 ;;
        *.tar.gz) tar -xzf "$archive_path" -C "${SRC_DIR}/prebuilts/gcc/linux-x86/aarch64/" --strip-components=1 ;;
        *) rkb_warn "未知的 toolchain 压缩格式：$archive_path" ;;
    esac

    # 验证
    if [[ -d "${SRC_DIR}/prebuilts/gcc/linux-x86/aarch64/FriendlyARM/toolchain" ]]; then
        rkb_ok "toolchain 解压成功（FriendlyARM 布局）"
    else
        rkb_log info "解压后目录："
        ls -la "${SRC_DIR}/prebuilts/gcc/linux-x86/aarch64/" | head
    fi
fi

# 8) 应用 overlay（写入 buildroot 工作树）
# shellcheck disable=SC1090
bash "${SCRIPTS_DIR}/apply-overlay.sh"

rkb_ok "fetch-source 完成。请执行 'make defconfig' 再 'make build'"