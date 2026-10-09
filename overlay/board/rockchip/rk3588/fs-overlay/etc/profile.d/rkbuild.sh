# /etc/profile.d/rkbuild.sh —— shell 启动时显示 rkbuild 信息 + PATH 调整
# 由 /etc/profile 自动 source

# 添加常用 PATH
export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

# Docker 命令行补全（如果已安装）
if [ -f /usr/share/bash-completion/completions/docker ]; then
    :
fi

# rkbuild 提示符
if [ -f /etc/rkbuild-release ]; then
    export RKBUILD_RELEASE="$(cat /etc/rkbuild-release)"
fi

# 显示欢迎信息（仅交互 shell）
if [ -n "$PS1" ] && [ -z "$RKBUILD_NO_BANNER" ]; then
    if [ -x /usr/local/bin/rkbuild-info ]; then
        rkbuild-info
    fi
fi