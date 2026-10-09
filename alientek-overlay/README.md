# alientek-overlay/ —— 正点原子专用 overlay
#
# alientek vendor 的 SDK tarball（来自 Mega.nz）使用 Rockchip 5.10 BSP 流派，
# 不能像 radxa/buildroot 那样用 kconfig `#include` 注入。
# 本目录提供：
#   - patches/          剥离 GUI / 注入 Docker 的 patch（可选）
#   - board-configs/    参考板子配置（用户可手改 SDK 内的 defconfig）
#   - README.md         本文件

## headless patch 用法

```bash
export VENDOR=alientek VARIANT=headless
make fetch      # 自动应用 patches/atk-dlrk3588B-headless.patch
make build
```

GUI 模式（默认）下不应用 patch；保留 SDK 全部默认（Qt5/weston/mali）。

## 注意

- 本目录 patch 是占位实现；具体行号需根据 SDK tarball 实际版本微调。
- `patches/<board>-headless.patch` 的实际内容由用户首次下载 SDK 后通过：
  ```bash
  cd dist/src/atk-sdk
  cp device/rockchip/rk3588/atk_dlrk3588B/buildroot/atk_dlrk3588B_defconfig /tmp/before.config
  # 手工去掉 qt5 / weston / wayland / mali，加入 docker / containerd / runc 等
  diff -u /tmp/before.config buildroot/atk_dlrk3588B_defconfig > alientek-overlay/patches/atk-dlrk3588B-headless.patch
  ```
- 详见 docs/alientek.md。