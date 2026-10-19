#!/usr/bin/env bash
# scripts/lib/ubuntu.sh —— Rockchip 官方 Ubuntu 22.04 构建共享函数
#
# 仅在 ROOTFS=ubuntu 且 VENDOR=rockchip 时使用。
# 负责：Ubuntu Base 解压、qemu-user chroot、apt 安装、内核/U-Boot 工具链定位、
#       rkbin 文件解析、rootfs 清理等。

if [[ -n "${__RKB_UBUNTU_SH__:-}" ]]; then
    return 0
fi
__RKB_UBUNTU_SH__=1

: "${RKB_ROOT:?RKB_ROOT must be set}"
: "${OUTPUT:=dist}"
: "${ROOTFS:=buildroot}"
: "${VARIANT:=headless}"
: "${BOARD:=rk3588}"
: "${JOBS:=$(nproc 2>/dev/null || echo 4)}"

# 相对 OUTPUT 统一转为绝对路径，避免 chroot/子目录下路径失效
case "$OUTPUT" in
    /*) ;;
    *) OUTPUT="${RKB_ROOT}/${OUTPUT}" ;;
esac

: "${UBUNTU_WORK:=${OUTPUT}/ubuntu}"
: "${UBUNTU_BOARDS_DIR:=${RKB_ROOT}/ubuntu/boards}"
: "${UBUNTU_PACKAGES_DIR:=${RKB_ROOT}/ubuntu/packages}"
: "${UBUNTU_OVERLAY_DIR:=${RKB_ROOT}/ubuntu/rootfs-overlay}"
: "${UBUNTU_SRC_DIR:=${OUTPUT}/src}"
: "${UBUNTU_DL_DIR:=${OUTPUT}/dl/ubuntu}"

export OUTPUT UBUNTU_WORK UBUNTU_BOARDS_DIR UBUNTU_PACKAGES_DIR \
       UBUNTU_OVERLAY_DIR UBUNTU_SRC_DIR UBUNTU_DL_DIR

# ---------------------------------------------------------------------------
# 校验 / 配置读取
# ---------------------------------------------------------------------------

rkb_ubuntu_assert() {
    [[ "$ROOTFS" == "ubuntu" ]] \
        || rkb_die "当前 ROOTFS='${ROOTFS}'，此脚本仅用于 ROOTFS=ubuntu"
    [[ "$VENDOR" == "rockchip" ]] \
        || rkb_die "ROOTFS=ubuntu 目前只支持 Rockchip 官方（VENDOR=rockchip），不支持 VENDOR='${VENDOR}'"
    [[ -f "$(rkb_vendor_ini)" ]] || rkb_die "缺少 vendor 配置：$(rkb_vendor_ini)"
}

# 读取 vendor ini 中的 Ubuntu 配置；同名环境变量优先（方便临时覆盖镜像源等）
rkb_ubuntu_vendor_get() {
    local key="$1"
    if [[ -n "${!key:-}" ]]; then
        printf '%s\n' "${!key}"
    else
        rkb_vendor_get "$key"
    fi
}

rkb_ubuntu_series() {
    local v
    v="$(rkb_ubuntu_vendor_get UBUNTU_SERIES)"
    printf '%s\n' "${v:-jammy}"
}

rkb_ubuntu_version() {
    local v
    v="$(rkb_ubuntu_vendor_get UBUNTU_VERSION)"
    printf '%s\n' "${v:-22.04.5}"
}

rkb_ubuntu_base_url() {
    rkb_ubuntu_vendor_get UBUNTU_BASE_URL
}

rkb_ubuntu_base_tarball() {
    local url name
    url="$(rkb_ubuntu_base_url)"
    [[ -n "$url" ]] || rkb_die "vendors/${VENDOR}.ini 未配置 UBUNTU_BASE_URL"
    name="$(basename "$url")"
    printf '%s/%s\n' "$UBUNTU_DL_DIR" "$name"
}

# ---------------------------------------------------------------------------
# 板级配置
# ---------------------------------------------------------------------------

rkb_ubuntu_board_ini() {
    local ini="${UBUNTU_BOARDS_DIR}/${BOARD}.ini"
    [[ -f "$ini" ]] || rkb_die "未找到 Ubuntu 板级配置：$ini
可用板：$(cd "$UBUNTU_BOARDS_DIR" 2>/dev/null && ls -1 *.ini 2>/dev/null | sed 's/\.ini$//' | tr '\n' ' ')
可用环境变量覆盖：KERNEL_DTB=... UBOOT_DEFCONFIG=... UBUNTU_UBOOT_TPL=... UBUNTU_UBOOT_BL31=..."
    printf '%s\n' "$ini"
}

# 用法：rkb_ubuntu_board_get KERNEL_DTB
# 环境变量优先，其次 ubuntu/boards/<BOARD>.ini
rkb_ubuntu_board_get() {
    local key="$1"
    if [[ -n "${!key:-}" ]]; then
        printf '%s\n' "${!key}"
        return 0
    fi
    local ini
    ini="$(rkb_ubuntu_board_ini)"
    # shellcheck disable=SC1090
    ( source "$ini" && printf '%s\n' "${!key:-}" )
}

# U-Boot TPL / BL31 允许 ini 中写相对 rkbin 的路径，也允许绝对路径。
# 找不到指定文件时自动选择 rkbin 中最新的匹配文件（rkbin 更新频繁）。
rkb_ubuntu_resolve_rkbin_file() {
    local rkbin="$1" wanted="$2" pattern="$3"
    local resolved=""
    if [[ -n "$wanted" ]]; then
        if [[ "$wanted" = /* && -f "$wanted" ]]; then
            printf '%s\n' "$wanted"
            return 0
        fi
        if [[ -f "${rkbin}/${wanted}" ]]; then
            printf '%s\n' "${rkbin}/${wanted}"
            return 0
        fi
    fi
    # shellcheck disable=SC2010,SC2012
    resolved="$(ls -1v "${rkbin}"/${pattern} 2>/dev/null \
        | grep -vE 'eyescan|_test_|single_vdd2' \
        | tail -1 || true)"
    [[ -n "$resolved" ]] || rkb_die "rkbin 中找不到 ${pattern}（rkbin=${rkbin}）"
    printf '%s\n' "$resolved"
}

# ---------------------------------------------------------------------------
# 工具链
# ---------------------------------------------------------------------------

rkb_ubuntu_toolchain_dir() {
    local dirname="${TOOLCHAIN_DIRNAME:-11.3-aarch64}"
    local candidate="${UBUNTU_SRC_DIR}/prebuilts/gcc/linux-x86/aarch64/FriendlyARM/toolchain/${dirname}"
    if [[ -x "${candidate}/bin/aarch64-cortexa53-linux-gnu-gcc" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    local found
    found="$(find "${UBUNTU_SRC_DIR}/prebuilts" -type f \
        -path '*/bin/aarch64-*-linux-gnu-gcc' 2>/dev/null | head -1 || true)"
    [[ -n "$found" ]] || rkb_die "未找到 aarch64 交叉工具链（先 make fetch ROOTFS=ubuntu）"
    dirname="$(dirname "$(dirname "$found")")"
    printf '%s\n' "$dirname"
}

rkb_ubuntu_toolchain_prefix() {
    local prefix
    prefix="$(rkb_ubuntu_vendor_get UBUNTU_TOOLCHAIN_PREFIX)"
    printf '%s\n' "${prefix:-aarch64-cortexa53-linux-gnu}"
}

rkb_ubuntu_cross_compile() {
    printf '%s/bin/%s-\n' "$(rkb_ubuntu_toolchain_dir)" "$(rkb_ubuntu_toolchain_prefix)"
}

# ---------------------------------------------------------------------------
# 主机依赖 / 权限 / qemu
# ---------------------------------------------------------------------------

rkb_ubuntu_require_root() {
    if [[ $EUID -ne 0 ]]; then
        rkb_maybe_sudo
        # 重新以 root 执行当前脚本，保留 MAKE/Makefile 传入的环境变量
        exec sudo -E env \
            VENDOR="$VENDOR" VARIANT="$VARIANT" BOARD="$BOARD" ROOTFS="$ROOTFS" \
            OUTPUT="$OUTPUT" JOBS="$JOBS" RKB_ROOT="$RKB_ROOT" \
            KERNEL_DTB="${KERNEL_DTB:-}" UBOOT_DEFCONFIG="${UBOOT_DEFCONFIG:-}" \
            UBUNTU_CONSOLE="${UBUNTU_CONSOLE:-}" \
            UBUNTU_EXTRA_PACKAGES="${UBUNTU_EXTRA_PACKAGES:-}" \
            UBUNTU_USER="${UBUNTU_USER:-}" UBUNTU_PASSWORD="${UBUNTU_PASSWORD:-}" \
            UBUNTU_TZ="${UBUNTU_TZ:-}" UBUNTU_ROOTFS_REUSE="${UBUNTU_ROOTFS_REUSE:-}" \
            bash "$0" "$@"
    fi
}

rkb_ubuntu_host_arch_is_aarch64() {
    case "$(uname -m)" in
        aarch64|arm64) return 0 ;;
        *) return 1 ;;
    esac
}

rkb_ubuntu_check_host() {
    local cmds=(make gcc tar xz sha256sum curl git rsync mke2fs mkfs.vfat
                mcopy mmd parted depmod dtc bison flex bc)
    local missing=()
    local c
    for c in "${cmds[@]}"; do
        command -v "$c" >/dev/null 2>&1 || missing+=("$c")
    done
    if (( ${#missing[@]} > 0 )); then
        rkb_die "缺少宿主命令：${missing[*]}。请先执行 'sudo make init'"
    fi

    if ! rkb_ubuntu_host_arch_is_aarch64; then
        command -v qemu-aarch64-static >/dev/null 2>&1 \
            || rkb_die "缺少 qemu-aarch64-static；请执行 'sudo make init'（安装 qemu-user-static）"
        if [[ ! -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
            rkb_die "qemu-aarch64 binfmt 未注册。请执行：
  sudo systemctl restart systemd-binfmt
或：
  sudo update-binfmts --enable qemu-aarch64"
        fi
    fi

    rkb_require_space 20000 "$RKB_ROOT"
}

rkb_ubuntu_install_qemu() {
    local root="$1"
    if rkb_ubuntu_host_arch_is_aarch64; then
        return 0
    fi
    install -m 0755 /usr/bin/qemu-aarch64-static "${root}/usr/bin/qemu-aarch64-static"
}

# ---------------------------------------------------------------------------
# chroot 挂载 / 卸载
# ---------------------------------------------------------------------------

rkb_ubuntu_mount_rootfs() {
    local root="$1"
    mkdir -p "${root}/proc" "${root}/sys" "${root}/dev" "${root}/dev/pts" \
             "${root}/dev/shm" "${root}/run" "${root}/tmp"

    mountpoint -q "${root}/proc" || mount -t proc proc "${root}/proc"
    mountpoint -q "${root}/sys"  || mount -t sysfs sysfs "${root}/sys"
    mountpoint -q "${root}/dev"  || mount --bind /dev "${root}/dev"
    if [[ -d /dev/pts ]]; then
        mountpoint -q "${root}/dev/pts" || mount --bind /dev/pts "${root}/dev/pts"
    fi
    if [[ -d /dev/shm ]]; then
        mountpoint -q "${root}/dev/shm" || mount --bind /dev/shm "${root}/dev/shm"
    fi
    mountpoint -q "${root}/run" || mount -t tmpfs -o mode=755 tmpfs "${root}/run"
}

rkb_ubuntu_umount_rootfs() {
    local root="$1"
    local d
    for d in run dev/shm dev/pts dev sys proc; do
        if mountpoint -q "${root}/${d}" 2>/dev/null; then
            umount "${root}/${d}" 2>/dev/null || umount -l "${root}/${d}" 2>/dev/null || true
        fi
    done
}

# ---------------------------------------------------------------------------
# Ubuntu Base / apt
# ---------------------------------------------------------------------------

rkb_ubuntu_extract_base() {
    local root="$1" tarball
    tarball="$(rkb_ubuntu_base_tarball)"
    [[ -f "$tarball" ]] || rkb_die "Ubuntu Base 未下载：$tarball（先 make fetch ROOTFS=ubuntu）"
    rkb_log info "解压 Ubuntu Base：$tarball -> $root"
    rm -rf "$root"
    mkdir -p "$root"
    tar -xzf "$tarball" -C "$root"
}

rkb_ubuntu_write_apt_sources() {
    local root="$1"
    local mirror series
    mirror="$(rkb_ubuntu_vendor_get UBUNTU_PORTS_MIRROR)"
    series="$(rkb_ubuntu_series)"
    [[ -n "$mirror" ]] || mirror="http://ports.ubuntu.com/ubuntu-ports"
    mkdir -p "${root}/etc/apt"
    cat > "${root}/etc/apt/sources.list" <<EOF
# rkbuild Ubuntu ${series} (arm64) —— 由 scripts/lib/ubuntu.sh 生成
deb [arch=arm64] ${mirror} ${series} main restricted universe multiverse
deb [arch=arm64] ${mirror} ${series}-updates main restricted universe multiverse
deb [arch=arm64] ${mirror} ${series}-security main restricted universe multiverse
deb [arch=arm64] ${mirror} ${series}-backports main restricted universe multiverse
EOF
}

# 运行 arm64 chroot 命令（自动保留代理环境变量）
rkb_ubuntu_chroot() {
    local root="$1"
    shift
    local proxy_env=()
    local v
    for v in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
        if [[ -n "${!v:-}" ]]; then
            proxy_env+=("${v}=${!v}")
        fi
    done
    chroot "$root" /usr/bin/env -i \
        HOME=/root \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        LC_ALL=C.UTF-8 \
        LANG=C.UTF-8 \
        DEBIAN_FRONTEND=noninteractive \
        "${proxy_env[@]}" \
        "$@"
}

# 创建 policy-rc.d，防止 apt 在 chroot 里启动服务
rkb_ubuntu_write_policy_rc() {
    local root="$1"
    mkdir -p "${root}/usr/sbin"
    cat > "${root}/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
    chmod 0755 "${root}/usr/sbin/policy-rc.d"
}

rkb_ubuntu_apt_update_and_install() {
    local root="$1"
    shift
    local packages=("$@")
    local pkg_args
    printf -v pkg_args '%s ' "${packages[@]}"

    rkb_ubuntu_mount_rootfs "$root"
    rkb_ubuntu_install_qemu "$root"
    cp -f /etc/resolv.conf "${root}/etc/resolv.conf"
    rkb_ubuntu_write_policy_rc "$root"

    rkb_section "apt-get update（Ubuntu $(rkb_ubuntu_version) arm64）"
    rkb_ubuntu_chroot "$root" apt-get update -qq \
        -o Acquire::Retries=3 \
        -o Acquire::http::Timeout=60

    rkb_section "apt-get install（${#packages[@]} 个包）"
    # shellcheck disable=SC2086
    rkb_ubuntu_chroot "$root" apt-get install -y \
        --no-install-recommends \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        -o Acquire::Retries=3 \
        $pkg_args

    rkb_ubuntu_chroot "$root" apt-get clean
    rm -rf "${root}/var/lib/apt/lists/"* 2>/dev/null || true
    rm -rf "${root}/var/cache/apt/archives/"*.deb 2>/dev/null || true
    rm -f "${root}/usr/sbin/policy-rc.d"
}

# 读取 ubuntu/packages/<variant>.list + UBUNTU_EXTRA_PACKAGES
# GUI 变体 = headless.list + gui.list（GUI 是在服务器基础上追加桌面）
rkb_ubuntu_package_list() {
    local variant="${1:-$VARIANT}"
    local lists=()
    case "$variant" in
        gui) lists=("${UBUNTU_PACKAGES_DIR}/headless.list" "${UBUNTU_PACKAGES_DIR}/gui.list") ;;
        headless) lists=("${UBUNTU_PACKAGES_DIR}/headless.list") ;;
        *) lists=("${UBUNTU_PACKAGES_DIR}/${variant}.list") ;;
    esac

    local list
    for list in "${lists[@]}"; do
        [[ -f "$list" ]] || rkb_die "缺少包清单：$list"
    done

    local pkgs=()
    mapfile -t pkgs < <(cat "${lists[@]}" \
        | grep -vE '^[[:space:]]*(#|$)' \
        | awk '{print $1}' \
        | awk '!seen[$0]++')
    if [[ -n "${UBUNTU_EXTRA_PACKAGES:-}" ]]; then
        # shellcheck disable=SC2206
        pkgs+=( ${UBUNTU_EXTRA_PACKAGES} )
    fi
    printf '%s\n' "${pkgs[@]}"
}

# 收尾：移除 qemu/policy，清理缓存，恢复 resolv.conf 为 systemd-resolved 风格
rkb_ubuntu_finalize_rootfs() {
    local root="$1"
    rkb_ubuntu_umount_rootfs "$root"
    rm -f "${root}/usr/bin/qemu-aarch64-static" \
          "${root}/usr/sbin/policy-rc.d" 2>/dev/null || true
    rm -rf "${root}/var/lib/apt/lists/"* \
           "${root}/var/cache/apt/archives/"*.deb \
           "${root}/tmp/"* 2>/dev/null || true
    rm -f "${root}/etc/resolv.conf"
    if [[ -d "${root}/run/systemd/resolve" ]]; then
        ln -sfn ../run/systemd/resolve/stub-resolv.conf "${root}/etc/resolv.conf"
    else
        printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "${root}/etc/resolv.conf"
    fi
    : > "${root}/etc/machine-id"
    rm -rf "${root}/var/lib/systemd/random-seed" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 内核 / U-Boot
# ---------------------------------------------------------------------------

rkb_ubuntu_kernel_source() {
    printf '%s/kernel\n' "$UBUNTU_SRC_DIR"
}

rkb_ubuntu_uboot_source() {
    printf '%s/u-boot-mainline\n' "$UBUNTU_SRC_DIR"
}

rkb_ubuntu_rkbin_dir() {
    printf '%s/rkbin\n' "$UBUNTU_SRC_DIR"
}

# 解析板级 TPL/BL31
rkb_ubuntu_uboot_tpl() {
    local rkbin wanted
    rkbin="$(rkb_ubuntu_rkbin_dir)"
    wanted="$(rkb_ubuntu_board_get UBUNTU_UBOOT_TPL)"
    rkb_ubuntu_resolve_rkbin_file "$rkbin" "$wanted" 'bin/rk35/rk3588_ddr_*.bin'
}

rkb_ubuntu_uboot_bl31() {
    local rkbin wanted
    rkbin="$(rkb_ubuntu_rkbin_dir)"
    wanted="$(rkb_ubuntu_board_get UBUNTU_UBOOT_BL31)"
    rkb_ubuntu_resolve_rkbin_file "$rkbin" "$wanted" 'bin/rk35/rk3588_bl31_*.elf'
}

rkb_ubuntu_kernelrelease() {
    local kout="$1"
    local ksrc="${2:-$(rkb_ubuntu_kernel_source)}"
    make -s -C "$ksrc" O="$kout" ARCH=arm64 \
        CROSS_COMPILE="$(rkb_ubuntu_cross_compile)" kernelrelease 2>/dev/null \
        | tail -1
}
