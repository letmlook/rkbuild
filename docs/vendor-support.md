# 厂商支持

rkbuild 支持三家 RK3588 BSP 提供方。每家有自己的源码组织方式与编译入口。

## 矩阵

| Vendor | 编译流派 | 源码形态 | 默认板 | 切换命令 |
|---|---|---|---|---|
| **`rockchip`** | radxa/buildroot | git 树 | RK3588 / RK3588S 通用 | `export VENDOR=rockchip` |
| **`friendlyarm`** | radxa/buildroot + friendlyarm 设备层 | git 树 | NanoPi M6/R6C/R6S、NanoPC-T6、CM3588 | `export VENDOR=friendlyarm` |
| **`alientek`** | Rockchip 5.10 BSP tarball | Mega.nz tarball | ATK-DLRK3588B、QuarkPi-CA2 | `export VENDOR=alientek BOARD=atk-dlrk3588B` |

## rockchip（默认 / 优先）

- **Buildroot**: [radxa/buildroot](https://github.com/radxa/buildroot) @ `rockchip/2024.02`
- **内核 / U-Boot / RKbin / MPP / RKNPU2**: 上游 `github.com/rockchip-linux`
- **工具链**: Bootlin `gcc-arm-10.3-2021.07 aarch64`
- **适用板**: Rock 5B+ / 5C / CM5、NanoPi M6/R6C/R6S、ATK-DLRK3588B 等任何 RK3588 / RK3588S 板
- **变体**: GUI / Headless 都可用（自定义 defconfig）

## friendlyarm（友善之臂）

- **Buildroot**: [radxa/buildroot](https://github.com/radxa/buildroot) @ `rockchip/2024.02`（沿用）
- **内核**: [friendlyarm/kernel-rockchip](https://github.com/friendlyarm/kernel-rockchip) @ `nanopi6-v6.1.y`
- **U-Boot**: [friendlyarm/uboot-rockchip](https://github.com/friendlyarm/uboot-rockchip) @ `nanopi6-v2017.09`
- **RKbin**: [friendlyarm/rkbin](https://github.com/friendlyarm/rkbin) @ `nanopi6`
- **设备层**: [buildroot_device_friendlyelec](https://github.com/friendlyarm/buildroot_device_friendlyelec) @ `kernel-5.10`
- **SD/eMMC 工具**: [sd-fuse_rk3588](https://github.com/friendlyarm/sd-fuse_rk3588) @ `kernel-6.1.y`
- **工具链**: FriendlyElec prebuilts 11.3-aarch64
- **适用板**: NanoPi M6、NanoPi R6C/R6S、NanoPC-T6、CM3588
- **变体**: GUI / Headless 都可用

## alientek（正点原子）

- **SDK**: Mega.nz tarball（[atk-dlrk3588B](https://mega.nz/folder/T1QyjKSI#ysQfY6-w_V1g0kBio79TOQ)、[QuarkPi-CA2](https://mega.nz/folder/T5IFzCbA#AIn2Du1vLvzdMlVGcQH4_Q)）
- **内核版本**: 5.10 (Rockchip `linux-5.10-gen-rkr8`)
- **SDK 内 buildroot**: frozen（与 BSP 版本绑定），自带 Qt5 5.15.8 / weston / mpp / python 3.10 / opencv 4.5
- **编译入口**: `./build.sh <board>`（不是 `make defconfig`）
- **变体**:
  - GUI: 直接走 SDK 默认（Qt5/weston 全开）
  - Headless: 应用 `alientek-overlay/patches/<board>-headless.patch`，剥离 GUI 包、注入 Docker 全栈

详细操作见 [`alientek.md`](alientek.md)。

## 切换厂商

```bash
# 切到 friendlyarm
export VENDOR=friendlyarm
make clean    # 可选
make fetch
make defconfig
make build

# 切到 alientek
export VENDOR=alientek BOARD=atk-dlrk3588B
make fetch
make build

# 切回 rockchip
export VENDOR=rockchip
make clean
make fetch && make defconfig && make build
```

## 加新厂商

参考 `vendors/README.md` 中的步骤：

1. 复制 `rockchip.ini` → `your.ini`
2. 修改各 `REPO/BRANCH/TOOLCHAIN_URL`
3. 在 `scripts/fetch-source.sh` 增加 case 分支
4. 若不是 radxa 流派（alientek 风格），复制 `fetch-alientek.sh`
5. 提供 `overlay/fragments/` 与 `overlay/defconfig/` 中的对应片段
6. 更新本文档