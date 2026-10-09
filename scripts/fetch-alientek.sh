#!/usr/bin/env bash
# scripts/fetch-alientek.sh —— 拉正点原子 SDK（来自 Mega.nz tarball）
#
# 特点：
#   - 不是 git 树，是单 tarball（多 GB）
#   - 默认板：atk-dlrk3588B（GUI）/ quarkpi-ca2（GUI，RK3588S）
#   - 可通过 VARIANT=headless + patch 剥离 GUI

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_banner "fetch-source  VENDOR=$VENDOR  VARIANT=$VARIANT  BOARD=$BOARD"

# 决定 board（ali entek 只有 GUI 默认板；headless 仍走同一 SDK）
case "$BOARD" in
    atk-dlrk3588B|atk-dlrk3588) BOARD=atk-dlrk3588B ;;
    quarkpi-ca2|quarkpi)        BOARD=quarkpi-ca2 ;;
    *) BOARD=atk-dlrk3588B ;;
esac
export BOARD

# Mega.nz tarball 路径
TARBALL="${SRC_DIR}/atk-sdk-${BOARD}.tar.xz"
SDK_DIR="${SRC_DIR}/atk-sdk"

# 1) 取 tarball
if [[ ! -d "$SDK_DIR" ]]; then
    rkb_section "获取 alientek SDK tarball"
    rkb_alientek_pick_tarball "$BOARD" >/dev/null
    if [[ ! -f "$TARBALL" ]]; then
        rkb_die "tarball 不存在：$TARBALL"
    fi
    rkb_section "解压 SDK"
    mkdir -p "$SDK_DIR"
    rkb_extract "$TARBALL" "$SDK_DIR"
fi

# 2) 应用 headless patch（若 VARIANT=headless）
rkb_alien_apply_headless_patch "$SDK_DIR" "$BOARD"

# 3) 注意：alientek 用自家 ./build.sh 选板；不需要 apply-overlay.sh
#    但仍写入 marker
rkb_mark_overlay_applied

rkb_ok "fetch-source 完成（alientek）。请执行 'make build VENDOR=alientek BOARD=$BOARD'"