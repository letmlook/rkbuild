# 快速开始

5 步从零编译 RK3588 镜像并烧写到 SD 卡。

## 0. 前置

- Ubuntu 22.04/24.04（或 Debian / WSL2）
- 至少 30GB 空闲磁盘空间
- 至少 8GB RAM（推荐 16GB）
- 与 GitHub / Mega.nz 网络可达

## 1. 安装编译依赖

```bash
sudo make init
```

会安装：build-essential、git、python3、mkfs.ext4、device-tree-compiler、megatools（alientek 用）等。

## 2. 拉源码

默认拉 Rockchip 官方风格：

```bash
make fetch
```

源码落在 `dist/src/`：

```
dist/src/
├── buildroot/                radxa/buildroot @ rockchip/2024.02
├── kernel/                   rockchip-linux/kernel @ develop-6.1
├── u-boot/                   rockchip-linux/u-boot @ next-dev
├── rkbin/                    rockchip-linux/rkbin
├── mpp/                      rockchip-linux/mpp
├── rknpu2/                   rockchip-linux/rknpu2
└── prebuilts/gcc/.../        Bootlin gcc-arm-10.3 aarch64 工具链
```

切换厂商：

```bash
VENDOR=friendlyarm make fetch         # 友善之臂
VENDOR=alientek make fetch            # 正点原子
```

## 3. 应用 defconfig

```bash
make defconfig
```

默认 `VARIANT=gui`，写入 `dist/src/buildroot/.config`。

Headless 版：

```bash
make defconfig VARIANT=headless
```

需要微调包选择：

```bash
make menuconfig
# 保存退出后自动 make savedefconfig → 提示覆盖 overlay/ 内的 defconfig
```

## 4. 编译

```bash
make build                 # make -j$(nproc)
```

首次编译耗时：30 分钟 ~ 数小时（依机器）。产出在：

```
dist/output/rk3588-gui/images/
├── boot.img
├── rootfs.ext4
├── u-boot.itb
└── ...
```

## 5. 烧写

```bash
sudo dd if=dist/output/rk3588-gui/images/rootfs.ext4 of=/dev/sdX bs=4M status=progress
sync
```

或生成完整 SD 卡镜像后烧：

```bash
make image                 # 生成 dist/images/rk3588-gui-sd-<DATE>.img.xz
sudo xzcat dist/images/rk3588-gui-sd-*.img.xz | dd of=/dev/sdX bs=4M status=progress
```

## 6. 一键 SDK（可选）

```bash
make sdk
# → dist/sdk/rk3588-gui-<DATE>.tar.xz
```

解压后在另一台 Ubuntu 编译 hello RK358：

```bash
tar -xJf rk3588-gui-20251009.tar.xz -C /opt/
cd /opt/<SDK root>
source environment-setup
echo 'int main(){return 0;}' | $CC -x c -
```

## 常用别名

`source ./envsetup.sh` 后可用：

| 别名 | 等价命令 |
|---|---|
| `rkb-init`     | `sudo make init` |
| `rkb-fetch`    | `make fetch` |
| `rkb-defconfig`| `make defconfig` |
| `rkb-build`    | `make build` |
| `rkb-sdk`      | `make sdk` |
| `rkb-image`    | `make image` |
| `rkb-info`     | `make info` |

## 下一步

- [`vendor-support.md`](vendor-support.md) —— 切厂商
- [`variant-guide.md`](variant-guide.md) —— GUI vs Headless
- [`sdk-usage.md`](sdk-usage.md) —— 交叉 SDK 使用
- [`docker-on-rk3588.md`](docker-on-rk3588.md) —— Docker 完整功能
- [`alientek.md`](alientek.md) —— 正点原子专属操作