# 交叉编译 SDK 使用

rkbuild 产出的 SDK tarball 内含 aarch64 交叉工具链、sysroot、Buildroot 配置与所有 BSP 源码，可用于宿主机编译在 RK3588 上运行的程序。

## 产出路径

```bash
make sdk
# → dist/sdk/rk3588-gui-20251009.tar.xz       (rockchip / friendlyarm 流派)
# → dist/sdk/rk3588-alientek-...tar.xz        (alientek 流派)
```

## 解压与激活

```bash
mkdir -p /opt
sudo tar -xJf dist/sdk/rk3588-gui-20251009.tar.xz -C /opt/

cd /opt/<SDK root>     # 实际目录名见 tar 内容
ls
# 应该看到：environment-setup  Makefile  external/  sysroot/  usr/  ...
```

激活环境：

```bash
source environment-setup
echo $CC
# /opt/<SDK root>/usr/bin/aarch64-buildroot-linux-gnu-gcc
```

激活后 `cc / gcc / c++ / cmake / pkg-config / make` 等会自动指向交叉工具链与 sysroot。

## 编译 hello RK358

```bash
echo 'int main(){return 0;}' | $CC -x c -o /tmp/hello
file /tmp/hello
# /tmp/hello: ELF 64-bit LSB executable, ARM aarch64 ...
```

把它拷到 RK3588 板子上：

```bash
scp /tmp/hello root@<board-ip>:/usr/local/bin/
ssh root@<board-ip> /usr/local/bin/hello
```

## CMake 工程

```bash
mkdir hello && cd hello
cat > main.cpp <<'CPP'
#include <iostream>
int main(){ std::cout << "hello rk3588" << std::endl; return 0; }
CPP

cat > CMakeLists.txt <<'CM'
cmake_minimum_required(VERSION 3.16)
project(hello CXX)
add_executable(hello main.cpp)
target_link_libraries(hello PRIVATE stdc++)
CM

source /opt/<SDK root>/environment-setup
mkdir build && cd build
cmake ..
make -j$(nproc)
```

## 链接 RKNN / DRM / OpenCV

SDK 自带 sysroot 内 `librknnrt.so / libdrm.so / libopencv.so` 等，pkg-config 会自动找到：

```bash
source /opt/<SDK root>/environment-setup

# 编译 rknn 推理 demo
cat > demo.c <<'C'
#include <rknn_api.h>
int main(){
    rknn_context ctx;
    rknn_init(&ctx, NULL, 0, 0, NULL);
    rknn_destroy(ctx);
    return 0;
}
C
$CC demo.c -lrknnrt -o demo

# 编译带 OpenCV 的图像处理 demo
cat > demo.cpp <<'CPP'
#include <opencv2/opencv.hpp>
int main(){
    cv::Mat m(10, 10, CV_8UC3);
    return 0;
}
CPP
$CXX demo.cpp $(pkg-config --cflags --libs opencv4) -o demo
```

## 编译 GStreamer 插件

```bash
source /opt/<SDK root>/environment-setup
pkg-config --cflags --libs gstreamer-1.0
# 应输出指向 sysroot/usr/include/...gstreamer-1.0/...
```

## external/ 子目录

SDK 内自带 `external/{kernel,u-boot,mpp,rknpu2,rkbin}/`，对应 `dist/src/` 下的源码。可用于：

- 改 kernel config 后重新编译 kernel（用同一工具链）
- 编译自定义 MPP 应用
- 编译 RKNN 自定义 runtime

```bash
cd /opt/<SDK root>/external/kernel
make ARCH=arm64 CROSS_COMPILE=$CC- defconfig rk3588_defconfig
make ARCH=arm64 CROSS_COMPILE=$CC- -j$(nproc)
```

## 已知陷阱

- `pkg-config` 默认指向 sysroot 内的 .pc 文件，**不要**误用宿主机的 /usr/lib/pkgconfig。
- 编译 Qt 程序时，`qmake6` 来自 sysroot（如 `/opt/<SDK>/usr/bin/qmake6`）；可用 `qmake6 -query QT_VERSION` 验证。
- Docker 与 system service 不可用——SDK 是开发工具，不是运行环境。
- 头文件与库的位置：
  - sysroot: `/opt/<SDK>/sysroot/`
  - 工具链: `/opt/<SDK>/usr/bin/`
  - 内核头: `/opt/<SDK>/usr/lib/gcc/.../include/`

## 在 Docker 里用 SDK

如果团队希望统一开发环境：

```dockerfile
FROM ubuntu:22.04
COPY dist/sdk/rk3588-gui-20251009.tar.xz /tmp/
RUN mkdir -p /opt && \
    tar -xJf /tmp/rk3588-gui-20251009.tar.xz -C /opt && \
    apt-get update && apt-get install -y cmake make g++
WORKDIR /work
CMD ["/bin/bash", "-c", "source /opt/*/environment-setup && make"]
```