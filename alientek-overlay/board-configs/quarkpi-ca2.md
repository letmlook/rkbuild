# alientek-overlay/board-configs/quarkpi-ca2.md
#
# 正点原子 QuarkPi-CA2（卡电脑）说明

## 板子硬件
- SoC: Rockchip RK3588S（低功耗版 RK3588）
- CPU: 4× Cortex-A76 + 4× Cortex-A55
- GPU: Mali-G610
- NPU: RKNN NPU 2.0
- 内存: 4GB/8GB LPDDR4x
- 网络: 千兆 Ethernet + WiFi 6
- 显示: HDMI 2.1
- USB: USB 3.0×1、USB-C PD×1
- 其它: 3.5mm 耳麦、M.2 PCIe 2230

## 构建
```bash
export VENDOR=alientek BOARD=quarkpi-ca2 VARIANT=gui   # 或 headless
make fetch && make build
```

## 与 atk-dlrk3588B 的差异
- 板级 DTS：device/rockchip/rk3588/atk_dlrk3588B → quarkpi_ca2（inferred）
- 内核配置差异：MIPI DSI 与 CSI 关闭
- 烧写方法：sd-fuse_rk3588 风格 / rkdeveloptool

注：正点原子官方 SDK 内 QuarkPi 的具体 defconfig 名（rk3588s_quarkpi_defconfig 或 quarkpi_ca2_defconfig）
    需以实际 SDK 版本为准。本文档为推断。