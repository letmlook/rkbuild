# alientek-overlay/board-configs/atk-dlrk3588B.md
#
# 正点原子 ATK-DLRK3588B 板子说明（GUI 模式 / Headless 模式）

## 板子硬件
- SoC: Rockchip RK3588
- CPU: 4× Cortex-A76 + 4× Cortex-A55
- GPU: Mali-G610
- NPU: RKNN NPU 2.0（最高 6 TOPS）
- 内存: 4GB/8GB/16GB LPDDR4x
- 网络: 千兆 Ethernet + WiFi 6（RTL8852BU）
- 显示: HDMI 2.1 + MIPI DSI（ATK-MD0550）
- 摄像头: 4× MIPI CSI（IMX415）
- 其它: USB 3.0×2、USB 2.0×2、PCIe 3.0、SATA 3.0、ES8388 codec

## SDK 默认提供（GUI 模式）
- Linux 5.10-gen-rkr8 BSP
- Buildroot（frozen，与 BSP 版本绑定）
- Qt5 5.15.8（qml）
- gstreamer 1.22.2 + wayland/weston 12.0.1
- ffmpeg 4.4.1 + rockchip-mpp
- python 3.10.5 + opencv 4.5.4
- nginx 1.20.1

## GUI 模式构建（默认）
```bash
export VENDOR=alientek BOARD=atk-dlrk3588B VARIANT=gui
make fetch      # 下载 SDK tarball（含 GUI）
make build      # cd atk-sdk && ./build.sh atk-dlrk3588B
```

## Headless 模式构建
```bash
export VENDOR=alientek BOARD=atk-dlrk3588B VARIANT=headless
make fetch      # 下载 SDK + 应用 patches/atk-dlrk3588B-headless.patch
make build      # 剥离 Qt5/weston/wayland/mali，加入 Docker/RKNN
```

## 输出路径
- GUI: dist/src/atk-sdk/output/<board>/images/rootfs.ext4
- Headless: 同上（patch 修改了 buildroot defconfig）
- 镜像烧写: rkdeveloptool 或 balenaEtcher

## 常见定制
- 修改 device/rockchip/rk3588/atk_dlrk3588B/buildroot/atk_dlrk3588B_defconfig
- 加包：BR2_PACKAGE_XXX=y
- 删包：BR2_PACKAGE_XXX is not set
- 重新编译：cd atk-sdk && ./build.sh atk-dlrk3588B