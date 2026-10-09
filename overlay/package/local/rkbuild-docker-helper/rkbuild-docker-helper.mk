################################################################################
#
# rkbuild-docker-helper —— rkbuild Docker 辅助脚本集
#
# 文件已在 overlay/board/rockchip/rk3588/fs-overlay 下，
# 通过 BR2_ROOTFS_OVERLAY 自动注入。本包只提供注册项。
#
################################################################################

RKBUILD_DOCKER_HELPER_VERSION = 0.1.0
RKBUILD_DOCKER_HELPER_SOURCE =
RKBUILD_DOCKER_HELPER_SITE =
RKBUILD_DOCKER_HELPER_LICENSE = Apache-2.0
RKBUILD_DOCKER_HELPER_LICENSE_FILES =

define RKBUILD_DOCKER_HELPER_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/rkbuild/docker-images
	# 占位 README
	echo "# Place pre-built docker image tarballs here." > \
		$(TARGET_DIR)/usr/share/rkbuild/docker-images/README
endef

$(eval $(generic-package))