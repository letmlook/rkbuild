# 正点原子 Alientek 专属操作

正点原子的 SDK 与 Radxa/FriendlyElec 不同：它不是 git 树，而是 **单 tarball**（多 GB），内部是 Rockchip 5.10 BSP（frozen Buildroot + Qt5 5.15.8 + weston 12 + gstreamer 1.22 + python 3.10 + opencv 4.5）。

## 来源

- 板子 SDK 仓库：[github.com/openedv](https://github.com/openedv)
  - ATK-DLRK3588B: `github.com/openedv/development_board_ATK-DLRK3588B`
  - QuarkPi-CA2: `github.com/openedv/card_computer_QuarkPi-CA2-RK3588S`
- Mega.nz 实际 SDK tarball（来自上述 README）：
  - ATK-DLRK3588B: `https://mega.nz/folder/T1QyjKSI#ysQfY6-w_V1g0kBio79TOQ`
  - QuarkPi-CA2: `https://mega.nz/folder/T5IFzCbA#AIn2Du1vLvzdMlVGcQH4_Q`

## 自动下载（推荐）

`make init` 已经会安装 `megatools`：

```bash
export VENDOR=alientek BOARD=atk-dlrk3588B
make fetch
# 检测到 megatools 自动 megatools dl <url>
```

> Mega.nz 偶尔会更新下载链接或增加新目录；若 megatools 失败，下方有手放 tarball 方案。

## 手动放 tarball

如果自动下载失败：

```bash
# 1. 浏览器打开 https://mega.nz/flder/T1QyjKSI#ysQfY6-w_V1g0kBio79TOQ
# 2. 下载整个目录（包含 SDK tarball 与 PDF 手册）
# 3. 把 SDK 主 tarball 重命名为 atk-sdk-atk-dlrk3588B.tar.xz 放到：
mkdir -p dist/src
cp ~/Downloads/<sdk>.tar.xz dist/src/atk-sdk-atk-dlrk3588B.tar.xz

# 4. 重跑 make fetch
make fetch
```

也可以填写 `vendors/alientek.ini` 中的 `ATK_DLRK3588B_SHA256=` 让脚本自动校验。

## 编译

```bash
export VENDOR=alientek BOARD=atk-dlrk3588B    # GUI（默认）
make fetch && make build
```

等价于：

```bash
cd dist/src/atk-sdk
./build.sh atk-dlrk3588B -j$(nproc)
```

## Headless 模式

剥离 Qt5/weston/wayland/mali，注入 Docker 全栈：

```bash
export VENDOR=alientek BOARD=atk-dlrk3588B VARIANT=headless
make fetch
make build
```

`make fetch` 自动应用 `alientek-overlay/patches/atk-dlrk3588B-headless.patch`。

### 首次生成 headless patch

当前 `patches/atk-dlrk3588B-headless.patch` 是占位。首次 fetch 后：

```bash
cd dist/src/atk-sdk

# 备份原 defconfig
cp device/rockchip/rk3588/atk_dlrk3588B/buildroot/atk_dlrk3588B_defconfig \
   /tmp/before.config

# 编辑去掉 GUI / 加入 Docker
vim /tmp/before.config
# （注释 BR2_PACKAGE_QT5 / WAYLAND / WESTON / MALI / LIBINPUT / TSLIB / SDL2 / MESA3D
#   加上 BR2_PACKAGE_DOCKER_ENGINE / CONTAINERD / RUNC / CRUN / BUILDKIT /
#   DOCKER_BUILDX / DOCKER_COMPOSE / DIVE / CTOP / LAZYDOCKER / HADOLINT /
#   SKOPEO / NERDCTL / CTR / CRICTL / APPARMOR / RKNPU2 / RKBUILD_HELPER 等）

# 生成 patch
diff -u /tmp/before.config \
        device/rockchip/rk3588/atk_dlrk3588B/buildroot/atk_dlrk3588B_defconfig \
        > ../../../alientek-overlay/patches/atk-dlrk3588B-headless.patch

# 重跑
make clean
make fetch    # 自动应用新 patch
make build
```

## 输出路径

```
dist/src/atk-sdk/output/<board>/
├── boot.img
├── rootfs.ext4
├── u-boot.itb
├── parameter.txt
└── ...
```

烧写：

```bash
sudo dd if=dist/src/atk-sdk/output/atk-dlrk3588B/rootfs.ext4 of=/dev/sdX bs=4M status=progress
```

或用 `rkdeveloptool` 烧写完整 update.img。

## SDK 打包

```bash
make sdk
# → dist/sdk/rk3588-alientek-<VARIANT>-<DATE>.tar.xz
```

alientek SDK 内部已包含完整工具链（prebuilts/）+ sysroot。脚本会从 atk-sdk/prebuilts/ + buildroot/output/<board>/host/ 打包。

## 板子特定硬件

| 硬件 | 加载方式 | 默认配置文件 |
|---|---|---|
| RTL8733BU USB WiFi+BT | `modprobe 8733bu` + `/etc/init.d/S36wifibt-init.sh` | `/etc/wifibt.conf` |
| Fibocom FG132 5G | `fibocom-dial -s 3gnet &` | `/etc/ppp/peers/` |
| IMX415 4× MIPI CSI | kernel `rk3588-atk-dlrk3588.dtb` | `/dev/video6[2,3,4]` |
| SH3001 IMU | kernel driver | `/dev/i2c-*` |
| ES8388 codec | kernel sound | `alsa.conf` |
| ATK-MD0550 5.5" 1080p MIPI DSI | kernel panel driver | weston display config |

## 注意事项

- alientek SDK 的 frozen Buildroot 与上游 Buildroot API 有差异；**不能**直接用 `make` 命令做 defconfig 切换。
- 自定义包（rkbuild-helper / onnxruntime-rknn 等）通过 patch 注入到 SDK 内的 defconfig，不走 `package/local/` 自动扫描。
- alientek-overlay 仅有参考文档与占位 patch；真实 patch 由用户首次 fetch 后手工生成。
- QuarkPi-CA2 是 RK3588S（低功耗版）；其 buildroot defconfig 名（`rk3588s_quarkpi_defconfig` 等）以 SDK 实际为准。