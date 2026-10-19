# rkbuild

RK3588 一键 Buildroot / Ubuntu 22.04 镜像编译 + 交叉编译 SDK 打包脚本。

支持三家厂商（Rockchip 官方 / FriendlyElec 友善之臂 / 正点原子 Alientek），每家支持 GUI 与 Headless 两个变体，默认软件包含完整 Docker 引擎栈与 RKNN AI 推理后端。

此外，Rockchip 官方 BSP 额外支持 **Ubuntu 22.04 (jammy)** 根文件系统镜像与对应的交叉 SDK（`ROOTFS=ubuntu`，仅 `VENDOR=rockchip`）。

## 快速开始（5 步）

```bash
# 1. 安装编译依赖（apt）
sudo make init

# 2. 拉源码（默认 vendor=rockchip, rootfs=buildroot, variant=gui）
make fetch

# 3. 应用 defconfig
make defconfig

# 4. 编译镜像
make build

# 5. 烧写到 SD 卡
sudo dd if=dist/images/rk3588-sd-*.img of=/dev/sdX bs=4M status=progress
```

Ubuntu 22.04 镜像：

```bash
make fetch ROOTFS=ubuntu VARIANT=headless
make build ROOTFS=ubuntu VARIANT=headless
make image ROOTFS=ubuntu VARIANT=headless
make sdk   ROOTFS=ubuntu VARIANT=headless
# → dist/images/rk3588-ubuntu-headless-sd-<date>.img.xz
# → dist/sdk/rk3588-rockchip-ubuntu22.04-headless-<date>-sdk.tar.xz
```

更多用法见 `docs/quickstart.md` 与 `docs/ubuntu.md`。

## 主要能力

- 三厂商 × 两变体（GUI / Headless）= 6 种默认产出组合
- 完整 Docker（dockerd + containerd + runc/crun + buildkit + compose + buildx + nerdctl + ctr/crictl + dive + ctop + hadolint + skopeo + crane + lazydocker + rootless 全栈）
- 完整 RKNN AI 运行时（rknpu2 + rknn-toolkit-lite2 + onnxruntime-rknn + tflite-delegate-rknpu2）
- 完整多媒体栈（GStreamer1 全家 + ffmpeg + rockchip-mpp + libv4l-rkmpp + rga + mali）
- Qt6 GUI 栈（qt6base EGLFS + 全部常用模块 + tslib + libinput）
- 完整网络栈（iptables-nft + wireguard + ppp + 全套 iproute2）
- 一键打包交叉编译 SDK（`make sdk`）
- 一键生成可烧写 SD 卡镜像（`make image`）
- **Rockchip Ubuntu 22.04**：官方 ubuntu-base + qemu chroot 定制，mainline U-Boot + extlinux 启动，
  独立 `ROOTFS=ubuntu` 流程与 Ubuntu sysroot 交叉 SDK（仅 `VENDOR=rockchip`）

## 厂商 × 变体

|                | GUI（默认） | Headless |
|----------------|--------------|----------|
| `rockchip`（默认）| ✅ | ✅ |
| `friendlyarm`    | ✅ | ✅ |
| `alientek`       | ✅ | ✅（需 headless patch） |

切换：`VENDOR=xxx make fetch`、`VARIANT=headless make defconfig`。

根文件系统：`ROOTFS=buildroot`（默认）或 `ROOTFS=ubuntu`（仅 rockchip；见 [`docs/ubuntu.md`](docs/ubuntu.md)）。

## 目录速览

```
rkbuild/
├── PLAN.md                   # 方案定稿（已批准）
├── Makefile                  # make init/fetch/defconfig/build/sdk/image/clean
├── envsetup.sh               # source 后提供 rkb-* 别名
├── VERSION
├── scripts/                  # 所有 shell 脚本
├── vendors/                  # 厂商配置（*.ini）
├── overlay/                  # defconfig 片段、bridge fs-overlay、自有 local package
├── ubuntu/                   # Ubuntu 22.04 板级配置、包清单、rootfs overlay
├── alientek-overlay/         # 正点原子专属 patch 与配置
├── docs/                     # 文档（quickstart/sdk-usage/...）
└── dist/                     # 产出（src/, ubuntu/, images/, sdk/）
```

## 详细文档

- [`docs/quickstart.md`](docs/quickstart.md) —— 5 步上手
- [`docs/ubuntu.md`](docs/ubuntu.md) —— Rockchip Ubuntu 22.04 镜像与交叉 SDK
- [`docs/vendor-support.md`](docs/vendor-support.md) —— 三家厂商差异
- [`docs/variant-guide.md`](docs/variant-guide.md) —— GUI vs Headless 选择
- [`docs/alientek.md`](docs/alientek.md) —— 正点原子专属操作
- [`docs/sdk-usage.md`](docs/sdk-usage.md) —— 交叉 SDK 使用
- [`docs/docker-on-rk3588.md`](docs/docker-on-rk3588.md) —— Docker 完整功能说明
- [`docs/default-software.md`](docs/default-software.md) —— 默认软件清单
- [`docs/adding-board.md`](docs/adding-board.md) —— 添加新板 / 新厂商
- [`docs/troubleshooting.md`](docs/troubleshooting.md) —— 常见问题

## 许可

脚本采用 Apache-2.0；具体使用到的第三方代码（Buildroot / Linux / U-Boot / Docker / 各厂商 BSP）按各自许可证。