#!/bin/sh
# overlay/board/rockchip/rk3588/post-image.sh —— Buildroot post-image 钩子
#
# 在 Buildroot 完成 rootfs.img 后被 BR2_ROOTFS_POST_IMAGE_SCRIPT 调用。
# 用于：
#   - 生成最终镜像的额外元数据（rkbuild-release、版本戳）
#   - 可选：调 scripts/mk-sd-image.sh 生成完整 SD 卡镜像
#   - 计算 sha256

set -e

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Buildroot 传入参数
# $1 = BINARIES_DIR（u-boot, kernel, rootfs.ext4 等都在这里）
# $2 = HOST_DIR
# $3 = IMAGES_DIR（最终 rootfs.ext4 在这里，名字由 BR2_TARGET_ROOTFS_* 决定）
# $4 = TARGET_DIR（chroot 视图的 target dir）

BINARIES_DIR="${1}"
HOST_DIR="${2}"
IMAGES_DIR="${3}"
TARGET_DIR="${4}"

RKB_ROOT="${RKB_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VARIANT="${VARIANT:-gui}"
VENDOR="${VENDOR:-rockchip}"
BOARD="${BOARD:-rk3588}"
DATE="$(date +%Y%m%d)"

echo "[post-image] BINARIES_DIR=$BINARIES_DIR"
echo "[post-image] IMAGES_DIR=$IMAGES_DIR"

# 1) 生成 rkbuild-release 到 rootfs（替换模板中的占位符）
TMPL="${RKB_ROOT}/overlay/board/rockchip/rk3588/fs-overlay/etc/rkbuild-release.tmpl"
RELEASE="${TARGET_DIR}/etc/rkbuild-release"
if [ -f "$TMPL" ]; then
    sed -e "s/__VARIANT__/${VARIANT}/g" "$TMPL" > "$RELEASE"
    echo "[post-image] rkbuild-release: $(cat "$RELEASE")"
fi

# 2) 替换 /etc/motd 中的占位符
MOTD="${TARGET_DIR}/etc/motd"
if [ -f "$MOTD" ]; then
    RELEASE_VER="$(cat "$RELEASE" 2>/dev/null || echo unknown)"
    sed -i \
        -e "s|__VENDOR__|${VENDOR}|g" \
        -e "s|__VARIANT__|${VARIANT}|g" \
        -e "s|__BOARD__|${BOARD}|g" \
        -e "s|__RKBUILD_RELEASE__|${RELEASE_VER}|g" \
        "$MOTD"
fi

# 3) 计算 sha256
if [ -d "$BINARIES_DIR" ]; then
    ( cd "$BINARIES_DIR" && find . -maxdepth 1 -type f -name '*.img' -o -name '*.itb' -o -name '*.dtb' -o -name '*.bin' 2>/dev/null ) \
        | while read -r f; do
            sha256sum "$f" >> "${BINARIES_DIR}/../SHA256SUMS"
        done
fi

# 4) 调用 rkbuild 顶层 mk-sd-image.sh（若已构建完成且用户希望）
#    注意：post-image 只在 rootfs 完成后跑一次；SD 卡镜像打包建议独立执行 make image。
#    这里仅做轻量操作。

echo "[post-image] done."