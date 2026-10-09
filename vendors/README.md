# vendors/ —— 厂商配置

每个 `*.ini` 文件定义一个 RK3588 BSP 厂商的源码来源、版本、默认板等元信息。
`scripts/fetch-source.sh` 根据 `VENDOR=` 读取对应 ini 并分发到对应的 fetch 脚本。

## 当前支持

| 文件 | VENDOR | 流派 | 板子 |
|---|---|---|---|
| `rockchip.ini` | `rockchip` | radxa/buildroot + 上游 rockchip-linux | RK3588 / RK3588S 全系列 |
| `friendlyarm.ini` | `friendlyarm` | radxa/buildroot + friendlyarm kernel/uboot/rkbin + device overlay + sd-fuse | NanoPi M6 / R6C / R6S / NanoPC-T6 / CM3588 |
| `alientek.ini` | `alientek` | Rockchip 5.10 BSP tarball（来自 Mega.nz） | ATK-DLRK3588B / QuarkPi-CA2 |

## ini 字段说明

| 字段 | 含义 |
|---|---|
| `VENDOR_NAME` | 厂商短名（与文件名一致） |
| `VENDOR_DESC` | 一句话描述 |
| `BUILDROOT_REPO` / `BUILDROOT_BRANCH` | Buildroot 主树（仅 radxa 流派需要） |
| `BUILDROOT_DEFCONFIG` | 该厂商使用的 base defconfig |
| `KERNEL_REPO` / `KERNEL_BRANCH` | 内核来源 |
| `UBOOT_REPO` / `UBOOT_BRANCH` | U-Boot 来源 |
| `RKBIN_REPO` / `RKBIN_BRANCH` | Rockchip 二进制（bootrom、bl31、tee） |
| `MPP_REPO` / `MPP_BRANCH` | 媒体处理平台 |
| `RKNPU2_REPO` / `RKNPU2_BRANCH` | NPU2 / RKNN |
| `DEVICE_REPO` / `DEVICE_BRANCH` / `DEVICE_PATH` | 设备覆盖层（friendlyarm 用） |
| `SDFUSE_REPO` / `SDFUSE_BRANCH` | SD/eMMC 镜像工具 |
| `TOOLCHAIN_URL` | 交叉工具链下载 URL |
| `BOARDS` | 该厂商支持的板子列表（空格分隔） |
| `DEFCONFIG_GUI` / `DEFCONFIG_HEADLESS` | 我们生成的两个 defconfig 名（GUI/Headless） |
| `DEFAULT_BOARD` | alientek 等没有 defconfig 的厂商使用 |

## 新增厂商

1. 复制 `rockchip.ini` → `your.ini`
2. 修改各 `REPO` / `BRANCH` / `TOOLCHAIN_URL`
3. 在 `scripts/fetch-source.sh` 增加 `case` 分支
4. 若不是 radxa 流派（如 alientek），参考 `fetch-alientek.sh`
5. 在 `overlay/fragments/` 与 `overlay/defconfig/` 中提供对应 defconfig 片段
6. 更新 `docs/vendor-support.md`

## 切换厂商

```bash
# 友好之臂
export VENDOR=friendlyarm
make fetch && make defconfig && make build

# 正点原子（GUI 默认）
export VENDOR=alientek BOARD=atk-dlrk3588B
make fetch && make build

# 正点原子（Headless）
export VENDOR=alientek BOARD=atk-dlrk3588B VARIANT=headless
make fetch && make build
```