# /etc/profile.d/rkbuild.sh —— rkbuild Ubuntu 环境
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [ -f /etc/rkbuild-release ]; then
    export RKBUILD_RELEASE="$(cat /etc/rkbuild-release)"
fi

# 仅交互 shell 显示一次简要信息；设置 RKBUILD_NO_BANNER=1 可关闭
if [ -n "$PS1" ] && [ -z "$RKBUILD_NO_BANNER" ] && [ -x /usr/local/bin/rkbuild-info ]; then
    rkbuild-info
fi
