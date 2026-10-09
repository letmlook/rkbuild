#!/usr/bin/env bash
# scripts/init-env.sh —— 安装 RK3588 Buildroot 编译所需的宿主依赖（apt 优先）
#
# 覆盖：
#   - Buildroot 编译基础
#   - Linux kernel/U-Boot 编译工具
#   - 镜像制作工具（genext2fs / e2fsprogs / dosfstools / btrfs-progs）
#   - 可选：megatools（alientek 厂商用）

set -e
# 解析项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT

# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_banner "rkbuild init-env  $(rkb_vendor_ini >/dev/null && echo 'VENDOR='$VENDOR)"

rkb_os_detect

# 检查 root
rkb_maybe_sudo

# Buildroot 官方推荐的 host 依赖（截至 Buildroot 2024.02 文档 manual/requirement.html）
HOST_PKGS_APT=(
    # 基础
    bash
    build-essential
    bison
    flex
    file
    gawk
    gcc
    g++
    make
    patch
    perl
    python3
    rsync
    sed
    tar
    unzip
    wget
    xz-utils
    # ncurses（menuconfig）
    libncurses-dev
    ncurses-base
    ncurses-term
    # SSL（openssl/python3-ssl）
    libssl-dev
    # Git
    git
    git-core
    # diff/补丁
    diffutils
    # 镜像与文件系统
    genext2fs
    e2fsprogs
    dosfstools
    btrfs-progs
    squashfs-tools
    # 调试
    gdb
    # 网络工具
    curl
    # 工具链
    bc
    cpio
    dpkg-dev
    fakeroot
    libmpc-dev
    libgmp-dev
    # kernel/u-boot 编译
    device-tree-compiler
    u-boot-tools
    libelf-dev
    # 字体（Qt 等）
    fontconfig
    libfontconfig1
    # 容器（可选，本机 docker 测试）
    docker.io
    # megatools（alientek 用）
    megatools
)

rkb_log info "将安装 ${#HOST_PKGS_APT[@]} 个 apt 包（缺失才装）"
rkb_pkg_install_if_missing "${HOST_PKGS_APT[@]}"

# 验证关键命令
rkb_require_cmd make
rkb_require_cmd gcc
rkb_require_cmd python3
rkb_require_cmd git
rkb_require_cmd curl
rkb_require_cmd dtc
rkb_require_cmd mkfs.ext4
rkb_require_cmd mkfs.vfat

# python3 必要
python3 -c 'import sys; assert sys.version_info >= (3, 7)' \
    || rkb_die "需要 Python ≥ 3.7"

# 内核头文件（部分 vendor 需要）
if ! dpkg -s linux-libc-dev >/dev/null 2>&1; then
    rkb_pkg_install linux-libc-dev
fi

# 可选：megatools 装好提示
if command -v megatools >/dev/null 2>&1; then
    rkb_ok "megatools 已就绪（alientek Mega.nz 下载可用）"
else
    rkb_warn "megatools 未安装；alientek 厂商需手动下载 SDK tarball"
fi

rkb_ok "init-env 完成。现在可执行 'make fetch'"