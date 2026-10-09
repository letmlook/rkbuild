# rkbuild

RK3588 一键 Buildroot 镜像编译 + 交叉编译 SDK 打包脚本。

支持三家厂商（Rockchip 官方 / FriendlyElec 友善之臂 / 正点原子 Alientek），每家支持 GUI 与 Headless 两个变体，默认软件包含完整 Docker 引擎栈与 RKNN AI 推理后端。

## 快速开始（5 步）

```bash
# 1. 安装编译依赖（apt）
sudo make init

# 2. 拉源码（默认 vendor=rockchip, variant=gui）
make fetch

# 3. 应用 defconfig
make defconfig

# 4. 编译镜像
make build

# 5. 烧写到 SD 卡
sudo dd if=dist/images/rk3588-sd-*.img of=/dev/sdX bs=4M status=progress
```

更多用法见 `docs/quickstart.md`。

## 主要能力

- 三厂商 × 两变体（GUI / Headless）= 6 种默认产出组合
- 完整 Docker（dockerd + containerd + runc/crun + buildkit + compose + buildx + nerdctl + ctr/crictl + dive + ctop + hadolint + skopeo + crane + lazydocker + rootless 全栈）
- 完整 RKNN AI 运行时（rknpu2 + rknn-toolkit-lite2 + onnxruntime-rknn + tflite-delegate-rknpu2）
- 完整多媒体栈（GStreamer1 全家 + ffmpeg + rockchip-mpp + libv4l-rkmpp + rga + mali）
- Qt6 GUI 栈（qt6base EGLFS + 全部常用模块 + tslib + libinput）
- 完整网络栈（iptables-nft + wireguard + ppp + 全套 iproute2）
- 一键打包交叉编译 SDK（`make sdk`）
- 一键生成可烧写 SD 卡镜像（`make image`）

## 厂商 × 变体

|                | GUI（默认） | Headless |
|----------------|--------------|----------|
| `rockchip`（默认）| ✅ | ✅ |
| `friendlyarm`    | ✅ | ✅ |
| `alientek`       | ✅ | ✅（需 headless patch） |

切换：`VENDOR=xxx make fetch`、`VARIANT=headless make defconfig`。

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
├── alientek-overlay/         # 正点原子专属 patch 与配置
├── docs/                     # 文档（quickstart/sdk-usage/...）
└── dist/                     # 产出（src/, images/, sdk/）
```

## 详细文档

- [`docs/quickstart.md`](docs/quickstart.md) —— 5 步上手
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