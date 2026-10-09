################################################################################
#
# rkbuild-helper —— rkbuild 自有辅助脚本集
#
# 不下载源码；所有文件已在 overlay/board/rockchip/rk3588/fs-overlay 下，
# 通过 BR2_ROOTFS_OVERLAY 自动注入。本包只提供 Config.in / .mk 注册项。
#
################################################################################

RKBUILD_HELPER_VERSION = 0.1.0
RKBUILD_HELPER_SOURCE =
RKBUILD_HELPER_SITE =
RKBUILD_HELPER_LICENSE = Apache-2.0
RKBUILD_HELPER_LICENSE_FILES =

# 仅在打开 BR2_ROOTFS_OVERLAY 时生效；不强制创建额外文件
define RKBUILD_HELPER_INSTALL_TARGET_CMDS
	@echo "[rkbuild-helper] files come from BR2_ROOTFS_OVERLAY"
endef

$(eval $(generic-package))