# rkbuild environment setup
# 用法：source ./envsetup.sh
# 之后可用：rkb-init / rkb-fetch / rkb-defconfig / rkb-build / rkb-sdk / rkb-image / rkb-clean
#
# 设计：仿 radxa/buildroot 的 scripts/envsetup.sh，提供简短别名

# ---- 防重复 source ----
if [[ -n "${__RKBUILDSET__:-}" ]]; then
    echo "[envsetup.sh] already sourced; re-sourcing will refresh them."
fi

# ---- 解析项目根目录 ----
_RKB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export RKB_ROOT="$_RKB_ROOT"
export __RKBUILDSET__=1

# ---- 默认环境变量 ----
: "${VENDOR:=rockchip}"
: "${VARIANT:=gui}"
: "${BOARD:=rk3588}"
: "${JOBS:=$(nproc 2>/dev/null || echo 4)}"
: "${OUTPUT:=dist}"
: "${SRC_DIR:=${OUTPUT}/src}"
: "${SDFUSE_NONINTERACTIVE:=y}"
: "${KEEP_CACHE:=1}"
: "${INIT_SYSTEM:=busybox}"

export VENDOR VARIANT BOARD JOBS OUTPUT SRC_DIR SDFUSE_NONINTERACTIVE KEEP_CACHE INIT_SYSTEM

# ---- 路径 ----
export SCRIPTS_DIR="${RKB_ROOT}/scripts"
export VENDORS_DIR="${RKB_ROOT}/vendors"
export OVERLAY_DIR="${RKB_ROOT}/overlay"
export ALIEN_DIR="${RKB_ROOT}/alientek-overlay"

# ---- 命令别名 ----
alias rkb-init="sudo make -C ${RKB_ROOT} init"
alias rkb-fetch="make -C ${RKB_ROOT} fetch"
alias rkb-defconfig="make -C ${RKB_ROOT} defconfig"
alias rkb-config="make -C ${RKB_ROOT} config"
alias rkb-menu="make -C ${RKB_ROOT} menu"
alias rkb-build="make -C ${RKB_ROOT} build"
alias rkb-image="make -C ${RKB_ROOT} image"
alias rkb-sdk="make -C ${RKB_ROOT} sdk"
alias rkb-clean="make -C ${RKB_ROOT} clean"
alias rkb-cleanall="make -C ${RKB_ROOT} cleanall"
alias rkb-info="make -C ${RKB_ROOT} info"
alias rkb-version="make -C ${RKB_ROOT} version"
alias rkb-help="make -C ${RKB_ROOT} help"

# ---- 颜色函数 ----
_rkb_color() {
    local color="$1"; shift
    case "$color" in
        red)    printf '\033[31m%s\033[0m\n' "$*" ;;
        green)  printf '\033[32m%s\033[0m\n' "$*" ;;
        yellow) printf '\033[33m%s\033[0m\n' "$*" ;;
        blue)   printf '\033[34m%s\033[0m\n' "$*" ;;
        bold)   printf '\033[1m%s\033[0m\n' "$*" ;;
        *)      printf '%s\n' "$*" ;;
    esac
}

# ---- 进入源码工作目录（radxa 流派） ----
_rkb_cd_buildroot() {
    if [[ -d "${SRC_DIR}/buildroot" ]]; then
        cd "${SRC_DIR}/buildroot"
    else
        echo "[envsetup.sh] 还没 fetch 源码；先 rkb-fetch" >&2
        return 1
    fi
}

alias rkb-croot='_rkb_color bold "现在你在 $PWD"'
alias rkb-bro='_rkb_cd_buildroot'

# ---- 摘要输出 ----
_rkb_color bold "rkbuild envsetup 已激活"
cat <<EOF | sed 's/^/  /'
项目根    : ${RKB_ROOT}
厂商      : ${VENDOR}
变体      : ${VARIANT}
板子      : ${BOARD}
源码目录  : ${SRC_DIR}
并行数    : ${JOBS}

常用别名：
  rkb-init         安装编译依赖
  rkb-fetch        拉源码
  rkb-defconfig    应用 defconfig
  rkb-config       menuconfig
  rkb-build        编译
  rkb-image        烧写镜像
  rkb-sdk          打包 SDK
  rkb-clean        增量清理
  rkb-cleanall     全清
  rkb-info         显示当前配置
  rkb-help         帮助

切换厂商/变体（export 后再 rkb-*）：
  export VENDOR=friendlyarm VARIANT=headless
  rkb-fetch && rkb-defconfig && rkb-build
EOF