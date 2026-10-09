# alientek-overlay/ —— 正点原子专用 overlay
#
# alientek vendor 的 SDK tarball（来自 Mega.nz）使用 Rockchip 5.10 BSP 流派，
# 不能像 radxa/buildroot 那样用 kconfig `#include` 注入。
# 本目录提供：
#   - patches/          剥离 GUI / 注入 Docker 的脚本（sed，非 patch）
#   - board-configs/    参考板子配置（用户可手改 SDK 内的 defconfig）
#   - README.md         本文件

## headless 注入脚本用法

```bash
export VENDOR=alientek BOARD=atk-dlrk3588B VARIANT=headless
make fetch      # 自动运行 patches/atk-dlrk3588B-headless.sh
make build
```

GUI 模式（默认）下不运行注入脚本；保留 SDK 全部默认（Qt5/weston/mali）。

## 为什么不用 patch

- patch 依赖行号 + 上下文匹配，SDK 升级后即使包名不变也会失败
- 用 sed 按"行首 token"修改，**不依赖行号**，对 SDK 升级鲁棒
- 幂等：可重复跑

详见 [`patches/README.md`](patches/README.md) 与 [`../docs/alientek.md`](../docs/alientek.md)。