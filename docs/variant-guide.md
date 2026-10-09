# GUI vs Headless 变体

rkbuild 为每个厂商提供两个变体：

| 变体 | defconfig 文件 | 适用场景 |
|---|---|---|
| **GUI**（默认） | `rkbuild_rk3588_gui_defconfig` | 桌面、HMI、信息亭、需要 Qt 应用、需要显示输出 |
| **Headless** | `rkbuild_rk3588_headless_defconfig` | 服务器、容器宿主机、AI 推理盒、视频转码盒、无人值守设备 |

切换：

```bash
make defconfig VARIANT=gui         # GUI（默认）
make defconfig VARIANT=headless    # Headless
make build VARIANT=gui
```

## GUI 变体包含

- **Qt6**（EGLFS 后端）：qt6base + qt6declarative + qt6quickcontrols2 + qt6multimedia + qt6svg + qt6websockets + qt6serialport + qt6shadertools + qt6wayland
- **显示栈**: weston (DRM + Demo Clients) + wayland + wayland-utils
- **GPU**: mesa3d + rockchip-mali（valhall-g610）
- **输入**: tslib（触摸屏）+ libinput
- **应用辅助**: SDL2（GUI 应用 + 多媒体调试）

## Headless 变体保留

即使没有显示输出，Headless 变体仍包含：

- **服务端转码**：ffmpeg + rockchip-mpp + libv4l-rkmpp + rockchip-rga（RGA 用于离屏图像处理）
- **AI 推理**：rknpu2 + rknpu-fw + onnxruntime-rknn + tflite-delegate-rknpu2
- **Docker 全套**（与 GUI 变体一致）
- **网络全套**：iptables-nft + ppp + wireguard + 全套 iproute2
- **库全套**：openssl、mbedtls、cJSON、jansson、msgpack-c、libcurl、libmosquitto、libwebsockets、sqlite、protobuf-c、flatbuffers、zstd、snappy、mongoose、libuv
- **Python3 全套**：pip + numpy + opencv + pillow
- **外设**：libgpiod、i2c-tools、can-utils、spidev-test、libmodbus

## 何时用哪个

| 场景 | 推荐 |
|---|---|
| 智能家居中控屏、楼宇对讲屏、商显广告机 | GUI |
| 工业 HMI、Qt 应用、wayland 应用 | GUI |
| AI 推理盒子、视频转码服务器、NVR | Headless |
| Docker 宿主机、k8s node | Headless |
| 边缘网关、IoT 网关 | Headless |
| 数字孪生、3D 可视化 | GUI |
| 网络应用服务器（VPN / 防火墙 / DNS）| Headless |
| 网络摄像头 IPC | Headless |

## 硬件开销对比（参考）

| 项 | GUI | Headless | 差值 |
|---|---|---|---|
| rootfs 大小 | ~1.6 GB | ~1.2 GB | -400 MB |
| 启动时间 | 8-12 s（weston） | 4-6 s | -4 s |
| 空载内存 | 280 MB | 120 MB | -160 MB |
| GPU 占用 | Mali 驱动 +30 MB | - | -30 MB |

> 仅供参考；具体数字依 Qt 应用复杂度与 systemd vs busybox init 变化。

## Headless 也可后加 GUI

如已用 Headless 镜像但想装 Qt 应用：

```bash
opkg install qt6base qt6declarative weston    # 假设有 opkg
# 或重新 make defconfig VARIANT=gui && make build
```

Headless 镜像不安装 Qt 是为了节省空间，不是硬性限制。

## alientek 厂商变体

正点原子 SDK 默认是 GUI 模式（自带 Qt5/weston）。切到 Headless：

```bash
export VENDOR=alientek BOARD=atk-dlrk3588B VARIANT=headless
make fetch    # 自动应用 patches/atk-dlrk3588B-headless.patch
make build
```

`alientek-overlay/patches/atk-dlrk3588B-headless.patch` 默认是占位模板；
首次 fetch 后请根据 SDK 实际 defconfig 用 `diff -u` 生成真实可用版本（见
`alientek-overlay/patches/README.md`）。