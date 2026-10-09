################################################################################
#
# tflite-delegate-rknpu2 —— TensorFlow Lite with RKNN delegate
#
################################################################################

TFLITE_DELEGATE_RKNPU2_VERSION = 2.14.0
TFLITE_DELEGATE_RKNPU2_LICENSE = Apache-2.0
TFLITE_DELEGATE_RKNPU2_LICENSE_FILES = LICENSE
TFLITE_DELEGATE_RKNPU2_INSTALL_STAGING = YES

TFLITE_DELEGATE_RKNPU2_DEPENDENCIES = rknpu2 linux

ifeq ($(BR2_PACKAGE_TFLITE_DELEGATE_RKNPU2_PREBUILT),y)

# 预编译包：从 airockchip/TensorflowLite-bin GitHub releases
TFLITE_DELEGATE_RKNPU2_SITE = https://github.com/airockchip/TensorflowLite-bin/releases/download/v$(TFLITE_DELEGATE_RKNPU2_VERSION)
TFLITE_DELEGATE_RKNPU2_SOURCE = tflite-rknpu2-aarch64-v$(TFLITE_DELEGATE_RKNPU2_VERSION).tar.gz

define TFLITE_DELEGATE_RKNPU2_EXTRACT_CMDS
	$(TAR) -xzf $(DL_DIR)/$(TFLITE_DELEGATE_RKNPU2_SOURCE) -C $(@D)
endef

define TFLITE_DELEGATE_RKNPU2_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/tflite-rknpu2
	cp -r $(@D)/lib/* $(TARGET_DIR)/usr/lib/tflite-rknpu2/
	cp -r $(@D)/include $(TARGET_DIR)/usr/include/tflite-rknpu2 2>/dev/null || true
endef

else # SOURCE

TFLITE_DELEGATE_RKNPU2_SITE = https://github.com/tensorflow/tensorflow.git
TFLITE_DELEGATE_RKNPU2_SITE_METHOD = git
TFLITE_DELEGATE_RKNPU2_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release \
	-DTFLITE_ENABLE_XNNPACK=OFF \
	-DTFLITE_ENABLE_GPU=OFF

define TFLITE_DELEGATE_RKNPU2_BUILD_CMDS
	cd $(@D) && \
	./configure --target=aarch64-linux-gnu --rknpu && \
	bash tensorflow/lite/tools/make/download_dependencies.sh && \
	bash tensorflow/lite/tools/make/build_rknpu_lib.sh
endef

define TFLITE_DELEGATE_RKNPU2_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/tflite-rknpu2
	cp $(@D)/tensorflow/lite/tools/make/gen/linux_aarch64_rknpu/lib/*.so $(TARGET_DIR)/usr/lib/tflite-rknpu2/ 2>/dev/null || true
endef

endif

$(eval $(generic-package))