# 默认软件清单

rkbuild 默认把常用软件全部编入镜像。两变体（GUI / Headless）共有清单 + GUI 专属清单。

## 共有清单（GUI + Headless）

### 系统基础

- busybox + eudev（systemd 可选启用）
- dropbear（SSH 后备）
- openssh（SSH 服务）
- chrony（时间同步）
- rng-tools + haveged（熵源）
- logrotate + syslog-ng（日志）
- e2fsprogs + btrfs-progs + dosfstools + parted + pciutils + util-linux
- rkbuild-helper（自写辅助：rkbuild-info / rkbuild-doctor / rkbuild-docker-preload）

### 网络

- iptables + nftables + iproute2 + bridge-utils + vlan
- wpa_supplicant + hostapd + dhcpcd + dnsmasq
- tcpdump + nmap + ncat + ethtool + mii-tool
- pppd（PPP 拨号）
- wireguard-tools（VPN）
- c-ares（异步 DNS）

### 外设/硬件调试

- libgpiod（新式 GPIO）
- i2c-tools（I2C 工具集）
- spidev-test（SPI 测试）
- can-utils（CAN 工具集）
- libmodbus（Modbus 协议库）

### 多媒体（headless 保留转码能力）

- gstreamer1 {base, good, bad, ugly, libav, x264, v4l2}
- gstreamer1-rockchip（rkmpp 解码插件）
- ffmpeg（启用 rockchip-mpp 硬件解码）
- rockchip-mpp + libv4l-rkmpp + rockchip-rga + libdrm
- alsa-lib + alsa-utils + tinyalsa

### AI / 推理

- rknpu2 + rknpu-fw（系统层 rknn_server + librknn_api）
- python3 + python3-pip + python3-numpy + python3-pillow + opencv3
- rknn-toolkit-lite2（Python 推理）
- **onnxruntime-rknn**（自有 local 包，RKNN 后端 ONNX Runtime）
- **tflite-delegate-rknpu2**（自有 local 包，RKNN delegate TFLite）

### 工具

- iperf3（带宽测试）
- smartmontools（磁盘健康）
- lm-sensors（温度/电压）
- stress-ng（压测）
- sysstat（性能监控）
- tmux + vim + bash-completion
- htop + lsof

### 常用库

| 类别 | 包 |
|---|---|
| TLS/加密 | openssl、mbedtls |
| 数据格式 | cJSON、jansson、msgpack-c、libconfuse |
| 网络 | libcurl、libmosquitto（MQTT）、libwebsockets |
| 数据库 | sqlite |
| RPC/数据 | protobuf-c、flatbuffers |
| 多媒体辅助 | libusb、libpng、libjpeg-turbo、libwebp、freetype |
| 压缩 | zstd、snappy（lz4 由 Buildroot 默认开启） |
| 嵌入式 Web | mongoose（C 单文件 HTTP+WebSocket） |
| 事件循环 | libuv |
| 杂项 | libuuid |

### Docker 完整栈（两变体共有，不裁剪）

详见 [`docker-on-rk3588.md`](docker-on-rk3588.md)。

## 仅 GUI 变体

### Qt6（默认）

- qt6base（EGLFS 后端，依赖 rockchip-mali 提供的 EGL/GBM）
- qt6declarative + qt6quickcontrols2 + qt6multimedia
- qt6svg + qt6websockets + qt6serialport + qt6shadertools
- qt6wayland + qt6imageformats + qt6scxml

### GUI 支撑栈

- wayland + weston（DRM backend + demo clients）
- mesa3d（rockchip + panfrost + lima + kmsro + vulkan）
- rockchip-mali（valhall-g610）

### 输入

- tslib（触摸屏）
- libinput（输入设备处理）

### 应用辅助

- SDL2 + SDL2_image + SDL2_ttf + SDL2_net

## 按需关闭 / 开启

如有不需要的包，用 `make menuconfig` 关闭：

```bash
make menuconfig
# 例如关掉 lazydocker：
# Package Selection → Utilities → lazydocker → [ ]
```

保存退出后，`make savedefconfig` 自动覆盖 `overlay/defconfig/rkbuild_rk3588_<variant>_defconfig`（如有提示确认）。

## 自有 local package 列表

| 包名 | 提供 |
|---|---|
| rkbuild-helper | 启动 + 演示命令 |
| onnxruntime-rknn | RKNN 后端 ONNX Runtime |
| tflite-delegate-rknpu2 | RKNN delegate TFLite |
| rkbuild-docker-helper | Docker 演示命令 + 预置镜像目录 |
| rkbuild-docker-images | firstboot 自动 docker load 预置镜像 |