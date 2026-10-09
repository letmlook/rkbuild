#!/usr/bin/env bash
# scripts/lib/log.sh —— 彩色日志输出
#
# 用法：
#   rkb_log info  "消息"
#   rkb_log ok    "成功消息"
#   rkb_log warn  "警告消息"
#   rkb_log error "错误消息"
#   rkb_log step  "步骤标题"
#
# 通过 NO_COLOR=1 或非 TTY 自动禁色。

if [[ -n "${__RKB_LOG_SH__:-}" ]]; then
    return 0
fi
__RKB_LOG_SH__=1

# ---- 检测 TTY ----
_rkb_log_use_color=1
if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    _rkb_log_use_color=0
fi

_rkb_log_color() {
    local code="$1"; shift
    if (( _rkb_log_use_color )); then
        printf '\033[%sm%s\033[0m' "$code" "$*"
    else
        printf '%s' "$*"
    fi
}

_rkb_log_now() {
    date '+%Y-%m-%d %H:%M:%S'
}

rkb_log() {
    local level="${1:-info}"
    shift || true
    local prefix ts
    ts="$(_rkb_log_now)"
    case "$level" in
        info)  prefix="$(_rkb_log_color '34' '[INFO]')"  ;;
        ok)    prefix="$(_rkb_log_color '32' '[ OK ]')"  ;;
        warn)  prefix="$(_rkb_log_color '33' '[WARN]')"  ;;
        error) prefix="$(_rkb_log_color '31;1' '[FAIL]')" ;;
        step)  prefix="$(_rkb_log_color '36;1' '[STEP]')" ;;
        debug) prefix="$(_rkb_log_color '90' '[DBG ]')"  ;;
        *)     prefix="[$level]" ;;
    esac
    printf '%s %s %s\n' "$ts" "$prefix" "$*"
}

# 标题分隔
rkb_banner() {
    local msg="$*"
    local bar
    bar="$(printf '=%.0s' $(seq 1 ${#msg}))"
    rkb_log step "$bar"
    rkb_log step "$msg"
    rkb_log step "$bar"
}

# 子标题
rkb_section() {
    local msg="$*"
    rkb_log step "── $msg ──"
}