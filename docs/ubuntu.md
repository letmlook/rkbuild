# Rockchip Ubuntu 22.04 镜像与交叉 SDK

> 仅支持 `VENDOR=rockchip`（Rockchip 官方 BSP）。FriendlyElec / 正点原子暂不提供 Ubuntu 流程。

rkbuild 在原有 Buildroot 流程之外，新增了一条独立的 Ubuntu 22.04（jammy）流程：

- 根文件系统：Ubuntu 官方 `ubuntu-base-22.04.5-base-arm64.tar.gz` + qemu-user chroot 安装软件
- 内核：`rockchip-linux/kernel` @ `develop-6.1`（`rockchip_linux_defconfig`）
- 启动链：Rockchip `rkbin`（DDR init / BL31）+ mainline U-Boot（`generic-rk3588_defconfig`，bootstd/extlinux）
- 镜像：GPT 分区，U-Boot 原始区 + FAT boot 分区 + ext4 rootfs 分区
- 交叉 SDK：FriendlyARM GCC 11.3（glibc 2.35，与 jammy 匹配）+ Ubuntu 22.04 arm64 sysroot

## 1. 快速开始

```bash
# 1. 安装宿主依赖（含 qemu-user-static；不需要 debootstrap）
sudo make init

# 2. 拉源码与 Ubuntu Base / 工具链
make fetch ROOTFS=ubuntu VARIANT=headless

# 3. defconfig 在 Ubuntu 流程是空操作，可跳过
make defconfig ROOTFS=ubuntu VARIANT=headless

# 4. 编译内核、U-Boot、Ubuntu rootfs
make build ROOTFS=ubuntu VARIANT=headless

# 5. 生成可烧写 SD 镜像
make image ROOTFS=ubuntu VARIANT=headless

# 6. 烧写
sudo xzcat dist/images/rk3588-ubuntu-headless-sd-<DATE>.img.xz \
  | dd of=/dev/sdX bs=4M status=progress
sync
```

默认是 **GUI** 变体（`VARIANT=gui`），会额外安装 Xfce（`xubuntu-core`）。
服务器/容器/AI 场景建议显式使用 `VARIANT=headless`，体积和构建时间都小很多。

## 2. 产出

| 路径 | 内容 |
|---|---|
| `dist/ubuntu/images/Image` | 内核 |
| `dist/ubuntu/images/rk3588-evb1-lp4-v10-linux.dtb` | 板级 DTB |
| `dist/ubuntu/images/u-boot-rockchip.bin` | idbloader + U-Boot |
| `dist/ubuntu/images/rootfs.ext4` | 可直接挂载的 Ubuntu rootfs |
| `dist/ubuntu/images/boot.vfat` | boot 分区内容 |
| `dist/ubuntu/rootfs/` | rootfs 目录树（调试用） |
| `dist/ubuntu/build-info.txt` | 本次构建版本信息 |
| `dist/images/rk3588-ubuntu-<variant>-sd-<date>.img.xz` | 最终 SD 镜像 + `.sha256` |

镜像布局（GPT）：

| 偏移 | 内容 |
|---|---|
| 32 KiB | `u-boot-rockchip.bin`（idbloader + U-Boot） |
| 16 MiB | `boot` 分区，FAT32 128 MiB：`Image`、DTB、`extlinux/extlinux.conf` |
| 144 MiB | `rootfs` 分区，ext4，GPT 分区名 `rootfs`（ext4 label 仍为 `rkbuild-rootfs`） |

U-Boot 通过 bootstd 扫描 `extlinux.conf` 启动，内核命令行包含
`root=PARTLABEL=rootfs ... console=ttyS2,1500000n8`。
使用 GPT 分区名（PARTLABEL）而不是 `/dev/mmcblkXpY`，SD/eMMC 设备编号变化不影响启动；
无 initramfs 时内核不支持 `root=LABEL=`，因此必须用 `PARTLABEL`/`PARTUUID`。

## 3. 默认账号与串口

| 项 | 默认值 |
|---|---|
| 串口 | `ttyS2`，1500000 8N1 |
| 用户 | `rkbuild` / `rkbuild`（sudo NOPASSWD） |
| root | `root` / `rkbuild` |
| SSH | 允许 root 密码登录（开发镜像） |

**量产前务必修改默认密码、关闭 root 密码登录**（`/etc/ssh/sshd_config.d/10-rkbuild.conf`）。

## 4. 软件包定制

包清单在：

```
ubuntu/packages/headless.list   # 服务器基础 + Docker + Python/GStreamer
ubuntu/packages/gui.list        # 在 headless 基础上追加 Xfce 桌面
ubuntu/packages/sdk.list        # 交叉 SDK sysroot 的 -dev 包
```

- `VARIANT=headless` 只安装 `headless.list`
- `VARIANT=gui` 安装 `headless.list + gui.list`
- 临时追加包：

```bash
UBUNTU_EXTRA_PACKAGES="libmali-valhall-g610 htop" \
  make build ROOTFS=ubuntu VARIANT=headless
```

- 默认 apt 源为 `http://ports.ubuntu.com/ubuntu-ports`。国内可改
  `vendors/rockchip.ini` 中的 `UBUNTU_PORTS_MIRROR`，或临时覆盖：

```bash
UBUNTU_PORTS_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports \
  make build ROOTFS=ubuntu
```

> Ubuntu 发行版自带的 Docker 是 20.10（`docker.io` + `docker-compose` v1）。
> 如果需要对标 Buildroot 变体的 Docker 23+ / compose v2 / buildx / nerdctl 全栈，
> 请使用 Buildroot 流程，或在 `ubuntu/packages/headless.list` 中自行替换为 Docker 官方 apt 源。

## 5. 板级适配

默认板级配置：

```
ubuntu/boards/rk3588.ini    # RK3588 EVB1（默认）
ubuntu/boards/rk3588s.ini   # RK3588S EVB1
```

关键字段：

```ini
KERNEL_DEFCONFIG=rockchip_linux_defconfig
KERNEL_DTB=rk3588-evb1-lp4-v10-linux.dtb
UBOOT_DEFCONFIG=generic-rk3588_defconfig
UBUNTU_UBOOT_TPL=bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.24.bin
UBUNTU_UBOOT_BL31=bin/rk35/rk3588_bl31_v1.56.elf
UBUNTU_CONSOLE=ttyS2,1500000n8
```

- TPL/BL31 路径相对 `dist/src/rkbin`；文件不存在时会自动选择
  `bin/rk35/rk3588_ddr_*.bin` / `rk3588_bl31_*.elf` 中最新的一个。
- 换板时可以直接用环境变量覆盖，不必改文件：

```bash
make fetch ROOTFS=ubuntu BOARD=rk3588s
make build ROOTFS=ubuntu BOARD=rk3588s
```

- 对于 Radxa Rock 5B、NanoPC-T6 等非 EVB 板：需要
  1. 内核源码里存在对应 DTB（`KERNEL_DTB=rk3588-rock-5b.dtb` 等，路径为
     `arch/arm64/boot/dts/rockchip/<KERNEL_DTB>`）；
  2. mainline U-Boot 里存在对应 defconfig（`UBOOT_DEFCONFIG=rock5b-rk3588_defconfig`）。
  当前 `rockchip-linux/kernel` 只带 Rockchip EVB 系列 DTB，若要真正适配第三方板，
  建议把 `vendors/rockchip.ini` 的 `KERNEL_REPO/BRANCH` 换成带该板 DTB 的内核分支，
  或新增一个 BSP vendor 配置。

新增板级配置：复制 `ubuntu/boards/rk3588.ini` 为 `ubuntu/boards/<board>.ini`，然后
`BOARD=<board> make fetch/build/image ROOTFS=ubuntu`。

## 6. 交叉编译 SDK

```bash
make sdk ROOTFS=ubuntu VARIANT=headless
# → dist/sdk/rk3588-rockchip-ubuntu22.04-headless-<date>-sdk.tar.xz (+ .sha256)
```

SDK 内容：

```
rk3588-ubuntu22.04-sdk/
├── environment-setup
├── bin/                       # 带 --sysroot 的 aarch64-rkbuild-linux-gnu-* wrapper
├── cmake/aarch64-rkbuild-toolchain.cmake
├── toolchain/                 # FriendlyARM GCC 11.3 aarch64（glibc 2.35）
├── sysroot/                   # Ubuntu 22.04 arm64 + libc6-dev + 常用 -dev 库 + RKNN
└── external/                  # kernel/u-boot-mainline/rkbin/mpp/rknpu2 源码（默认包含）
```

使用：

```bash
mkdir -p /opt
sudo tar -xJf dist/sdk/rk3588-rockchip-ubuntu22.04-headless-<date>-sdk.tar.xz -C /opt/
cd /opt/rk3588-ubuntu22.04-sdk
source environment-setup

echo 'int main(){return 0;}' | $CC -x c - -o /tmp/hello
file /tmp/hello
# ELF 64-bit LSB pie executable, ARM aarch64, dynamically linked
```

CMake：

```bash
cmake -B build -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE"
cmake --build build -j
```

pkg-config：

```bash
$PKG_CONFIG --cflags --libs zlib
$PKG_CONFIG --cflags --libs gstreamer-1.0
$PKG_CONFIG --cflags --libs opencv4
```

精简 SDK（不打包 BSP 源码，体积小很多）：

```bash
SDK_INCLUDE_EXTERNAL=0 make sdk ROOTFS=ubuntu
```

自定义 sysroot 包集合：

```bash
SDK_PACKAGES_FILE=/path/to/my-sdk.list make sdk ROOTFS=ubuntu
# 或追加：UBUNTU_EXTRA_PACKAGES="libqt5-dev" make sdk ...
```

SDK 自检会在打包前用 `$CC` / `$CXX` 各编译一个 aarch64 可执行文件；失败会直接终止。

## 7. 缓存与清理

- 内核/U-Boot 使用 `O=dist/ubuntu/{kernel,u-boot}` 增量编译。
- 首次 rootfs 构建后加 `UBUNTU_ROOTFS_REUSE=1` 可跳过解压 + apt 安装，只重新安装模块/配置：

```bash
UBUNTU_ROOTFS_REUSE=1 make build ROOTFS=ubuntu VARIANT=headless
```

- 增量清理（保留源码、Ubuntu Base、工具链）：

```bash
make clean ROOTFS=ubuntu
```

- 全清：`make cleanall`（会删除 `dist/ubuntu`）。

## 8. 已知限制

- 仅支持 Rockchip 官方 BSP；不生成 FriendlyElec / 正点原子 Ubuntu 镜像。
- 默认镜像面向 RK3588 EVB，第三方板需自行提供 DTB / U-Boot defconfig。
- Ubuntu 官方源不含 Rockchip 专有 `libmali`（GPU）和预编译 MPP；GUI 默认软件渲染。
  RKNN runtime 由 `rknpu2` 仓库复制进 rootfs 和 SDK sysroot。
- 默认未安装 `linux-firmware`（体积大）。需要 WiFi/蓝牙固件时可加：
  `UBUNTU_EXTRA_PACKAGES="linux-firmware" make build ROOTFS=ubuntu`。
- 无 initramfs：根文件系统、MMC、ext4 必须内建；当前内核 fragment 已保证。
- 镜像使用 GPT + mainline U-Boot bootstd/extlinux；若替换为 Rockchip vendor U-Boot，
  需要改用 Rockchip 的 boot.img/FIT 流程。
- 构建 rootfs 需要 root 权限和 qemu-user binfmt（x86_64 宿主）。
- 默认密码仅用于开发调试，量产前必须修改。

## 9. 常见问题

### qemu-aarch64 binfmt 未注册

```bash
sudo systemctl restart systemd-binfmt
# 或
sudo update-binfmts --enable qemu-aarch64
```

### apt 下载失败

检查 `UBUNTU_PORTS_MIRROR`；容器环境可能需要设置 `http_proxy/https_proxy`
（脚本会把代理变量传入 chroot）。

### 找不到 DTB

构建会打印 `arch/arm64/boot/dts/rockchip/` 下的前 20 个 DTB；用
`KERNEL_DTB=<name>.dtb make build ROOTFS=ubuntu` 指定。

### U-Boot 构建报缺少 BL31 / TPL

`rkbin` 分支更新后文件名会变化。脚本会自动匹配最新文件；也可以显式指定：

```bash
UBUNTU_UBOOT_TPL=bin/rk35/xxx.bin UBUNTU_UBOOT_BL31=bin/rk35/xxx.elf \
  make build ROOTFS=ubuntu
```

### 镜像启动无输出

确认串口是 `ttyS2` 1500000；不同板可能是 `ttyS0/ttyS9`，用
`UBUNTU_CONSOLE=ttyS0,1500000n8` 覆盖板级配置。还要确认 U-Boot 的 TPL 与板子 DDR
配置匹配（`generic-rk3588` 默认的 DDR 初始化可能不适用于所有板）。
