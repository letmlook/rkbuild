#!/usr/bin/env bash
# scripts/lib/git.sh —— git 封装（克隆、更新、解析 tag/branch）

if [[ -n "${__RKB_GIT_SH__:-}" ]]; then
    return 0
fi
__RKB_GIT_SH__=1

# ---- git clone（shallow、branch、tag 支持） ----
# 用法：rkb_git_clone <url> <dst> [branch]
rkb_git_clone() {
    local url="$1" dst="$2" branch="${3:-}"
    rkb_require_cmd git
    if [[ -d "$dst" ]]; then
        rkb_log info "已存在：$dst（跳过 clone）"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -n "$branch" ]]; then
        rkb_log info "git clone --depth 1 -b '$branch' '$url' '$dst'"
        git clone --depth 1 -b "$branch" "$url" "$dst"
    else
        rkb_log info "git clone --depth 1 '$url' '$dst'"
        git clone --depth 1 "$url" "$dst"
    fi
}

# ---- git 更新（已有目录拉最新） ----
# 用法：rkb_git_pull <repo>
rkb_git_pull() {
    local repo="$1"
    rkb_require_cmd git
    if [[ ! -d "$repo/.git" ]]; then
        rkb_die "$repo 不是 git 仓库"
    fi
    (
        cd "$repo"
        # 浅克隆不适用普通 pull；用 fetch + reset
        if git config remote.origin.url >/dev/null 2>&1; then
            rkb_log info "fetch + reset：$repo"
            git fetch --depth 1 origin HEAD 2>/dev/null \
              || git fetch --depth 1 origin
            git reset --hard FETCH_HEAD 2>/dev/null \
              || git reset --hard origin/HEAD
        fi
    )
}

# ---- git 浅克隆 + 切到指定 tag/commit ----
# 用法：rkb_git_clone_ref <url> <dst> <ref>
rkb_git_clone_ref() {
    local url="$1" dst="$2" ref="$3"
    rkb_require_cmd git
    if [[ -d "$dst" ]]; then
        rkb_log info "已存在：$dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    rkb_log info "git clone '$url' '$dst' && checkout '$ref'"
    git clone "$url" "$dst"
    (
        cd "$dst"
        if ! git checkout "$ref" 2>/dev/null; then
            # 可能 ref 是远端分支名；fetch 一次
            git fetch --depth 1 origin "$ref" 2>/dev/null
            git checkout FETCH_HEAD
        fi
    )
}

# ---- git describe（HEAD 信息） ----
rkb_git_describe() {
    local repo="$1"
    (
        cd "$repo"
        git describe --tags --always --dirty 2>/dev/null \
          || git log -1 --format='%h'
    )
}

# ---- 文件下载（curl） ----
# 用法：rkb_download <url> <dst> [sha256]
rkb_download() {
    local url="$1" dst="$2" expected_sha="${3:-}"
    rkb_require_cmd curl
    mkdir -p "$(dirname "$dst")"
    if [[ -f "$dst" ]]; then
        if [[ -n "$expected_sha" ]]; then
            local actual
            actual="$(sha256sum "$dst" | awk '{print $1}')"
            if [[ "$actual" == "$expected_sha" ]]; then
                rkb_log info "已存在且 SHA256 匹配：$dst"
                return 0
            else
                rkb_warn "SHA256 不匹配，重新下载"
                rm -f "$dst"
            fi
        else
            rkb_log info "已存在：$dst"
            return 0
        fi
    fi
    rkb_log info "下载：$url -> $dst"
    curl -fL --retry 3 --connect-timeout 15 -o "$dst" "$url" \
        || rkb_die "下载失败：$url"
    if [[ -n "$expected_sha" ]]; then
        local actual
        actual="$(sha256sum "$dst" | awk '{print $1}')"
        if [[ "$actual" != "$expected_sha" ]]; then
            rkb_die "SHA256 校验失败：$dst（期望 $expected_sha，实际 $actual）"
        fi
        rkb_log info "SHA256 校验通过"
    fi
}

# ---- tarball 解压 ----
rkb_extract() {
    local archive="$1" dst="$2"
    mkdir -p "$dst"
    case "$archive" in
        *.tar.xz|*.txz)  tar -xJf "$archive" -C "$dst" ;;
        *.tar.gz|*.tgz)  tar -xzf "$archive" -C "$dst" ;;
        *.tar.bz2|*.tbz2) tar -xjf "$archive" -C "$dst" ;;
        *.tar.zst|*.tzst) tar --zstd -xf "$archive" -C "$dst" ;;
        *.zip) unzip -q "$archive" -d "$dst" ;;
        *) rkb_die "不支持的压缩格式：$archive" ;;
    esac
}