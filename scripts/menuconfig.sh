#!/usr/bin/env bash
# scripts/menuconfig.sh —— 打开 menuconfig（交互式）
#
# 行为：
#   - 若 .config 不存在，先跑 make defconfig
#   - make menuconfig
#   - 用户退出后自动 make olddefconfig 收尾
#   - 提示用户保存为新 defconfig（saveconfig 流程仿 radxa/buildroot）

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

if [[ "$VENDOR" == "alientek" ]]; then
    rkb_log info "alientek 流派无 menuconfig；编辑 SDK 内的 defconfig"
    exit 0
fi

BR_DIR="$(rkb_buildroot_dir)"
cd "$BR_DIR"

if [[ ! -f .config ]]; then
    rkb_warn ".config 不存在；先 make defconfig"
    bash "${SCRIPTS_DIR}/defconfig.sh"
fi

rkb_log info "启动 menuconfig（保存并退出）"
make menuconfig

# 收尾
make olddefconfig

# 把当前 .config 保存为 defconfig
rkb_log info "把 .config 保存为 defconfig..."
make savedefconfig

# 询问覆盖 / 新建
DEFCONFIG_CURRENT="$(rkb_defconfig_name)"
DEFCONFIG_TARGET="${DEFCONFIG_CURRENT}"
DEF_DIR="${RKB_DIR_OVERLAY:-${RKB_ROOT}/overlay}/defconfig"

# 优先用 BR_DIR 内的 defconfig；rsync 回 overlay
if [[ -f defconfig ]]; then
    if [[ -t 0 ]]; then
        echo
        read -r -p "把更新覆盖 ${DEF_DIR}/${DEFCONFIG_TARGET}？[y/N] " ans
        case "${ans,,}" in
            y|yes)
                cp -f defconfig "${DEF_DIR}/${DEFCONFIG_TARGET}"
                rkb_ok "已覆盖 ${DEF_DIR}/${DEFCONFIG_TARGET}"
                ;;
            *)
                rkb_log info "已保留新 defconfig 在 ${BR_DIR}/defconfig"
                ;;
        esac
    fi
fi

rkb_ok "menuconfig 完成。"