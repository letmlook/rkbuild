# rkbuild —— RK3588 一键 Buildroot 镜像与交叉 SDK 编译脚本
# 用法见 README.md / PLAN.md

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# ============== 可配置变量 ==============
# 任何带空格的内容会被理解为变量的一部分（Makefile 不支持行内注释），故只写纯值
VENDOR       ?= rockchip
VARIANT      ?= gui
BOARD        ?= rk3588
JOBS         ?= $(shell nproc)
OUTPUT       ?= dist
SRC_DIR      ?= $(OUTPUT)/src
KEEP_CACHE   ?= 1
SDFUSE_NONINTERACTIVE ?= y
INIT_SYSTEM  ?= busybox
VERBOSE      ?= 0

# ============== 路径 ==============
RKB_ROOT     := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPTS_DIR  := $(RKB_ROOT)/scripts
VENDORS_DIR  := $(RKB_ROOT)/vendors
OVERLAY_DIR  := $(RKB_ROOT)/overlay
ALIEN_DIR    := $(RKB_ROOT)/alientek-overlay

# ============== 内部常量 ==============
RKB_VERSION  := $(shell cat $(RKB_ROOT)/VERSION 2>/dev/null || echo 0.1.0)
DATE         := $(shell date +%Y%m%d)

# vendor 配置
VENDOR_INI   := $(VENDORS_DIR)/$(VENDOR).ini
ifeq (,$(wildcard $(VENDOR_INI)))
$(error VENDOR='$(VENDOR)' 未找到 $(VENDOR_INI)；可选：rockchip | friendlyarm | alientek)
endif

# defconfig 名（不同 vendor × variant 组合）
ifeq ($(VENDOR),alientek)
DEFCONFIG    :=
BUILD_CMD    := ./build.sh
else
DEFCONFIG    := rkbuild_rk3588_$(VARIANT)_defconfig
BUILD_CMD    := make
endif

# ============== 颜色 ==============
ifndef NO_COLOR
C_RESET  := \033[0m
C_BOLD   := \033[1m
C_RED    := \033[31m
C_GREEN  := \033[36m
C_YELLOW := \033[33m
C_BLUE   := \033[34m
else
C_RESET  :=
C_BOLD   :=
C_RED    :=
C_GREEN :=
C_YELLOW:=
C_BLUE   :=
endif

# ============== 帮助 ==============
.PHONY: help
help: ## 显示本帮助
	@awk 'BEGIN{FS=":.*##"; printf "$(C_BOLD)用法：$(C_RESET) make [VENDOR=...] [VARIANT=...] <目标>\n\n"} \
		/^[a-zA-Z_-]+:.*##/{printf "  $(C_GREEN)%-12s$(C_RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ============== 顶层目标 ==============
.PHONY: init fetch defconfig config menu build image sdk clean cleanall version info

init: ## 安装编译依赖（apt-get install）
	@bash $(SCRIPTS_DIR)/init-env.sh

fetch: ## 按 VENDOR 拉源码到 $(SRC_DIR)
	@bash $(SCRIPTS_DIR)/fetch-source.sh

defconfig: ## 应用 defconfig（生成 .config）
	@bash $(SCRIPTS_DIR)/defconfig.sh

config menu: ## 打开 menuconfig
	@bash $(SCRIPTS_DIR)/menuconfig.sh

build: ## 编译镜像（rootfs + kernel + uboot）
	@bash $(SCRIPTS_DIR)/make-image.sh

image: ## 生成可烧写 SD 卡镜像
	@bash $(SCRIPTS_DIR)/mk-sd-image.sh

sdk: ## 产出交叉 SDK tarball
	@bash $(SCRIPTS_DIR)/make-sdk.sh

clean: ## 增量清理（保留 dl 缓存）
	@bash $(SCRIPTS_DIR)/clean.sh

cleanall: ## 全清（含源码）
	@bash $(SCRIPTS_DIR)/cleanall.sh

version: ## 显示版本
	@echo "rkbuild $(RKB_VERSION)"

info: ## 显示当前配置
	@echo "VENDOR       = $(VENDOR)"
	@echo "VARIANT      = $(VARIANT)"
	@echo "BOARD        = $(BOARD)"
	@echo "DEFCONFIG    = $(DEFCONFIG)"
	@echo "JOBS         = $(JOBS)"
	@echo "OUTPUT       = $(OUTPUT)"
	@echo "SRC_DIR      = $(SRC_DIR)"
	@echo "VENDOR_INI   = $(VENDOR_INI)"
	@echo "BUILD_CMD    = $(BUILD_CMD)"
	@echo "DATE         = $(DATE)"