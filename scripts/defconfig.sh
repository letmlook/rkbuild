#!/usr/bin/env bash
# scripts/defconfig.sh —— 把 rkbuild defconfig 应用到 buildroot 工作树
#
# 步骤：
#   1) 确认 src/buildroot 存在
#   2) 确认 overlay 已应用（marker）
#   3) make <DEFCONFIG>

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

# Ubuntu rootfs 不使用 Buildroot defconfig；保留目标以维持 make fetch/defconfig/build 流程
if [[ "$ROOTFS" == "ubuntu" ]]; then
    [[ "$VENDOR" == "rockchip" ]] \
        || rkb_die "ROOTFS=ubuntu 目前只支持 VENDOR=rockchip（官方）"
    rkb_log info "Ubuntu 流程不使用 defconfig；直接 'make build ROOTFS=ubuntu' 即可。"
    exit 0
fi

# alientek 流派不走 defconfig；提示用户直接 cd SDK
if [[ "$VENDOR" == "alientek" ]]; then
    rkb_log info "alientek 流派无 defconfig；请 'cd dist/src/atk-sdk && ./build.sh $BOARD'"
    exit 0
fi

rkb_banner "defconfig  VENDOR=$VENDOR  VARIANT=$VARIANT  BOARD=$BOARD"

BR_DIR="$(rkb_buildroot_dir)"
[[ -d "$BR_DIR" ]] || rkb_die "buildroot 工作树不存在：$BR_DIR（先 make fetch）"

# overlay marker 检查
if ! rkb_overlay_applied; then
    rkb_warn "overlay 未应用；自动跑 apply-overlay"
    bash "${SCRIPTS_DIR}/apply-overlay.sh"
fi

DEFCONFIG="$(rkb_defconfig_name)"
[[ -n "$DEFCONFIG" ]] || rkb_die "VENDOR=$VENDOR 无法解析 defconfig 名"

cd "$BR_DIR"
if [[ -f .config ]]; then
    rkb_warn ".config 已存在；建议先 'make clean' 重建。本次覆盖。"
    # 用 cp defconfig 为 .config，再 make olddefconfig 把新 defconfig 的选项 merge 进去
    cp -f "configs/${DEFCONFIG}" .config
else
    make "${DEFCONFIG}"
fi

# olddefconfig：消除 .config 中与新 defconfig 不一致项的 prompt
make olddefconfig

rkb_ok "defconfig 已应用：${DEFCONFIG}"
rkb_log info "下一步：make build（可加 -j${JOBS}；BR2_JLEVEL=${JOBS}）"