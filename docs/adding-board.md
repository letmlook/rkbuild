# 添加新板 / 新 SoC

本节说明如何扩展 rkbuild 支持新板或新 SoC。

## 场景 A：radxa/buildroot 流派内的新板

例：在 rockchip 流派下增加对 `rock-5-itx` 板子的支持。

### 1. 准备板子的 kernel/u-boot 分支

通常 vendor 提供：
- `kernel` git repo + 分支（如 `nanopi6-v6.1.y`）
- `u-boot` git repo + 分支

把这些写到 `vendors/<vendor>.ini`：

```ini
KERNEL_REPO=https://github.com/.../kernel
KERNEL_BRANCH=<branch>
UBOOT_REPO=https://github.com/.../u-boot
UBOOT_BRANCH=<branch>
```

### 2. 板级 DTS / config

新建 `overlay/board/<vendor>/<board>/`：

```
overlay/board/myvendor/myboard/
├── fs-overlay/          # 可选：/etc 下放板级配置
├── kernel-fragment.config   # 板级内核配置片段
├── post-image.sh        # 可选：构建后处理
└── readme.txt
```

更新 defconfig 让 BR2_ROOTFS_OVERLAY 指向它：

```kconfig
BR2_ROOTFS_OVERLAY="board/myvendor/myboard/fs-overlay"
BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES+="$(TOPDIR)/../board/myvendor/myboard/kernel-fragment.config"
```

### 3. 提交 defconfig 入口

新增 `overlay/defconfig/rkbuild_myboard_gui_defconfig` + `..._headless_defconfig`，模板：

```kconfig
#include "rockchip_<soc>_defconfig"
#include "../fragments/rkbuild_base.config"
#include "../fragments/rkbuild_default.config"
#include "../fragments/rkbuild_gui.config"     # GUI 才有
#include "../fragments/rkbuild_docker.config"
#include "../fragments/rkbuild_mirrors.config"

BR2_ROOTFS_OVERLAY="board/myvendor/myboard/fs-overlay"
BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES="$(TOPDIR)/../board/myvendor/myboard/kernel-fragment.config"
```

### 4. 在 buildroot defconfig 中标记对应 board

radxa/buildroot 用 `RK_BOARD` / `BR2_TARGET_<SOC>` 等变量。把板子映射到对应的 BR2_ 变量写在 defconfig 中。

### 5. 测试

```bash
make fetch
make defconfig
make build
```

## 场景 B：新增一个 vendor

例：Firefly 或 Orange Pi。

### 1. 创建 vendors/<vendor>.ini

```ini
VENDOR_NAME=firefly
VENDOR_DESC=Firefly ROC-RK3588S-PC

BUILDROOT_REPO=https://github.com/radxa/buildroot   # 沿用
BUILDROOT_BRANCH=rockchip/2024.02
BUILDROOT_DEFCONFIG=rockchip_rk3588_defconfig

KERNEL_REPO=https://github.com/...
KERNEL_BRANCH=...
UBOOT_REPO=https://github.com/...
UBOOT_BRANCH=...

TOOLCHAIN_URL=...

BOARDS="roc-rk3588s-pc firefly-itx"

DEFCONFIG_GUI=rkbuild_rk3588_gui_defconfig
DEFCONFIG_HEADLESS=rkbuild_rk3588_headless_defconfig
```

### 2. 创建 scripts/fetch-<vendor>.sh

参考 `scripts/fetch-rockchip.sh` 模板：

```bash
#!/usr/bin/env bash
# fetch-firefly.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RKB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export RKB_ROOT
source "${SCRIPT_DIR}/common.sh"

KERNEL_REPO="$(rkb_vendor_get KERNEL_REPO)"
KERNEL_BRANCH="$(rkb_vendor_get KERNEL_BRANCH)"
# ... 其他与 fetch-rockchip.sh 类似

rkb_git_clone "$KERNEL_REPO" "${SRC_DIR}/kernel" "$KERNEL_BRANCH"
# ... 克隆所有仓库

bash "${SCRIPTS_DIR}/apply-overlay.sh"
```

### 3. 在 scripts/fetch-source.sh 中加 case

```bash
case "$VENDOR" in
    ...
    firefly)
        exec bash "${SCRIPTS_DIR}/fetch-firefly.sh"
        ;;
esac
```

### 4. 更新 vendors/README.md 与 docs/vendor-support.md

## 场景 C：alientek 风格的 vendor（无 git tree）

如 Firefly（其 RK3588 SDK 也走 Mega.nz 风格），参考：

1. `vendors/alientek.ini` 复制一份为 `vendors/firefly.ini`
2. 修改 URL 与 SHA256
3. `scripts/fetch-alientek.sh` 复制为 `scripts/fetch-firefly.sh`，改 board 名
4. `scripts/fetch-source.sh` 加 case 分支

## 场景 D：新增 SoC（非 RK3588）

如未来要支持 RK3576 / RK3568：

1. `vendors/rockchip.ini` 中加 `BOARDS="rk3588 rk3576 rk3568"`
2. 复制 `overlay/defconfig/rkbuild_rk3588_*` → `rkbuild_rk3576_*` 并改 `#include` 的 base defconfig
3. `overlay/board/rockchip/rk3588/` 复制为 `rk3576/`，调整 kernel fragment
4. 新增 defconfig 入口
5. 测试

`VENDOR` 与 `BOARD` 的组合由用户运行时指定，例如：

```bash
make BOARD=rk3576 defconfig
```