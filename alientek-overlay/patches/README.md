# alientek-overlay/patches/README.md
#
# 本目录的 patch 是占位实现；真实可用的 patch 需用户在首次 fetch 后，
# 根据 SDK 实际版本手工生成。
#
# 生成方法：
#   1) make fetch VENDOR=alientek BOARD=atk-dlrk3588B
#   2) cd dist/src/atk-sdk
#   3) cp device/rockchip/rk3588/atk_dlrk3588B/buildroot/atk_dlrk3588B_defconfig /tmp/orig.config
#   4) 编辑 /tmp/orig.config：
#        - 注释 BR2_PACKAGE_QT5/WAYLAND/WESTON/MALI/LIBINPUT/TSLIB/SDL2/MESA3D 等 GUI 包
#        - 追加 dockerd/containerd/runc/crun/buildkit/docker-compose/dive/ctop/lazydocker/hadolint/skopeo/nerdctl/ctr/crictl 等
#        - 追加 BR2_PACKAGE_APPARMOR / BR2_PACKAGE_RKNPU2 等
#   5) diff -u /tmp/orig.config device/rockchip/rk3588/atk_dlrk3588B/buildroot/atk_dlrk3588B_defconfig \
#         > ../../alientek-overlay/patches/atk-dlrk3588B-headless.patch
#   6) make clean && make fetch VENDOR=alientek BOARD=atk-dlrk3588B VARIANT=headless && make build
#
# 当前 patches/<board>-headless.patch 是参考模板；用户应用前务必核对。