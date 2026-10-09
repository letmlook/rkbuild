################################################################################
#
# rkbuild-docker-images —— 在 build 阶段预 pull + save 常用 docker 镜像到 rootfs
#
# 注：此包会调用 host docker CLI；如 host 无 docker 则跳过。
#
################################################################################

RKBUILD_DOCKER_IMAGES_VERSION = 0.1.0
RKBUILD_DOCKER_IMAGES_LICENSE = Apache-2.0
RKBUILD_DOCKER_IMAGES_LICENSE_FILES =

RKBUILD_DOCKER_IMAGES_DEPENDENCIES = host-docker
RKBUILD_DOCKER_IMAGES_IMAGES = $(call qstrip,$(BR2_PACKAGE_RKBUILD_DOCKER_IMAGES_LIST))

define RKBUILD_DOCKER_IMAGES_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/rkbuild/docker-images
	@if command -v docker >/dev/null 2>&1; then \
		for img in $(RKBUILD_DOCKER_IMAGES_IMAGES); do \
			echo "[rkbuild-docker-images] pulling $$img"; \
			docker pull $$img 2>/dev/null || true; \
			safe=$$(echo $$img | tr '/:' '__'); \
			docker save -o $(TARGET_DIR)/usr/share/rkbuild/docker-images/$$safe.tar $$img 2>/dev/null || true; \
		done; \
	else \
		echo "[rkbuild-docker-images] host docker missing; skipping"; \
	fi
endef

$(eval $(generic-package))