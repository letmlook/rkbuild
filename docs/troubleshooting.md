# 常见问题

## 编译阶段

### make defconfig 提示 "configs/<board>_defconfig not found"

- 你可能未跑 `make fetch`，buildroot 工作树不存在。
- 或 vendor=alientek 时传了 defconfig（alientek 不走 defconfig）。

### "fatal: not a git repository" 出现在 rkbuild-helper 的 build 阶段

Buildroot 的 `package/local/*` 被扫描但某些包没有 .mk。检查：

```bash
ls overlay/package/local/rkbuild-helper/
# 应有 Config.in + rkbuild-helper.mk
```

### Qt6 编译报 "EGL/GBM not found"

kernel fragment 中漏了：

```
CONFIG_HAS_LIBEGL=y
CONFIG_HAS_LIBGBM=y
```

确认 `overlay/fragments/rkbuild_docker_kernel.config` 与 rockchip-mali 包都已选。

### Docker engine 编译报 "libsystemd-dev not found"

busybox init 模式下 Buildroot 默认不编译 systemd 开发库。

如果想用 dockerd 的 systemd cgroup driver（一般用 cgroupfs driver 即可），忽略此警告。

### Docker engine 编译报 "BTRFS support requested but no libbtrfs"

BR2_PACKAGE_BTRFS_PROGS=y 已开，br2 依赖项应会自动拉 libbtrfs。如失败：

```bash
make menuconfig
# Filesystem → btrfs-progs → [*] build btrfs-progs
```

### opencv3 编译耗时（30+ 分钟）

opencv3 + python + contrib 体积大。可选：

```bash
make menuconfig
# Graphic libraries → opencv3 → 关掉 opencv3_contrib / python bindings（如不需要）
```

## 运行阶段

### dockerd 启动后 "no such file or directory: /var/run/docker.sock"

第一次启动没自动建 socket dir。手动：

```bash
mkdir -p /var/run
/etc/init.d/S95dockerd start
```

### docker run 报 "cgroup v2 not mounted"

```bash
mount | grep cgroup2
# 没输出则：
mount -t cgroup2 cgroup2 /sys/fs/cgroup
```

写入 /etc/fstab 持久化：

```
cgroup2 /sys/fs/cgroup cgroup2 defaults 0 0
```

### docker run 报 "Failed to create network: could not find an available address pool"

docker 默认 bridge 子网与宿主机冲突。修改 daemon.json：

```json
{
  "bip": "172.17.42.1/16",
  "default-address-pools": [
    {"base": "172.80.0.0/16", "size": 24}
  ]
}
```

### docker run 报 "permission denied: /dev/dri/rknpu"

把当前用户加到 video 组，或者用 `--device /dev/dri/rknpu --group-add video`（rootful）。

### weston 起不来，"failed to open device /dev/dri/card0"

```bash
ls -la /dev/dri/
# 检查 mali 内核模块是否加载
modprobe mali_kbase
# 检查 dts 是否含 mali 节点
ls /sys/devices/platform/ff9a0000.gpu/
```

### rknn 推理报 "rknn_init failed: RKNN_ERR_DEVICE_UNAVAILABLE"

- 检查 `/dev/dri/rknpu` 存在
- 检查 kernel 加载了 `rknpu` 模块
- 容器需 `--device /dev/dri/rknpu --group-add video`

## alientek 阶段

### megatools dl 失败

Mega.nz 偶尔会更新下载链接或增加新目录：

```bash
# 直接手动从浏览器下载
# 把 tarball 重命名为 dist/src/atk-sdk-atk-dlrk3588B.tar.xz
```

### ./build.sh atk-dlrk3588B 报"找不到 buildroot 配置"

SDK tarball 解压不完整。重新 `make fetch`。

### headless patch dry-run 失败

patch 与 SDK 版本不匹配。重新生成 patch（见 docs/alientek.md）。

## 网络相关

### make fetch 卡在 git clone（github 不可达）

```bash
# 临时走代理
export https_proxy=http://127.0.0.1:7890

# 或换 git 配置
git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/"

# 或换 SSH
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

### Buildroot dl 阶段从 sources.buildroot.net 拉取失败

启用国内镜像：

```bash
make menuconfig
# Build options → mirrors → primary site → https://mirrors.tuna.tsinghua.edu.cn/buildroot
```

或编辑 `overlay/fragments/rkbuild_mirrors.config`。

## SDK 阶段

### make sdk 报 "no space left on device"

Buildroot SDK 中间产物大（特别包括 sysroot 中所有 lib）。预留 ≥10 GB。

### 解 SDK tarball 后 source environment-setup 失败

`source` 需要在 SDK 的 root 目录中执行（注意环境变量赋值会保留，bash 兼容性）。

```bash
cd /opt/<SDK root>
source ./environment-setup    # 注意 "./"
```

### $CC 仍指向宿主机 gcc

检查是否在 SDK root 目录 source：

```bash
cd /opt/<SDK root> && source ./environment-setup
echo $CC
# /opt/<SDK root>/usr/bin/aarch64-buildroot-linux-gnu-gcc
```

## 报告 Bug

收集：

```bash
# 1. 错误输出
make build 2>&1 | tee /tmp/build.log

# 2. 配置信息
make info > /tmp/info.txt
ls dist/src/buildroot/.config | xargs -I{} bash -c "echo === {} ===; grep -E '^(BR2_|LINUX_KERN|GPU2|MPP|RKNPU)' {}"

# 3. 板子/内核/rootfs 信息
cat dist/rk3588-gui/images/SHA256SUMS 2>/dev/null
```

附 `/tmp/build.log` `/tmp/info.txt` 与本节描述。