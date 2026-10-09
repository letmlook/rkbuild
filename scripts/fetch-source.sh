#!/usr/bin/env bash
# scripts/fetch-source.sh —— 按 VENDOR 分发拉源码
#
# 设计：
#   - 由 Makefile 调用，自动 export RKB_ROOT / VENDOR / VARIANT
#   - 按 vendor 分发到 fetch-{rockchip,friendlyarm,alientek}.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT

# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

case "$VENDOR" in
    rockchip)
        # shellcheck disable=SC1090
        exec bash "${SCRIPTS_DIR}/fetch-rockchip.sh"
        ;;
    friendlyarm)
        # shellcheck disable=SC1090
        exec bash "${SCRIPTS_DIR}/fetch-friendlyarm.sh"
        ;;
    alientek)
        # shellcheck disable=SC1090
        exec bash "${SCRIPTS_DIR}/fetch-alientek.sh"
        ;;
    *)
        rkb_die "未知 VENDOR='$VENDOR'（可选：rockchip | friendlyarm | alientek）"
        ;;
esac