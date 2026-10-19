#!/usr/bin/env bash
# scripts/ubuntu-sdk.sh —— 生成 Rockchip Ubuntu 22.04 交叉编译 SDK
#
# SDK 内容：
#   toolchain/            FriendlyARM GCC 11.3 aarch64（glibc 2.35，可重定位）
#   sysroot/              Ubuntu 22.04 arm64 开发 sysroot（libc6-dev + 常用 -dev 库）
#   bin/                  带 --sysroot 的交叉编译 wrapper
#   environment-setup     source 后生效
#   cmake/                CMake toolchain file
#   external/             （可选）BSP 源码：kernel / u-boot / mpp / rknpu2 / rkbin
#
# 产出：dist/sdk/rk3588-rockchip-ubuntu22.04-<variant>-<date>-sdk.tar.xz (+ .sha256)
#
# 仅支持 VENDOR=rockchip。

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_ubuntu_assert
rkb_ubuntu_require_root "$@"
rkb_ubuntu_check_host

DATE="$(date +%Y%m%d)"
SDK_OUT="${OUTPUT}/sdk"
SDK_STAGE="${UBUNTU_WORK}/rk3588-ubuntu22.04-sdk"
SYSROOT="${SDK_STAGE}/sysroot"
TOOLCHAIN_DIR="$(rkb_ubuntu_toolchain_dir)"
TC_PREFIX="$(rkb_ubuntu_toolchain_prefix)"
SDK_INCLUDE_EXTERNAL="${SDK_INCLUDE_EXTERNAL:-1}"
SDK_KEEP_STAGE="${SDK_KEEP_STAGE:-0}"
SDK_PACKAGES_FILE="${SDK_PACKAGES_FILE:-${UBUNTU_PACKAGES_DIR}/sdk.list}"

rkb_banner "ubuntu-sdk  VENDOR=$VENDOR  ROOTFS=$ROOTFS  VARIANT=$VARIANT"

[[ -x "${TOOLCHAIN_DIR}/bin/${TC_PREFIX}-gcc" ]] \
    || rkb_die "交叉工具链不存在：${TOOLCHAIN_DIR}（先 make fetch ROOTFS=ubuntu）"
[[ -f "$(rkb_ubuntu_base_tarball)" ]] \
    || rkb_die "Ubuntu Base 未下载（先 make fetch ROOTFS=ubuntu）"

cleanup() {
    local rc=$?
    if [[ -d "$SYSROOT" ]]; then
        rkb_ubuntu_umount_rootfs "$SYSROOT" 2>/dev/null || true
    fi
    if (( rc != 0 )); then
        rkb_log error "ubuntu-sdk 失败 rc=$rc（中间目录保留：$SDK_STAGE）"
    fi
}
trap cleanup EXIT INT TERM

mkdir -p "$SDK_OUT" "$UBUNTU_WORK"
SDK_REUSE="${UBUNTU_SDK_REUSE:-0}"
SDK_STAMP="${SDK_STAGE}/.sysroot-ready"

# ===========================================================================
# 1) 构建 Ubuntu 22.04 sysroot
# ===========================================================================
if [[ "$SDK_REUSE" == "1" && -f "$SDK_STAMP" && -d "${SYSROOT}/usr/include" ]]; then
    rkb_section "复用已有 SDK sysroot（UBUNTU_SDK_REUSE=1）"
    mkdir -p "$SDK_STAGE/bin" "$SDK_STAGE/cmake"
else
    rm -rf "$SDK_STAGE"
    mkdir -p "$SDK_STAGE/bin" "$SDK_STAGE/cmake"

    rkb_section "构建 Ubuntu $(rkb_ubuntu_version) arm64 sysroot"
    rkb_ubuntu_extract_base "$SYSROOT"
    rkb_ubuntu_write_apt_sources "$SYSROOT"

    [[ -f "$SDK_PACKAGES_FILE" ]] || rkb_die "SDK 包清单不存在：$SDK_PACKAGES_FILE"
    mapfile -t SDK_PKGS < <(grep -vE '^[[:space:]]*(#|$)' "$SDK_PACKAGES_FILE" \
        | awk '{print $1}' | awk '!seen[$0]++')
    if [[ -n "${UBUNTU_EXTRA_PACKAGES:-}" ]]; then
        # shellcheck disable=SC2206
        SDK_PKGS+=( ${UBUNTU_EXTRA_PACKAGES} )
    fi
    rkb_log info "sysroot 软件包数量：${#SDK_PKGS[@]}"
    rkb_ubuntu_apt_update_and_install "$SYSROOT" "${SDK_PKGS[@]}"
    rkb_ubuntu_finalize_rootfs "$SYSROOT"

    # RKNN runtime + 头文件
    rkb_section "加入 RKNN runtime / 头文件"
    RKNN_LIB="$(find "${UBUNTU_SRC_DIR}/rknpu2" -path '*aarch64/librknnrt.so' -type f 2>/dev/null | head -1 || true)"
    RKNN_INC_DIR="$(find "${UBUNTU_SRC_DIR}/rknpu2" -name rknn_api.h -type f 2>/dev/null | head -1 || true)"
    if [[ -n "$RKNN_LIB" ]]; then
        install -m 0755 "$RKNN_LIB" "${SYSROOT}/usr/lib/aarch64-linux-gnu/librknnrt.so"
        if [[ -n "$RKNN_INC_DIR" ]]; then
            mkdir -p "${SYSROOT}/usr/include/rknn"
            install -m 0644 "$(dirname "$RKNN_INC_DIR")"/*.h "${SYSROOT}/usr/include/rknn/" 2>/dev/null || true
        fi
        rkb_ok "sysroot 已包含 librknnrt.so"
    else
        rkb_warn "rknpu2 中未找到 librknnrt.so；SDK 不含 RKNN runtime"
    fi

    # 方便部分构建系统直接按 triplet 查找（wrapper 已显式加 -isystem/-L）
    ln -sfn aarch64-linux-gnu "${SYSROOT}/usr/include/aarch64-${TC_PREFIX#aarch64-}"
    ln -sfn aarch64-linux-gnu "${SYSROOT}/usr/lib/aarch64-${TC_PREFIX#aarch64-}"

    touch "$SDK_STAMP"
fi

# ===========================================================================
# 2) 工具链
# ===========================================================================
rkb_section "复制交叉工具链"
mkdir -p "${SDK_STAGE}/toolchain"
cp -a "${TOOLCHAIN_DIR}/." "${SDK_STAGE}/toolchain/"
rkb_ok "工具链：${SDK_STAGE}/toolchain"

# ===========================================================================
# 3) wrapper + environment-setup + CMake
# ===========================================================================
rkb_section "生成 SDK wrapper / environment-setup"

WRAPPER_BIN="${SDK_STAGE}/bin"
REAL_PREFIX="${TC_PREFIX}-"

# 编译器 wrapper：--sysroot + Ubuntu 多架构 include/lib 路径
for tool in gcc g++ cc c++; do
    cat > "${WRAPPER_BIN}/aarch64-rkbuild-linux-gnu-${tool}" <<EOF
#!/bin/sh
# rkbuild Ubuntu 22.04 交叉 ${tool} wrapper（自动指向 SDK 内 sysroot）
_SDK_ROOT=\$(CDPATH= cd -- "\$(dirname -- "\$0")/.." && pwd)
_SYSROOT="\${_SDK_ROOT}/sysroot"
exec "\${_SDK_ROOT}/toolchain/bin/${REAL_PREFIX}${tool}" \\
    --sysroot="\${_SYSROOT}" \\
    -isystem "\${_SYSROOT}/usr/include/aarch64-linux-gnu" \\
    -B"\${_SYSROOT}/usr/lib/aarch64-linux-gnu" \\
    -L"\${_SYSROOT}/usr/lib/aarch64-linux-gnu" \\
    -Wl,-rpath-link,"\${_SYSROOT}/usr/lib/aarch64-linux-gnu" \\
    -Wl,-rpath-link,"\${_SYSROOT}/lib/aarch64-linux-gnu" \\
    "\$@"
EOF
    chmod 0755 "${WRAPPER_BIN}/aarch64-rkbuild-linux-gnu-${tool}"
done

# 预处理器 wrapper（不接受链接参数）
cat > "${WRAPPER_BIN}/aarch64-rkbuild-linux-gnu-cpp" <<EOF
#!/bin/sh
_SDK_ROOT=\$(CDPATH= cd -- "\$(dirname -- "\$0")/.." && pwd)
_SYSROOT="\${_SDK_ROOT}/sysroot"
exec "\${_SDK_ROOT}/toolchain/bin/${REAL_PREFIX}cpp" \\
    --sysroot="\${_SYSROOT}" \\
    -isystem "\${_SYSROOT}/usr/include/aarch64-linux-gnu" \\
    "\$@"
EOF
chmod 0755 "${WRAPPER_BIN}/aarch64-rkbuild-linux-gnu-cpp"

# binutils wrapper（不接受 --sysroot，直接转发）
for tool in ar as ld nm objcopy objdump ranlib readelf strip size addr2line c++filt elfedit dwp gcov gcov-dump gcov-tool; do
    if [[ -x "${SDK_STAGE}/toolchain/bin/${REAL_PREFIX}${tool}" ]]; then
        cat > "${WRAPPER_BIN}/aarch64-rkbuild-linux-gnu-${tool}" <<EOF
#!/bin/sh
_SDK_ROOT=\$(CDPATH= cd -- "\$(dirname -- "\$0")/.." && pwd)
exec "\${_SDK_ROOT}/toolchain/bin/${REAL_PREFIX}${tool}" "\$@"
EOF
        chmod 0755 "${WRAPPER_BIN}/aarch64-rkbuild-linux-gnu-${tool}"
    fi
done

# pkg-config wrapper：确保 pkg-config 查询的是 sysroot
cat > "${WRAPPER_BIN}/aarch64-rkbuild-linux-gnu-pkg-config" <<'EOF'
#!/bin/sh
_SDK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
_SYSROOT="${_SDK_ROOT}/sysroot"
export PKG_CONFIG_SYSROOT_DIR="$_SYSROOT"
export PKG_CONFIG_LIBDIR="$_SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig:$_SYSROOT/usr/lib/pkgconfig:$_SYSROOT/usr/share/pkgconfig"
for p in /usr/bin/pkg-config /usr/local/bin/pkg-config /bin/pkg-config; do
    if [ -x "$p" ]; then
        exec "$p" "$@"
    fi
done
echo "pkg-config not found on host; install pkg-config" >&2
exit 1
EOF
chmod 0755 "${WRAPPER_BIN}/aarch64-rkbuild-linux-gnu-pkg-config"

cat > "${SDK_STAGE}/environment-setup" <<'EOF'
# rkbuild Ubuntu 22.04 aarch64 交叉编译环境
# 用法：source environment-setup
if [ -n "${BASH_SOURCE:-}" ]; then
    _rkbuild_src="${BASH_SOURCE[0]}"
else
    _rkbuild_src="$0"
fi
SDK_ROOT="$(CDPATH= cd -- "$(dirname -- "$_rkbuild_src")" && pwd)"
unset _rkbuild_src

export SDK_ROOT
export SYSROOT="${SDK_ROOT}/sysroot"
export CROSS_COMPILE="aarch64-rkbuild-linux-gnu-"
export PATH="${SDK_ROOT}/bin:${SDK_ROOT}/toolchain/bin:${PATH}"

export CC="${CROSS_COMPILE}gcc"
export CXX="${CROSS_COMPILE}g++"
export CPP="${CROSS_COMPILE}cpp"
export AR="${CROSS_COMPILE}ar"
export AS="${CROSS_COMPILE}as"
export LD="${CROSS_COMPILE}ld"
export NM="${CROSS_COMPILE}nm"
export OBJCOPY="${CROSS_COMPILE}objcopy"
export OBJDUMP="${CROSS_COMPILE}objdump"
export RANLIB="${CROSS_COMPILE}ranlib"
export READELF="${CROSS_COMPILE}readelf"
export STRIP="${CROSS_COMPILE}strip"
export SIZE="${CROSS_COMPILE}size"
export PKG_CONFIG="${CROSS_COMPILE}pkg-config"

export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig"
export PKG_CONFIG_PATH=""
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1

export CFLAGS="-O2 -pipe"
export CXXFLAGS="-O2 -pipe"
export LDFLAGS=""
export CMAKE_TOOLCHAIN_FILE="${SDK_ROOT}/cmake/aarch64-rkbuild-toolchain.cmake"
export QEMU_LD_PREFIX="${SYSROOT}"

# 让基于 autotools/Makefile 的项目默认使用交叉工具
export HOST=aarch64-linux-gnu
export BUILD="$(gcc -dumpmachine 2>/dev/null || echo x86_64-linux-gnu)"

echo "[rkbuild sdk] CC=$CC"
echo "[rkbuild sdk] SYSROOT=$SYSROOT"
EOF

cat > "${SDK_STAGE}/cmake/aarch64-rkbuild-toolchain.cmake" <<'EOF'
# rkbuild Ubuntu 22.04 aarch64 CMake toolchain
get_filename_component(_SDK_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_SYSROOT "${_SDK_ROOT}/sysroot")
set(CMAKE_C_COMPILER "${_SDK_ROOT}/bin/aarch64-rkbuild-linux-gnu-gcc")
set(CMAKE_CXX_COMPILER "${_SDK_ROOT}/bin/aarch64-rkbuild-linux-gnu-g++")
set(CMAKE_AR "${_SDK_ROOT}/bin/aarch64-rkbuild-linux-gnu-ar")
set(CMAKE_RANLIB "${_SDK_ROOT}/bin/aarch64-rkbuild-linux-gnu-ranlib")
set(CMAKE_STRIP "${_SDK_ROOT}/bin/aarch64-rkbuild-linux-gnu-strip")

set(CMAKE_FIND_ROOT_PATH "${_SDK_ROOT}/sysroot")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

# ===========================================================================
# 4) external/ 源码（可选）
# ===========================================================================
if [[ "$SDK_INCLUDE_EXTERNAL" == "1" ]]; then
    rkb_section "复制 BSP 源码到 external/"
    mkdir -p "${SDK_STAGE}/external"
    for src in kernel u-boot-mainline rkbin mpp rknpu2; do
        if [[ -d "${UBUNTU_SRC_DIR}/${src}" ]]; then
            rkb_log info "  external/${src}"
            rsync -a \
                --exclude='.git/' \
                --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
                "${UBUNTU_SRC_DIR}/${src}/" "${SDK_STAGE}/external/${src}/"
        fi
    done
else
    rkb_log info "SDK_INCLUDE_EXTERNAL=0：不打包 BSP 源码"
fi

# ===========================================================================
# 5) README / 自检 / 打包
# ===========================================================================
cat > "${SDK_STAGE}/README.txt" <<EOF
rkbuild Rockchip Ubuntu $(rkb_ubuntu_version) aarch64 交叉编译 SDK
========================================================================
构建时间 : $(date -Iseconds)
rkbuild  : $(cat "${RKB_ROOT}/VERSION")
Vendor   : ${VENDOR}
Variant  : ${VARIANT}
Toolchain: FriendlyARM GCC ${TC_PREFIX} (glibc 2.35)
Sysroot  : Ubuntu $(rkb_ubuntu_version) ($(rkb_ubuntu_series)) arm64

快速开始
--------
  tar -xJf rk3588-rockchip-ubuntu22.04-${VARIANT}-${DATE}-sdk.tar.xz -C /opt/
  cd /opt/rk3588-ubuntu22.04-sdk
  source environment-setup

  echo 'int main(){return 0;}' | \$CC -x c - -o /tmp/hello
  file /tmp/hello       # ELF 64-bit LSB ... ARM aarch64

CMake
-----
  export CMAKE_TOOLCHAIN_FILE=\$SDK_ROOT/cmake/aarch64-rkbuild-toolchain.cmake
  cmake -B build -DCMAKE_TOOLCHAIN_FILE=\$CMAKE_TOOLCHAIN_FILE
  cmake --build build

pkg-config
----------
  \$PKG_CONFIG --cflags --libs zlib
  \$PKG_CONFIG --cflags --libs gstreamer-1.0
  \$PKG_CONFIG --cflags --libs opencv4

可直接访问的库
--------------
  sysroot 内含 Ubuntu jammy 的 libc/libstdc++/OpenSSL/curl/GStreamer/OpenCV/
  libdrm/libgbm/EGL/GLES/libgpiod/libasound/libsqlite/libmosquitto/libwebsockets
  等开发文件；另外包含 Rockchip RKNN runtime（librknnrt.so + rknn/ 头文件）。

说明
----
* 编译产物运行于 Ubuntu 22.04（glibc 2.35）rootfs；不要用宿主机的
  /usr/include、/usr/lib 混淆 sysroot。
* 本 SDK 不包含 Rockchip 专有 GPU 驱动（libmali）和 MPP 预编译库；
  MPP 源码位于 external/mpp（若打包），可用本 SDK 自行交叉编译。
* external/ 下的 kernel/u-boot 源码仅便于二次开发，构建内核模块时
  请使用 $CROSS_COMPILE 作为 CROSS_COMPILE。
EOF

rkb_section "SDK 自检：交叉编译 hello (C / C++)"
SELFTEST_DIR="${SDK_STAGE}/.selftest"
mkdir -p "$SELFTEST_DIR"
printf 'int main(void){return 0;}\n' > "${SELFTEST_DIR}/hello.c"
printf '#include <iostream>\nint main(){std::cout<<"ok"<<std::endl;}\n' > "${SELFTEST_DIR}/hello.cpp"

(
    # shellcheck disable=SC1091
    source "${SDK_STAGE}/environment-setup" >/dev/null
    "$CC" "${SELFTEST_DIR}/hello.c" -o "${SELFTEST_DIR}/hello-c"
    "$CXX" "${SELFTEST_DIR}/hello.cpp" -o "${SELFTEST_DIR}/hello-cpp"
    for f in "${SELFTEST_DIR}/hello-c" "${SELFTEST_DIR}/hello-cpp"; do
        if ! file "$f" | grep -q 'ARM aarch64'; then
            echo "SDK 自检失败：$f 不是 aarch64 ELF" >&2
            exit 1
        fi
    done
    echo "[ok] C  : $(file -b "${SELFTEST_DIR}/hello-c")"
    echo "[ok] C++: $(file -b "${SELFTEST_DIR}/hello-cpp")"
)
rm -rf "$SELFTEST_DIR"

PKG_NAME="rk3588-rockchip-ubuntu22.04-${VARIANT}-${DATE}-sdk.tar.xz"
PKG_PATH="${SDK_OUT}/${PKG_NAME}"
rm -f "$PKG_PATH" "${PKG_PATH}.sha256"
rkb_section "打包 SDK：$PKG_NAME"
# 多线程 xz（tar -J 是单线程，SDK 常有 2GB+）
tar -C "$UBUNTU_WORK" -cf - --exclude='.sysroot-ready' "$(basename "$SDK_STAGE")" \
    | xz -T"${JOBS}" -6 -c > "$PKG_PATH"
( cd "$SDK_OUT" && sha256sum "$PKG_NAME" > "${PKG_NAME}.sha256" )

SDK_SIZE="$(du -h "$PKG_PATH" | awk '{print $1}')"
rkb_ok "SDK 完成：${PKG_PATH}（${SDK_SIZE}）"
rkb_log info "SHA256：$(cat "${PKG_PATH}.sha256")"
rkb_log info "用法：tar -xJf ${PKG_NAME} -C /opt/ && source /opt/$(basename "$SDK_STAGE")/environment-setup"

if [[ "$SDK_KEEP_STAGE" != "1" ]]; then
    rm -rf "$SDK_STAGE"
else
    rkb_log info "保留 SDK 展开目录：$SDK_STAGE"
fi
