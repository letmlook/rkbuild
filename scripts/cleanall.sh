#!/usr/bin/env bash
# scripts/cleanall.sh —— 全清（含源码与 SDK 产出）
#
# 警告：删除 dist/src/、dist/images/、dist/sdk/、dist/rk3588-*/
# 保留 dist/dl/ 与 dist/output

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_banner "cleanall"

rkb_warn "将删除 dist/src/* dist/images/* dist/sdk/* dist/rk3588-* dist/overlays-applied/"
echo -n "确认？[y/N] "
read -r ans
case "${ans,,}" in
    y|yes) ;;
    *) rkb_log info "已取消"; exit 0 ;;
esac

rm -rf "${OUTPUT}/src"           2>/dev/null || true
rm -rf "${OUTPUT}/images"        2>/dev/null || true
rm -rf "${OUTPUT}/sdk"           2>/dev/null || true
rm -rf "${OUTPUT}/overlays-applied" 2>/dev/null || true
# 保留 dist/dl 缓存

# 删除 buildroot output 与 alientek SDK 的内部产物
rm -rf "${OUTPUT}/rk3588-"* 2>/dev/null || true

rkb_ok "cleanall 完成。下次 make fetch 将重新拉取全部源码。"