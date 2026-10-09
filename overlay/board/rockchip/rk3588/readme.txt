rkbuild board overlay: rockchip/rk3588
======================================

This directory is rsynced into the buildroot working tree as
  dist/src/buildroot/board/rockchip/rk3588/

Contents:
  fs-overlay/        BR2_ROOTFS_OVERLAY 注入到最终 rootfs
    etc/
      docker/daemon.json      Docker 完整功能 daemon 配置
      init.d/S95dockerd       busybox init 风格 dockerd 启动
      init.d/S96docker-preload firstboot 预置 docker 镜像
      motd                    登录欢迎信息
      profile.d/rkbuild.sh    shell 启动钩子
      rkbuild-release.tmpl    /etc/rkbuild-release 模板
    usr/local/bin/
      rkbuild-info            显示版本与硬件信息
      rkbuild-doctor          健康检查
      rkbuild-docker-preload  docker 镜像预载
  kernel-fragment.config       Docker 必需的内核配置
  post-image.sh                Buildroot 后置钩子

由 scripts/apply-overlay.sh 在 make fetch 时自动拷贝。