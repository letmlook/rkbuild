#!/usr/bin/env bash
# scripts/make-image.sh —— 编译镜像（按 vendor 分发）
#
# rockchip / friendlyarm：cd dist/src/buildroot && make -j${JOBS}
# alientek：cd dist/src/atk-sdk && ./build.sh ${BOARD}

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

rkb_banner "make-image  VENDOR=$VENDOR  VARIANT=$VARIANT  BOARD=$BOARD"

case "$VENDOR" in
    alientek)
        SDK_DIR="$(rkb_workspace_dir)"
        [[ -d "$SDK_DIR" ]] || rkb_die "alientek SDK 未展开：$SDK_DIR（先 make fetch）"
        cd "$SDK_DIR"
        rkb_log info "./build.sh ${BOARD} -j${JOBS}"
        ./build.sh "${BOARD}" -j"${JOBS}"
        ;;
    *)
        BR_DIR="$(rkb_buildroot_dir)"
        [[ -d "$BR_DIR" ]] || rkb_die "buildroot 工作树不存在：$BR_DIR"
        [[ -f "${BR_DIR}/.config" ]] || rkb_die ".config 不存在；先 make defconfig"
        cd "$BR_DIR"
        rkb_log info "make -j${JOBS}"
        BR2_JLEVEL=${JOBS} make -j"${JOBS}"
        ;;
esac

rkb_ok "make-image 完成。镜像在 output/${VENDOR}_${VARIANT}/images/"