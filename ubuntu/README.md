# ubuntu/ —— Rockchip Ubuntu 22.04 资产

`ROOTFS=ubuntu`（仅 `VENDOR=rockchip`）使用的配置与 rootfs overlay。

```
ubuntu/
├── boards/<board>.ini       # 板级：内核 DTB、U-Boot defconfig、rkbin TPL/BL31、串口
├── packages/headless.list   # 服务器/容器/AI 默认包
├── packages/gui.list        # GUI 追加包（Xfce）
├── packages/sdk.list        # 交叉 SDK sysroot 的 -dev 包
├── kernel-fragment.config   # Ubuntu 启动/systemd/容器内核选项（追加到 rockchip_linux_defconfig）
└── rootfs-overlay/          # 注入 rootfs 的 /etc、/usr/local/bin 文件
```

使用：

```bash
make fetch ROOTFS=ubuntu VARIANT=headless
make build ROOTFS=ubuntu VARIANT=headless
make image ROOTFS=ubuntu VARIANT=headless
make sdk   ROOTFS=ubuntu VARIANT=headless
```

完整说明见 [`../docs/ubuntu.md`](../docs/ubuntu.md)。
