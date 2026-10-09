#!/usr/bin/env bash
# scripts/common.sh —— 所有脚本共享的通用函数、路径、错误处理
#
# 用法：在其他脚本中：
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # 或调用方传 -s 时定义
#   source "${SCRIPT_DIR}/common.sh"
#
# 约定：
#   - common.sh 必须 source 之前已 export RKB_ROOT
#   - 不重复定义同一函数（重复 source 会覆盖）

# ---- 防 ----
if [[ -n "${__RKB_COMMON_SH__:-}" ]]; then
    return 0
fi
__RKB_COMMON_SH__=1

# ---- 严格模式 ----
# 注意：调用方可以提前 set -u；这里不再强制 set -e，给每个子命令单独决定
set -o pipefail

# ---- 路径（默认值，可被调用方覆盖） ----
: "${RKB_ROOT:?RKB_ROOT must be set}"
: "${SCRIPTS_DIR:=${RKB_ROOT}/scripts}"
: "${VENDORS_DIR:=${RKB_ROOT}/vendors}"
: "${OVERLAY_DIR:=${RKB_ROOT}/overlay}"
: "${ALIEN_DIR:=${RKB_ROOT}/alientek-overlay}"
: "${DOCS_DIR:=${RKB_ROOT}/docs}"
: "${VENDOR:=rockchip}"
: "${VARIANT:=gui}"
: "${BOARD:=rk3588}"
: "${JOBS:=$(nproc 2>/dev/null || echo 4)}"
: "${OUTPUT:=dist}"
: "${SRC_DIR:=${OUTPUT}/src}"
: "${KEEP_CACHE:=1}"
: "${SDFUSE_NONINTERACTIVE:=y}"
: "${INIT_SYSTEM:=busybox}"

export SCRIPTS_DIR VENDORS_DIR OVERLAY_DIR ALIEN_DIR DOCS_DIR \
       VENDOR VARIANT BOARD JOBS OUTPUT SRC_DIR KEEP_CACHE \
       SDFUSE_NONINTERACTIVE INIT_SYSTEM

# ---- 加载 lib ----
_LIB_DIR="${SCRIPTS_DIR}/lib"
for _lib in log os git alientek; do
    if [[ -f "${_LIB_DIR}/${_lib}.sh" ]]; then
        # shellcheck disable=SC1090
        source "${_LIB_DIR}/${_lib}.sh"
    fi
done
unset _lib _LIB_DIR

# ---- 顶层错误处理 ----
rkb_die() {
    rkb_log error "$@"
    exit 1
}

rkb_warn() { rkb_log warn "$@"; }
rkb_info() { rkb_log info "$@"; }
rkb_ok()   { rkb_log ok   "$@"; }
rkb_step() { rkb_log step "$@"; }

# ---- 调用方常用检查 ----
rkb_require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || rkb_die "缺少命令：$cmd。请先执行 'sudo make init'。"
}

rkb_require_file() {
    local f="$1"
    [[ -f "$f" ]] || rkb_die "缺少文件：$f"
}

rkb_require_dir() {
    local d="$1"
    [[ -d "$d" ]] || rkb_die "缺少目录：$d"
}

# ---- vendor 配置读取 ----
rkb_vendor_ini() {
    local name="${1:-$VENDOR}"
    local ini="${VENDORS_DIR}/${name}.ini"
    rkb_require_file "$ini"
    printf '%s\n' "$ini"
}

rkb_vendor_get() {
    local key="$1"
    local ini
    ini="$(rkb_vendor_ini)"
    # shellcheck disable=SC1090
    ( source "$ini" && printf '%s\n' "${!key:-}" )
}

# ---- 输出已应用 overlay 标记 ----
rkb_overlay_applied() {
    local marker="${OUTPUT}/overlays-applied/${VENDOR}_${VARIANT}.marker"
    [[ -f "$marker" ]]
}

rkb_mark_overlay_applied() {
    mkdir -p "${OUTPUT}/overlays-applied"
    date -u +%Y%m%dT%H%M%SZ > "${OUTPUT}/overlays-applied/${VENDOR}_${VARIANT}.marker"
}

rkb_clear_overlay_marker() {
    rm -f "${OUTPUT}/overlays-applied/${VENDOR}_${VARIANT}.marker"
}

# ---- root 检查 ----
rkb_is_root() {
    [[ $EUID -eq 0 ]]
}

rkb_maybe_sudo() {
    if ! rkb_is_root; then
        command -v sudo >/dev/null || rkb_die "需要 root 权限（请安装 sudo 或以 root 运行）"
        sudo -n true 2>/dev/null || rkb_die "需要 root 权限（请用 sudo 或以 root 运行）"
    fi
}

# ---- trap 辅助 ----
rkb_on_exit() {
    local rc=$?
    if (( rc != 0 )); then
        rkb_log error "脚本退出 rc=$rc"
    fi
}

# ---- 一些常用的相对路径输出 ----
rkb_defconfig_name() {
    case "$VENDOR" in
        alientek) printf '' ;;      # alientek 用 ./build.sh 选板，没有 defconfig
        *) printf 'rkbuild_%s_%s_defconfig\n' "rk3588" "$VARIANT" ;;
    esac
}

rkb_workspace_dir() {
    case "$VENDOR" in
        alientek) printf '%s\n' "${SRC_DIR}/atk-sdk" ;;
        *)        printf '%s\n' "${SRC_DIR}" ;;
    esac
}

rkb_buildroot_dir() {
    case "$VENDOR" in
        alientek) printf '%s\n' "${SRC_DIR}/atk-sdk/buildroot" ;;
        *)        printf '%s\n' "${SRC_DIR}/buildroot" ;;
    esac
}