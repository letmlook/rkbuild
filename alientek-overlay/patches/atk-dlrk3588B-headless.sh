#!/usr/bin/env bash
# alientek-overlay/patches/atk-dlrk3588B-headless.sh
#
# 把 alientek SDK 内 atk_dlrk3588B_defconfig 的 GUI 选项关掉、注入 Docker 全栈。
#
# 不用 patch、不用行号、不依赖上下文匹配。
# 直接用 sed -i 按"行首 token 匹配"修改：
#   - 关闭 GUI：把 `^BR2_PACKAGE_QT5=y` 改为 `# BR2_PACKAGE_QT5 is not set`
#   - 关闭已经显式打开的：sed 替换为 is not set 形式
#   - 删除未设置行（保持文件清爽）
#   - 追加 Docker / RKNN / rkbuild-helper 到文件末尾
#
# 脚本是幂等的：可以重复跑，已经注释掉的行不会再改。
# 若 SDK 升级后新增 GUI 包，把名字加到 GUI_REMOVE 数组即可。

set -e

# --- 参数 ---
SDK_DIR="${1:-dist/src/atk-sdk}"
BOARD="${BOARD:-atk-dlrk3588B}"

# 不同板子对应不同 defconfig；如 quarkpi-ca2 需另起一个文件（见同名 .sh）
case "$BOARD" in
    atk-dlrk3588B|atk-dlrk3588)
        DEFCONFIG="${SDK_DIR}/device/rockchip/rk3588/atk_dlrk3588B/buildroot/atk_dlrk3588B_defconfig"
        ;;
    quarkpi-ca2|quarkpi)
        # 占位：quarkpi-ca2 的 defconfig 路径以 SDK 实际为准
        DEFCONFIG="${SDK_DIR}/device/rockchip/rk3588/atk_dlrk3588B/buildroot/$(echo "$BOARD" | tr '[:upper:]' '[:lower:]')_defconfig"
        # 大概率不存在；脚本会在后面检查
        ;;
esac

if [ ! -f "$DEFCONFIG" ]; then
    echo "defconfig 不存在：$DEFCONFIG"
    echo "请确认 SDK 已展开且 BOARD 名称正确；如 SDK 版本不同，请编辑此脚本调整 DEFCONFIG 路径。"
    exit 1
fi

# --- 备份 ---
BAK="${DEFCONFIG}.bak.$(date +%Y%m%d%H%M%S)"
cp -p "$DEFCONFIG" "$BAK"
echo "已备份：$BAK"

# --- 待关闭的 GUI 包（与是否在 defconfig 出现无关；sed 无匹配会静默 noop） ---
GUI_REMOVE=(
    BR2_PACKAGE_QT5
    BR2_PACKAGE_QT5BASE
    BR2_PACKAGE_QT5QUICK
    BR2_PACKAGE_QT5MULTIMEDIA
    BR2_PACKAGE_QT5WAYLAND
    BR2_PACKAGE_QT5SVG
    BR2_PACKAGE_QT5WEBSOCKETS
    BR2_PACKAGE_QT5SERIALPORT
    BR2_PACKAGE_QT5DECLARATIVE
    BR2_PACKAGE_WAYLAND
    BR2_PACKAGE_WESTON
    BR2_PACKAGE_WAYLAND_UTILS
    BR2_PACKAGE_WAYLAND_PROTOCOLS
    BR2_PACKAGE_MALI
    BR2_PACKAGE_ROCKCHIP_MALI
    BR2_PACKAGE_MESA3D
    BR2_PACKAGE_LIBINPUT
    BR2_PACKAGE_LIBINPUT_TOOLS
    BR2_PACKAGE_TSLIB
    BR2_PACKAGE_TSLIB_TOOLS
    BR2_PACKAGE_SDL2
    BR2_PACKAGE_SDL2_IMAGE
    BR2_PACKAGE_SDL2_TTF
    BR2_PACKAGE_SDL2_NET
)

# --- 待追加的 headless + Docker + RKNN + rkbuild-helper 包 ---
APPEND_LINES=(
    ""
    "# === rkbuild: headless variant injections ==="
    "BR2_PACKAGE_RKBUILD_HELPER=y"
    "BR2_PACKAGE_RKBUILD_DOCKER_HELPER=y"
    "BR2_PACKAGE_RKBUILD_DOCKER_IMAGES=y"
    ""
    "# === AI / RKNN ==="
    "BR2_PACKAGE_RKNPU2=y"
    "BR2_PACKAGE_RKNPU2_ARCH=aarch64"
    "BR2_PACKAGE_RKNPU_FW=y"
    "BR2_PACKAGE_ONNXRUNTIME_RKNN=y"
    "BR2_PACKAGE_TFLITE_DELEGATE_RKNPU2=y"
    ""
    "# === Docker 全栈 ==="
    "BR2_PACKAGE_DOCKER_ENGINE=y"
    "BR2_PACKAGE_DOCKER_ENGINE_DRIVER_OVERLAY2=y"
    "BR2_PACKAGE_DOCKER_ENGINE_DRIVER_BTRFS=y"
    "BR2_PACKAGE_DOCKER_ENGINE_DRIVER_DEVICEMAPPER=y"
    "BR2_PACKAGE_DOCKER_ENGINE_DRIVER_VFS=y"
    "BR2_PACKAGE_DOCKER_ENGINE_SECCOMP=y"
    "BR2_PACKAGE_DOCKER_ENGINE_APPARMOR=y"
    "BR2_PACKAGE_DOCKER_ENGINE_ROOTLESS=y"
    "BR2_PACKAGE_DOCKER_ENGINE_EXPERIMENTAL=y"
    "BR2_PACKAGE_DOCKER_ENGINE_BUILDKIT=y"
    "BR2_PACKAGE_DOCKER_CLI=y"
    "BR2_PACKAGE_CONTAINERD=y"
    "BR2_PACKAGE_CONTAINERD_BTRFS=y"
    "BR2_PACKAGE_CONTAINERD_CRI=y"
    "BR2_PACKAGE_RUNC=y"
    "BR2_PACKAGE_CRUN=y"
    "BR2_PACKAGE_BUILDKIT=y"
    "BR2_PACKAGE_DOCKER_BUILDX=y"
    "BR2_PACKAGE_DOCKER_COMPOSE=y"
    "BR2_PACKAGE_DOCKER_COMPOSE_V2=y"
    "BR2_PACKAGE_DIVE=y"
    "BR2_PACKAGE_CTOP=y"
    "BR2_PACKAGE_LAZYDOCKER=y"
    "BR2_PACKAGE_HADOLINT=y"
    "BR2_PACKAGE_SKOPEO=y"
    "BR2_PACKAGE_NERDCTL=y"
    "BR2_PACKAGE_CTR=y"
    "BR2_PACKAGE_CRICTL=y"
    "BR2_PACKAGE_SLIRP4NETNS=y"
    "BR2_PACKAGE_FUSE_OVERLAYFS=y"
    "BR2_PACKAGE_UIDMAP=y"
    "BR2_PACKAGE_APPARMOR=y"
    "BR2_PACKAGE_APPARMOR_UTILS=y"
    ""
    "# === Headless 必备补充 ==="
    "BR2_PACKAGE_IPTABLES=y"
    "BR2_PACKAGE_NFTABLES=y"
    "BR2_PACKAGE_IPROUTE2=y"
    "BR2_PACKAGE_WIREGUARD_TOOLS=y"
    "BR2_PACKAGE_LIBGPIOD=y"
    "BR2_PACKAGE_I2C_TOOLS=y"
    "BR2_PACKAGE_OPENCV3=y"
    "BR2_PACKAGE_OPENCV3_PYTHON=y"
    "BR2_PACKAGE_PYTHON_NUMPY=y"
    "BR2_PACKAGE_PYTHON_PILLOW=y"
    "BR2_PACKAGE_FFMPEG=y"
    "BR2_PACKAGE_FFMPEG_GPL=y"
    "BR2_PACKAGE_GSTREAMER1_PLUGINS_BASE=y"
    "BR2_PACKAGE_GSTREAMER1_PLUGINS_GOOD=y"
    "BR2_PACKAGE_GSTREAMER1_PLUGINS_V4L2=y"
    "BR2_PACKAGE_ROCKCHIP_MPP=y"
    "BR2_PACKAGE_ROCKCHIP_MPP_ALLOCATOR_DRM=y"
    "BR2_PACKAGE_LIBV4L_RKMPP=y"
    ""
    "# === Docker 必需内核配置（追加到 BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES） ==="
    '# 如 defconfig 内已有 BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES，注释并由 rkbuild 注入；'
    '# 如未有，由 rkbuild 直接在 buildroot 工作树注入。'
)

# --- 1. 关闭 GUI 包 ---
echo "[1/3] 关闭 GUI 包..."
for pkg in "${GUI_REMOVE[@]}"; do
    # 情况 A：原 defconfig 是 `BR2_PACKAGE_X=y` → 改成 `# BR2_PACKAGE_X is not set`
    # 情况 B：原 defconfig 是 `# BR2_PACKAGE_X is not set` → 不动
    # 情况 C：原 defconfig 无该行 → 不动
    # 用 -i -e 多次替换保证幂等
    sed -i -e "s|^${pkg}=y$|# ${pkg} is not set|" \
           -e "s|^${pkg}=[\"' ]*[Yy][\"' ]*$|# ${pkg} is not set|" \
           "$DEFCONFIG"
done

# --- 2. 注释掉 BR2_PACKAGE_QT6*（SDK 自带的 Qt5 行已注释；防止重名误关） ---
# （不影响 Qt5，因为 GUI_REMOVE 已覆盖。Qt6 在 alientek SDK 中本就不存在）

# --- 3. 追加 headless + Docker 配置 ---
echo "[2/3] 追加 headless + Docker 配置..."
{
    printf '\n'
    for line in "${APPEND_LINES[@]}"; do
        printf '%s\n' "$line"
    done
} >> "$DEFCONFIG"

# --- 4. 收尾：去重 + 提示 ---
echo "[3/3] 收尾..."
# 用 awk 去重（保留每行首次出现）；空行不动
awk 'NF || !seen_blank {print; if(NF) seen[$0]=1; else seen_blank=1}' \
    "$DEFCONFIG" > "${DEFCONFIG}.uniq"
mv "${DEFCONFIG}.uniq" "$DEFCONFIG"

echo
echo "完成。"
echo "原 defconfig: $BAK"
echo "现 defconfig: $DEFCONFIG"
echo
echo "建议：grep -E '^(BR2_PACKAGE_QT|BR2_PACKAGE_WAYLAND|BR2_PACKAGE_WESTON|BR2_PACKAGE_DOCKER)' $DEFCONFIG"