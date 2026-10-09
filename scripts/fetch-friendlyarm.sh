#!/usr/bin/env bash
# scripts/fetch-friendlyarm.sh —— 拉 FriendlyElec 风格 BSP + radxa/buildroot + device overlay + sd-fuse

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_banner "fetch-source  VENDOR=$VENDOR  VARIANT=$VARIANT"

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
DEVICE_REPO="$(rkb_vendor_get DEVICE_REPO)"
DEVICE_BRANCH="$(rkb_vendor_get DEVICE_BRANCH)"
DEVICE_PATH="$(rkb_vendor_get DEVICE_PATH)"
SDFUSE_REPO="$(rkb_vendor_get SDFUSE_REPO)"
SDFUSE_BRANCH="$(rkb_vendor_get SDFUSE_BRANCH)"
TOOLCHAIN_URL="$(rkb_vendor_get TOOLCHAIN_URL)"

if ! rkb_network_ok github.com; then
    rkb_warn "GitHub 不可达；将尝试代理或镜像。后续 fetch 可能失败。"
fi

mkdir -p "${SRC_DIR}" "${SRC_DIR}/device" "${SRC_DIR}/sd-fuse"

# buildroot（同 rockchip 流派）
rkb_section "buildroot → ${SRC_DIR}/buildroot"
rkb_git_clone "$BUILDROOT_REPO" "${SRC_DIR}/buildroot" "$BUILDROOT_BRANCH"

# kernel / u-boot / rkbin / mpp / rknpu2（friendlyarm 自家分支）
rkb_section "kernel → ${SRC_DIR}/kernel"
rkb_git_clone "$KERNEL_REPO" "${SRC_DIR}/kernel" "$KERNEL_BRANCH"

rkb_section "u-boot → ${SRC_DIR}/u-boot"
rkb_git_clone "$UBOOT_REPO" "${SRC_DIR}/u-boot" "$UBOOT_BRANCH"

rkb_section "rkbin → ${SRC_DIR}/rkbin"
rkb_git_clone "$RKBIN_REPO" "${SRC_DIR}/rkbin" "$RKBIN_BRANCH"

rkb_section "mpp → ${SRC_DIR}/mpp"
rkb_git_clone "$MPP_REPO" "${SRC_DIR}/mpp" "$MPP_BRANCH"

rkb_section "rknpu2 → ${SRC_DIR}/rknpu2"
rkb_git_clone "$RKNPU2_REPO" "${SRC_DIR}/rknpu2" "$RKNPU2_BRANCH"

# device overlay（friendlyarm 用作 BR2_ROOTFS_OVERLAY）
if [[ -n "$DEVICE_REPO" && -n "$DEVICE_PATH" ]]; then
    rkb_section "device overlay → ${SRC_DIR}/${DEVICE_PATH}"
    rkb_git_clone "$DEVICE_REPO" "${SRC_DIR}/${DEVICE_PATH}" "$DEVICE_BRANCH"
fi

# sd-fuse 工具（可选，用于打 SD 卡镜像）
if [[ -n "$SDFUSE_REPO" ]]; then
    rkb_section "sd-fuse → ${SRC_DIR}/sd-fuse"
    rkb_git_clone "$SDFUSE_REPO" "${SRC_DIR}/sd-fuse" "$SDFUSE_BRANCH"
fi

# toolchain
if [[ -n "$TOOLCHAIN_URL" ]]; then
    rkb_section "toolchain"
    mkdir -p "${SRC_DIR}/prebuilts/gcc/linux-x86/aarch64"
    archive_name="$(basename "$TOOLCHAIN_URL")"
    rkb_download "$TOOLCHAIN_URL" "${SRC_DIR}/${archive_name}"
    if ! ls "${SRC_DIR}/prebuilts/gcc/linux-x86/aarch64"/gcc-arm-* >/dev/null 2>&1; then
        rkb_log info "解压 toolchain"
        tar -xJf "${SRC_DIR}/${archive_name}" -C "${SRC_DIR}/prebuilts/gcc/linux-x86/aarch64/" --strip-components=1 \
            || rkb_warn "toolchain 解压失败"
    fi
fi

# overlay
bash "${SCRIPTS_DIR}/apply-overlay.sh"

rkb_ok "fetch-source 完成。请执行 'make defconfig' 再 'make build'"