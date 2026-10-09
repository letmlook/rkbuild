# rkbuild —— RK3588 一键 Buildroot 镜像与交叉 SDK 编译脚本（v6：Docker 完整功能）

> 本文件为方案定稿，对应实现以 `Makefile` + `envsetup.sh` + `scripts/` + `overlay/` + `vendors/` + `alientek-overlay/` + `docs/` 落地。

## 0. 厂商 × 变体矩阵

|                | **GUI 变体**（默认）              | **Headless 变体**                    |
|----------------|----------------------------------|--------------------------------------|
| **`rockchip`**   | radxa/buildroot + GUI + Docker 全功能 | radxa/buildroot + Docker 全功能 |
| **`friendlyarm`** | radxa/buildroot + GUI + Docker 全功能 | radxa/buildroot + Docker 全功能 |
| **`alientek`**   | Mega.nz tarball + Docker 全功能注入 | 同一 tarball + patch 剥离 GUI + Docker 全功能注入 |

环境变量：`VENDOR=rockchip|friendlyarm|alientek`（默认 `rockchip`）、`VARIANT=gui|headless`（默认 `gui`）、`BOARD=...`。

## 1. Docker 完整功能清单（不裁剪）

### 1.1 Docker 官方包（全部纳入）
- **核心**：`docker-engine`（dockerd）、`docker-cli`、`containerd`、`runc`、`crun`、`buildkit`、`docker-buildx`
- **官方生态 CLI**：`docker-compose`（v2 插件）、`dive`、`ctop` / `lazydocker`、`hadolint`、`skopeo`、`crane`、`regctl`
- **Containerd 生态 CLI**：`nerdctl`、`ctr`、`crictl`
- **Rootless 支撑**：`slirp4netns`、`pasta`、`fuse-overlayfs`、`uidmap`
- **安全**：`apparmor` + `apparmor-utils`、`libselinux` + `libsepol`、seccomp profile（全部规则可用）

### 1.2 Storage Drivers（全部编译进 daemon）
`overlay2`、`btrfs`、`devicemapper`、`fuse-overlayfs`、`vfs`。

### 1.3 Network Drivers（全部编译进 daemon）
`bridge`、`host`、`overlay`、`macvlan`、`ipvlan`、`none`。

### 1.4 Log Drivers（daemon.json 全列）
`json-file`、`syslog`、`journald`、`fluentd`、`gelf`、`awslogs`、`splunk`、`logentries`、`loki`。

### 1.5 Docker daemon 配置 `/etc/docker/daemon.json`

```json
{
  "storage-driver": "overlay2",
  "iptables": true,
  "ip-forward": true,
  "ip-masq": true,
  "ipv6": false,
  "live-restore": true,
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "default-runtime": "runc",
  "runtimes": {
    "crun": { "path": "/usr/bin/crun" },
    "runc": { "path": "/usr/sbin/runc" }
  },
  "features": { "buildkit": true },
  "experimental": true,
  "rootless": true
}
```

### 1.6 Docker 内核配置（全开，写入 `overlay/fragments/rkbuild_docker_kernel.config`）

- Namespaces：PID/NET/IPC/USER/UTS/CGROUP NS 全 y
- Cgroups v2：SCHED/FREEZER/PIDS/DEVICE/CPUSETS/MEMCG/BLK/WRITEBACK/PERF/HUGETLB 全 y
- Storage：OVERLAY_FS、BTRFS_FS、FUSE_FS、EXT4_FS
- Networking：BRIDGE、BRIDGE_NETFILTER、VLAN_8021Q、VETH、VXLAN、IP_GRE、IPVLAN、MACVLAN、DUMMY、TUN
- Netfilter（iptables-nft 全套）：NF_TABLES、NF_TABLES_INET、NF_TABLES_NETDEV、NFT_CT/NFT_NAT/NFT_MASQ/NFT_LIMIT/NFT_LOG/NFT_QUEUE/NFT_QUOTA/NFT_REJECT/NFT_COMPAT/NFT_HASH/NFT_SOCKET/NFT_OSF/NFT_TPROXY/NFT_FLOW_OFFLOAD/NFT_DUP_NETDEV、NETFILTER_XTABLES 含 REDIRECT/MASQUERADE/NAT/CONNTRACK/MULTIPORT/ADDRTYPE/RECENT/STATISTIC
- Security：SECCOMP、SECCOMP_FILTER、SECURITY、SECURITY_APPARMOR、SECURITY_SELINUX
- Misc：CHECKPOINT_RESTORE、USERFAULTFD、MEMBARRIER、RSEQ

### alientek headless 支持

- alientek SDK tarball 用 `./build.sh atk-dlrk3588B` 入口，无法 kconfig 注入
- 提供 `alientek-overlay/patches/atk-dlrk3588B-headless.sh` —— **sed 注入脚本**（不用 patch，避免行号/上下文漂移）
  - 关闭 GUI 包：Qt5/Wayland/Weston/Mali/Mesa3D/SDL2/TSlib/libinput 等
  - 追加 Docker 全栈、RKNN、rkbuild-helper、headless 必备包
- `scripts/fetch-alientek.sh` 检测 `VARIANT=headless` 时自动运行该脚本
- 脚本幂等，SDK 升级后只要包名不变仍可工作
- 文档说明：用户也可手改 SDK 内的 `<board>_defconfig` 实现更精细裁剪

## 2. 默认软件清单（两变体共有）

- **系统**：busybox+eudev（systemd 可选）/ dropbear+openssh / chrony / rng-tools+haveged / e2fsprogs+btrfs-progs+dosfstools+parted+pciutils+util-linux / logrotate+syslog-ng
- **网络**：iptables+nftables+iproute2+bridge-utils+vlan / wpa_supplicant+hostapd+dhcpcd+dnsmasq / tcpdump+nmap+ncat+ethtool+mii-tool / pppd / wireguard-tools / c-ares
- **外设**：libgpiod / i2c-tools / spidev-test / can-utils / libmodbus
- **多媒体**（headless 保留转码）：gstreamer1 {base,good,bad,ugly,libav,x264,v4l2} + gstreamer1-rockchip / ffmpeg + rockchip-mpp + libv4l-rkmpp + rockchip-rga / alsa-lib+alsa-utils+tinyalsa
- **AI**：rknpu2 + rknpu-fw / python3 + pip + numpy + opencv + pillow / rknn-toolkit-lite2 / `onnxruntime-rknn` + `tflite-delegate-rknpu2`（自有 local package）
- **工具**：iperf3 / smartmontools / lm-sensors / stress-ng / sysstat / tmux / vim / bash-completion / htop / iotop / lsof
- **常用库**：openssl+mbedtls / cJSON+jansson+msgpack-c+libconfuse / libcurl+libmosquitto+libwebsockets / sqlite / protobuf-c+flatbuffers / libusb+libpng+libjpeg-turbo+libwebp+freetype / zstd+snappy / mongoose（备 civetweb）/ libuv / libuuid

## 3. 仅 GUI 变体

Qt6（qt6base EGLFS + qt6declarative + qt6quickcontrols2 + qt6multimedia + qt6svg + qt6websockets + qt6serialport + qt6shadertools）/ wayland + weston + wayland-utils + mesa3d + rockchip-mali / tslib + libinput / SDL2

## 4. defconfig 层次

```
overlay/fragments/
├── rkbuild_base.config             # rockchip_rk3588_defconfig 必补
├── rkbuild_default.config          # 两变体共有 + Docker 全套
├── rkbuild_gui.config              # GUI 专属
├── rkbuild_docker.config           # Docker 全套（独立 fragment）
├── rkbuild_docker_kernel.config    # Docker 内核配置
└── rkbuild_mirrors.config          # 国内镜像
```

```
overlay/defconfig/
├── rkbuild_rk3588_gui_defconfig       # include rockchip + base + default + gui + docker + mirrors
└── rkbuild_rk3588_headless_defconfig  # include rockchip + base + default + docker + mirrors
```

两者都通过 `BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES+=` 追加 `rkbuild_docker_kernel.config`。

## 5. 自有 local package

- `rkbuild-helper` —— firstboot 信息写入、`rkbuild-info` 命令
- `onnxruntime-rknn` —— RKNN 后端 ONNX Runtime
- `tflite-delegate-rknpu2` —— RKNN delegate TFLite
- `rkbuild-docker-helper` —— `rkbuild-docker-info` / `rkbuild-doctor` / `rkbuild-docker-preload`
- `rkbuild-docker-images`（可选）—— 预置常用 docker image

## 6. 文档

`docs/{quickstart, sdk-usage, vendor-support, variant-guide, alientek, default-software, adding-board, troubleshooting, docker-on-rk3588}.md`

## 7. 验收

- `make fetch VENDOR=rockchip && make defconfig VARIANT=gui && make build` → 完整 GUI + Docker 镜像
- `make fetch VENDOR=rockchip && make defconfig VARIANT=headless && make build` → 无 GUI + Docker 镜像
- `docker info` 显示：`Storage Driver: overlay2`、`Runtimes: runc crun`、`Experimental: true`、`BuildKit: true`
- `docker compose / buildx / nerdctl / ctr / crictl / crun / dive / hadolint / skopeo / crane / lazydocker / docker-buildx` 全部命令可用
- `docker run --rm hello-world` / `docker run --rm --runtime=crun hello-world` 成功
- `zcat /proc/config.gz | grep -E 'NAMESPACE|CGROUP|OVERLAY|BRIDGE|VXLAN|APPARMOR'` 全 y
- `make sdk VARIANT=gui/headless` 均产出可移植 SDK tarball
- alientek vendor GUI/headless 通过 patch 实现同等产出

## 8. 不在本期范围

- Docker Registry 服务端、k8s/k3s、Podman/Lima/Finch、rkdeveloptool 自动烧写