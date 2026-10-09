#!/usr/bin/env bash
# scripts/apply-overlay.sh —— 把 overlay/ 同步到 buildroot 工作树
#
# 同步内容：
#   1) overlay/defconfig/rkbuild_*.config → buildroot/configs/
#   2) overlay/fragments/* → buildroot/configs/fragments/（或同目录）
#   3) overlay/board/rockchip/rk3588/ → buildroot/board/rockchip/rk3588/
#   4) overlay/package/local/ → buildroot/package/local/
#   5) overlay/fragments/rkbuild_docker_kernel.config → board 的 kernel-fragment.config（Docker 必需内核）
#
# 幂等：已存在文件被覆盖；写入 marker ${OUTPUT}/overlays-applied/${VENDOR}_${VARIANT}.marker

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

# alientek 流派不走本脚本
if [[ "$VENDOR" == "alientek" ]]; then
    rkb_log info "alientek 流派跳过 apply-overlay（用 ./build.sh + patch）"
    exit 0
fi

rkb_banner "apply-overlay  VENDOR=$VENDOR  VARIANT=$VARIANT"

BR_DIR="${SRC_DIR}/buildroot"
[[ -d "$BR_DIR" ]] || rkb_die "buildroot 工作树不存在：$BR_DIR（先 make fetch）"

# 1) defconfig
rkb_section "configs/"
mkdir -p "${BR_DIR}/configs"
cp -f "${OVERLAY_DIR}/defconfig/rkbuild_rk3588_gui_defconfig" \
      "${BR_DIR}/configs/"
cp -f "${OVERLAY_DIR}/defconfig/rkbuild_rk3588_headless_defconfig" \
      "${BR_DIR}/configs/"

# 2) fragments
rkb_section "configs/fragments/"
mkdir -p "${BR_DIR}/configs/fragments"
cp -f "${OVERLAY_DIR}/fragments/"*.config \
      "${BR_DIR}/configs/fragments/"

# 3) board fs-overlay
rkb_section "board/rockchip/rk3588/"
mkdir -p "${BR_DIR}/board/rockchip/rk3588"
rsync -a --delete \
    "${OVERLAY_DIR}/board/rockchip/rk3588/" \
    "${BR_DIR}/board/rockchip/rk3588/"

# 4) package/local
rkb_section "package/local/"
mkdir -p "${BR_DIR}/package/local"
# 清空旧内容再同步（避免遗留）
rm -rf "${BR_DIR}/package/local"/* 2>/dev/null || true
cp -r "${OVERLAY_DIR}/package/local/." "${BR_DIR}/package/local/"

# 5) 把 Docker kernel fragment 单独拷贝到板级目录（已在第3步中完成，
#    因为 overlay/board/rockchip/rk3588/kernel-fragment.config 已存在，
#    但内容是占位；下面用真实片段覆盖一次）。
if [[ -f "${OVERLAY_DIR}/fragments/rkbuild_docker_kernel.config" ]]; then
    cp -f "${OVERLAY_DIR}/fragments/rkbuild_docker_kernel.config" \
          "${BR_DIR}/board/rockchip/rk3588/kernel-fragment.config"
fi

# 6) 把我们的 package/local/* 注册到 buildroot 主 package/Config.in
#    Buildroot 默认扫描整个 package/ 目录，所以 *.mk 自动被 include；
#    但需要 package/Config.in 添加 source 才能让 menuconfig 看到我们的包。
#    这里追加一段 menuconfig 引用；失败也无害。
if ! grep -q 'package/local/Config.in' "${BR_DIR}/package/Config.in" 2>/dev/null; then
    cat >> "${BR_DIR}/package/Config.in" <<'EOF'

# rkbuild local packages
source "package/local/Config.in"
EOF
    rkb_log info "已追加 rkbuild local packages 到 package/Config.in"
fi

# 7) 写入 marker
rkb_mark_overlay_applied
rkb_ok "apply-overlay 完成（marker 已写）"