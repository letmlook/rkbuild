################################################################################
#
# onnxruntime-rknn —— ONNX Runtime with RKNN execution provider
#
# 从 https://github.com/airockchip/onnxruntime 检出 master 分支构建。
#
################################################################################

ONNXRUNTIME_RKNN_VERSION = $(call qstrip,$(BR2_PACKAGE_ONNXRUNTIME_RKNN_VERSION))
ONNXRUNTIME_RKNN_SITE = https://github.com/airockchip/onnxruntime.git
ONNXRUNTIME_RKNN_SITE_METHOD = git
ONNXRUNTIME_RKNN_LICENSE = MIT
ONNXRUNTIME_RKNN_LICENSE_FILES = LICENSE
ONNXRUNTIME_RKNN_INSTALL_STAGING = YES

# 编译依赖
ONNXRUNTIME_RKNN_DEPENDENCIES = rknpu2 linux host-cmake host-python3 \
                                 $(BR2_PYTHON3_PACKAGE_DEPENDENCIES_REPLACE)

# cmake / 自定义构建脚本（以项目自带 build.sh 为准）
ONNXRUNTIME_RKNN_BUILD_CMDS = \
	cd $(@D) && \
	CMAKE_BUILD_TYPE=Release \
	$(HOST_DIR)/bin/cmake -B build -DCMAKE_INSTALL_PREFIX=/usr \
		-DONNXRUNTIME_VERSION=r$(ONNXRUNTIME_RKNN_VERSION) \
		-DBUILD_SHARED_LIBS=ON \
		-DUSE_RKNN=ON \
		-DUSE_CUDA=0 . && \
	$(HOST_DIR)/bin/cmake --build build -j$(PARALLEL_JOBS)

ONNXRUNTIME_RKNN_INSTALL_STAGING_CMDS = \
	cd $(@D)/build && $(HOST_DIR)/bin/cmake -DCMAKE_INSTALL_PREFIX=$(STAGING_DIR)/usr -P cmake_install.cmake

ONNXRUNTIME_RKNN_INSTALL_TARGET_CMDS = \
	cd $(@D)/build && $(HOST_DIR)/bin/cmake -DCMAKE_INSTALL_PREFIX=$(TARGET_DIR)/usr -P cmake_install.cmake

$(eval $(cmake-package))