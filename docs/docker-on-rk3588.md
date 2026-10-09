# Docker 完整功能说明（RK3588）

rkbuild 默认把 Docker 引擎栈与生态工具**全部**编译进镜像（不裁剪）。本节说明包含什么、如何启动、如何调优。

## 包含的工具

### 核心运行时

| 工具 | 路径 | 用途 |
|---|---|---|
| dockerd | `/usr/bin/dockerd` | Docker 主守护进程 |
| containerd | `/usr/bin/containerd` | 容器运行时管理器（含 CRI 插件） |
| runc | `/usr/sbin/runc` | 标准 OCI 运行时 |
| crun | `/usr/bin/crun` | 替代 OCI（C 实现，性能更好） |
| buildkit | `/usr/bin/buildkitd` + `/usr/bin/buildctl` | 新一代构建引擎 |
| docker-buildx | 作为 docker 插件 | docker build 的扩展 |

### 官方生态 CLI

| 工具 | 用途 |
|---|---|
| `docker` (cli) | 主客户端 |
| `docker compose` (v2 插件) | 多容器编排 |
| `dive` | 镜像层分析 |
| `ctop` / `lazydocker` | TUI 资源监控 |
| `hadolint` | Dockerfile 静态检查 |
| `skopeo` | 镜像搬运/检查 |
| `crane` | 镜像元数据/复制 |
| `regctl` | registry 交互 |

### Containerd 生态 CLI

| 工具 | 用途 |
|---|---|
| `nerdctl` | Docker-compatible CLI（containerd 原生） |
| `ctr` | containerd 调试 CLI |
| `crictl` | Kubernetes CRI 调试 CLI |

### Rootless 支撑

| 工具 | 用途 |
|---|---|
| `slirp4netns` | rootless 网络栈（兼容性最好） |
| `pasta` | rootless 网络栈（比 slirp4netns 更快，2024+ 主推） |
| `fuse-overlayfs` | rootless overlay 存储 |
| `uidmap` | 用户命名空间映射（rootless 必需） |

### 安全

| 工具 | 用途 |
|---|---|
| `apparmor` + `apparmor-utils` | AppArmor 强制访问控制 |
| `libselinux` + `libsepol` | SELinux 库支持 |
| `seccomp` profile | Docker 默认 profile 全规则可用 |

## 启动 Docker

### BusyBox init（默认）

```bash
/etc/init.d/S95dockerd start
/etc/init.d/S95dockerd status    # 检查
/etc/init.d/S95dockerd stop
```

### systemd（如启用）

```bash
systemctl enable --now docker
systemctl status docker
```

## daemon 配置

`/etc/docker/daemon.json`（默认）：

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
  "rootless": true,
  "metrics-addr": "127.0.0.1:9323",
  "selinux-enabled": false,
  "default-ulimits": {
    "nofile": { "Name": "nofile", "Hard": 65535, "Soft": 65535 }
  }
}
```

## Storage Drivers（全部可用）

```bash
# 默认 overlay2
docker info | grep "Storage Driver"

# 切换（需重启 dockerd）
# 改 /etc/docker/daemon.json 的 storage-driver 字段后 /etc/init.d/S95dockerd restart
# 可选: overlay2 / btrfs / devicemapper / fuse-overlayfs / vfs
```

## Network Drivers（全部可用）

```bash
# 默认 bridge
docker network create --driver bridge my-net
docker network create --driver host my-host
docker network create --driver macvlan \
    --opt parent=eth0 my-macvlan
docker network create --driver ipvlan \
    --opt parent=eth0 --opt ipvlan_mode=l2 my-ipvlan
docker network create --driver overlay my-overlay    # Swarm
docker network create --driver none my-none
```

## Log Drivers（全部可用）

`daemon.json` 中 `log-driver` 可切：

- `json-file`（默认，10 MB × 3 文件）
- `syslog` → 配 `syslog-address: "tcp://log-server:514"`
- `journald` → 配 `tag: "docker/{{.Name}}"`
- `fluentd` → 配 `fluentd-address: "127.0.0.1:24224"`
- `gelf` → 配 `gelf-address: "udp://graylog:12201"`
- `awslogs` / `splunk` / `logentries` / `loki`

## 容器内访问 RKNPU

把 `/dev/dri/rknpu` 透传给容器：

```bash
docker run --rm -it \
    --device /dev/dri/rknpu \
    --group-add video \
    -v /usr/lib/librknn_api:/usr/lib/librknn_api:ro \
    your-rknn-app
```

或用 `compose.yml`：

```yaml
services:
  ai:
    image: your-app
    devices:
      - /dev/dri/rknpu
    group_add:
      - video
    volumes:
      - /usr/lib/librknn_api:/usr/lib/librknn_api:ro
```

## 容器内访问 GPU/Mali

```bash
docker run --rm -it \
    --device /dev/dri:/dev/dri \
    --group-add video \
    --group-add render \
    -e WAYLAND_DISPLAY=wayland-0 \
    -v $XDG_RUNTIME_DIR/wayland-0:/run/user/$(id -u)/wayland-0 \
    your-qt-app
```

## Rootless 模式

```bash
# 在 rootful 用户内切换 rootless
dockerd-rootless-setuptool.sh check
dockerd-rootless-setuptool.sh install --skip-iptables
systemctl --user enable --now docker

# 容器测试
docker run --rm hello-world
```

## Compose 用法

```bash
cat > compose.yml <<'YAML'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
  app:
    image: your-app:latest
    runtime: crun      # 用 crun 而非 runc
    devices:
      - /dev/dri/rknpu
    depends_on:
      - web
YAML

docker compose up -d
docker compose logs -f
docker compose down
```

## BuildKit / buildx

```bash
# 默认 buildkit 已开启
docker build -t myapp:latest .

# 用 buildx 高级特性（多平台、cache 导出）
docker buildx create --name mybuilder --use
docker buildx build \
    --platform linux/arm64 \
    --cache-to type=local,dest=/tmp/cache \
    -t myapp:latest .
```

## nerdctl（Docker-compatible CLI）

```bash
# nerdctl 用 containerd 而非 dockerd；适合不愿启动 dockerd 的场景
nerdctl run --rm hello-world
nerdctl compose up -d      # 类似 docker compose
nerdctl build -t myapp .
```

## 健康检查

```bash
rkbuild-doctor          # 检查 namespaces/cgroups/overlay/bridge/npu/docker
```

## 预置镜像

`/usr/share/rkbuild/docker-images/` 下放置的 *.tar 在 firstboot 自动 `docker load`。

可配置 `BR2_PACKAGE_RKBUILD_DOCKER_IMAGES_LIST`（如 `"alpine:latest busybox:latest hello-world"`）在编译时自动 pull+save。

## 常见问题

### docker info 显示 "permission denied"

```bash
# 用户需在 docker 组
usermod -aG docker $USER
# 或每次 sudo
sudo docker info
```

### cgroup v2 未挂载

```bash
mount | grep cgroup2
# 没有则手动挂载（写入 /etc/fstab）
echo 'cgroup2 /sys/fs/cgroup cgroup2 defaults 0 0' >> /etc/fstab
mount /sys/fs/cgroup
```

### 容器无法上网

```bash
# 检查 iptables
iptables -t nat -L
# 缺失 modprobe 加载
modprobe br_netfilter
sysctl -w net.bridge.bridge-nf-call-iptables=1
```

### AppArmor 拒绝

```bash
# 临时关闭
docker run --security-opt apparmor=unconfined ...
# 或在 daemon.json 关闭 docker apparmor
```