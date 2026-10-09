#!/usr/bin/env bash
# scripts/lib/os.sh —— OS/distro 检测、包管理、sudo 处理

if [[ -n "${__RKB_OS_SH__:-}" ]]; then
    return 0
fi
__RKB_OS_SH__=1

# ---- 探测 distro ----
rkb_os_detect() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_VERSION_CODENAME="${VERSION_CODENAME:-unknown}"
        OS_VERSION_ID="${VERSION_ID:-unknown}"
        OS_LIKE="${ID_LIKE:-unknown}"
        OS_NAME="${NAME:-${OS_ID}}"
    else
        OS_ID="unknown"
        OS_NAME="$(uname -s)"
    fi
    rkb_log info "OS: ${OS_NAME} (${OS_ID} ${OS_VERSION_ID})"
}

# ---- 包管理器 ----
rkb_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo apt
    elif command -v dnf >/dev/null 2>&1; then
        echo dnf
    elif command -v yum >/dev/null 2>&1; then
        echo yum
    elif command -v pacman >/dev/null 2>&1; then
        echo pacman
    else
        rkb_die "未识别的包管理器（apt/dnf/yum/pacman 均未找到）"
    fi
}

# ---- 包管理器封装 ----
rkb_pkg_install() {
    local pm
    pm="$(rkb_pkg_manager)"
    rkb_maybe_sudo
    case "$pm" in
        apt)
            rkb_log info "apt-get update && apt-get install $*"
            sudo apt-get update
            sudo apt-get install -y "$@"
            ;;
        dnf|yum)
            rkb_log info "$pm install $*"
            sudo "$pm" install -y "$@"
            ;;
        pacman)
            rkb_log info "pacman -S --noconfirm $*"
            sudo pacman -S --noconfirm "$@"
            ;;
    esac
}

rkb_pkg_install_if_missing() {
    local pm
    pm="$(rkb_pkg_manager)"
    local missing=()
    for pkg in "$@"; do
        case "$pm" in
            apt)
                dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
                ;;
            dnf|yum)
                rpm -q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
                ;;
            pacman)
                pacman -Q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
                ;;
        esac
    done
    if (( ${#missing[@]} > 0 )); then
        rkb_pkg_install "${missing[@]}"
    else
        rkb_log info "已安装：$*"
    fi
}

# ---- sudo 包装 ----
rkb_sudo() {
    if rkb_is_root; then
        "$@"
    else
        sudo "$@"
    fi
}

# ---- 磁盘空间检查 ----
rkb_require_space() {
    local need_mb="$1" path="${2:-$PWD}"
    local avail_mb
    avail_mb="$(df -Pm "$path" | awk 'NR==2 {print $4}')"
    if (( avail_mb < need_mb )); then
        rkb_die "磁盘空间不足：${path} 剩余 ${avail_mb}MB，需要 ${need_mb}MB"
    fi
    rkb_log info "磁盘空间 OK：${avail_mb}MB（需要 ≥${need_mb}MB）"
}

# ---- 网络可达性 ----
rkb_network_ok() {
    local host="${1:-github.com}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 8 -o /dev/null "https://${host}" 2>/dev/null
    else
        ping -c1 -W3 "$host" >/dev/null 2>&1
    fi
}