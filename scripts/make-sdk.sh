#!/usr/bin/env bash
# scripts/make-sdk.sh —— 产出交叉编译 SDK tarball
#
# radxa 流派：
#   1) cd buildroot && make sdk
#   2) 解 SDK tarball 到 dist/sdk/extracted/
#   3) 把外部源（kernel/mpp/rknpu2/rkbin）rsync 进 SDK 的 external/，修复相对路径
#   4) 加 README
#   5) 重打包为 dist/sdk/rk3588-sdk-<DATE>.tar.xz + sha256
#
# alientek 流派：
#   直接打包 SDK 内的 prebuilts/ + toolchain + sysroot

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_banner "make-sdk  VENDOR=$VENDOR  VARIANT=$VARIANT"

SDK_OUT="${OUTPUT}/sdk"
mkdir -p "$SDK_OUT"
DATE="$(date +%Y%m%d)"

case "$VENDOR" in
    alientek)
        SDK_DIR="$(rkb_workspace_dir)"
        [[ -d "$SDK_DIR" ]] || rkb_die "alientek SDK 未展开：$SDK_DIR"
        # alientek SDK 自带完整工具链与 sysroot
        # 打包 prebuilts/ + buildroot/output/<board>/host/ + device/rockchip/...
        PKG_NAME="rk3588-alientek-${VARIANT}-${DATE}.tar.xz"
        rkb_log info "打包 alientek SDK -> ${SDK_OUT}/${PKG_NAME}"
        cd "$(dirname "$SDK_DIR")"
        tar -cJf "${SDK_OUT}/${PKG_NAME}" \
            --exclude='*.o' --exclude='*.cmd' --exclude='*.tmp' \
            "$(basename "$SDK_DIR")/prebuilts" \
            "$(basename "$SDK_DIR")/buildroot/output/$(ls -1 "${SDK_DIR}/buildroot/output" 2>/dev/null | head -1)/host" 2>/dev/null \
            || true
        rkb_log info "请手动确认 SDK 内容：${SDK_OUT}/${PKG_NAME}"
        ;;
    *)
        BR_DIR="$(rkb_buildroot_dir)"
        [[ -d "$BR_DIR" ]] || rkb_die "buildroot 工作树不存在：$BR_DIR"
        [[ -f "${BR_DIR}/.config" ]] || rkb_die ".config 不存在；先 make defconfig"

        rkb_section "Buildroot 内部 make sdk"
        cd "$BR_DIR"
        make sdk
        # 找到生成的 tarball
        RAW_TARBALL="$(find output -maxdepth 4 -name 'buildroot-sdk-build.tar*' 2>/dev/null | head -1)"
        [[ -n "$RAW_TARBALL" ]] || rkb_die "Buildroot 未生成 sdk tarball；查看 ${BR_DIR}/output/logfile"

        rkb_section "展开 SDK"
        EXTRACT_DIR="${SDK_OUT}/extracted"
        rm -rf "$EXTRACT_DIR"
        mkdir -p "$EXTRACT_DIR"
        case "$RAW_TARBALL" in
            *.tar.gz) tar -xzf "$RAW_TARBALL" -C "$EXTRACT_DIR" ;;
            *.tar.xz) tar -xJf "$RAW_TARBALL" -C "$EXTRACT_DIR" ;;
            *.tar)    tar -xf  "$RAW_TARBALL" -C "$EXTRACT_DIR" ;;
            *) rkb_die "未知的 sdk tarball 格式：$RAW_TARBALL" ;;
        esac

        # 把外部源加进 SDK
        rkb_section "合并 external/ 源（kernel/mpp/rknpu2/rkbin）"
        EXTERNAL_DIR="${EXTRACT_DIR}/external"
        mkdir -p "$EXTERNAL_DIR"
        for src in kernel mpp rknpu2 rkbin u-boot; do
            if [[ -d "${SRC_DIR}/${src}" ]]; then
                rsync -a --delete "${SRC_DIR}/${src}/" "${EXTERNAL_DIR}/${src}/"
                rkb_log info "  external/${src} 已加入"
            fi
        done

        # 加 README
        rkb_section "写入 README"
        cat > "${EXTRACT_DIR}/README.txt" <<EOF
rk3588 cross SDK ($(rkb_vendor_get VENDOR_NAME) / ${VARIANT})
构建日期：$(date -Iseconds)
版本：$(cat "${RKB_ROOT}/VERSION")

用法：
  tar -xJf rk3588-sdk-${VARIANT}-${DATE}.tar.xz -C /opt/
  cd /opt/<SDK root>
  source environment-setup
  # 验证：$CC --version
  # 编译 hello：echo 'int main(){return 0;}' | $CC -x c -

注意：本 SDK 自带 external/{kernel,mpp,rknpu2,rkbin,u-boot}；
     工具链路径为 sysroot 内的 usr/bin/aarch64-buildroot-linux-gnu-*。
EOF

        # 重打包
        rkb_section "重打包为可分发 SDK"
        PKG_NAME="rk3588-${VARIANT}-${DATE}.tar.xz"
        cd "$EXTRACT_DIR"
        tar -cJf "${SDK_OUT}/${PKG_NAME}" ./*
        cd "$SDK_OUT"
        sha256sum "${PKG_NAME}" > "${PKG_NAME}.sha256"

        rkb_ok "SDK tarball：${SDK_OUT}/${PKG_NAME}"
        rkb_log info "SHA256：$(cat "${PKG_NAME}.sha256")"
        ;;
esac

# 清理 extracted
rm -rf "${SDK_OUT}/extracted"