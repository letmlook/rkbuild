#!/usr/bin/env bash
# scripts/clean.sh —— 增量清理
#
# 保留 dist/dl 缓存；删除 buildroot output/ 与中间产物。

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_banner "clean  VENDOR=$VENDOR  VARIANT=$VARIANT  ROOTFS=$ROOTFS"

if [[ "$ROOTFS" == "ubuntu" ]]; then
    rkb_log info "清理 Ubuntu 构建产物（保留 dist/src 源码与 dist/dl 缓存）"
    rm -rf "${UBUNTU_WORK}/rootfs" \
           "${UBUNTU_WORK}/kernel" \
           "${UBUNTU_WORK}/u-boot" \
           "${UBUNTU_WORK}/images" \
           "${UBUNTU_WORK}/boot-partition" \
           "${UBUNTU_WORK}/rk3588-ubuntu22.04-sdk" \
           "${UBUNTU_WORK}/.rootfs-ready" 2>/dev/null || true
    rkb_ok "Ubuntu incremental clean 完成"
    exit 0
fi

case "$VENDOR" in
    alientek)
        rkb_warn "alientek 流派 clean：请 'cd dist/src/atk-sdk && ./build.sh clean'"
        rkb_warn "rkbuild 仅清理自有的 marker 与临时文件"
        rkb_clear_overlay_marker
        ;;
    *)
        BR_DIR="$(rkb_buildroot_dir)"
        [[ -d "$BR_DIR" ]] || { rkb_warn "buildroot 工作树不存在：$BR_DIR"; exit 0; }
        cd "$BR_DIR"
        rkb_log info "make clean"
        make clean
        rkb_clear_overlay_marker
        ;;
esac

rkb_ok "incremental clean 完成"