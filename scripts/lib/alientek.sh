#!/usr/bin/env bash
# scripts/lib/alientek.sh —— 正点原子 Mega.nz tarball 处理专用
#
# Mega.nz 文件不能用普通 curl 直链下载；需 megatools 或手放文件。
# 本脚本提供：
#   - rkb_alien_check_megatools       检查是否安装 megatools
#   - rkb_alien_download_tarball      用 megatools dl 下载
#   - rkb_alientek_pick_tarball       提示用户手放文件路径
#   - rkb_alien_verify_sha256         校验 tarball

if [[ -n "${__RKB_ALIENTEK_SH__:-}" ]]; then
    return 0
fi
__RKB_ALIENTEK_SH__=1

# ---- 检查 megatools ----
rkb_alien_check_megatools() {
    if command -v megatools >/dev/null 2>&1; then
        rkb_log info "已安装 megatools"
        return 0
    fi
    rkb_warn "未安装 megatools；Mega.nz 链接需要 megatools 或手动下载"
    return 1
}

# ---- 用 megatools dl 下载 ----
rkb_alien_download_tarball() {
    local url="$1" dst="$2" sha="${3:-}"
    rkb_alien_check_megatools || rkb_die "需要 megatools：sudo apt install megatools"
    if [[ -f "$dst" ]]; then
        rkb_alien_verify_sha256 "$dst" "$sha" && return 0
        rkb_warn "已存在但 SHA256 不匹配，重新下载"
        rm -f "$dst"
    fi
    mkdir -p "$(dirname "$dst")"
    rkb_log info "megatools dl '$url' -> '$dst'"
    megatools dl --path "$dst" "$url" || rkb_die "megatools dl 失败"
    rkb_alien_verify_sha256 "$dst" "$sha"
}

# ---- 提示用户手放 tarball ----
rkb_alientek_pick_tarball() {
    local board="$1"
    local dst="${OUTPUT}/src/atk-sdk-${board}.tar.xz"
    local marker="${OUTPUT}/src/.atk-${board}.tarball"

    if [[ -f "$dst" ]]; then
        printf '%s\n' "$dst"
        return 0
    fi

    rkb_warn "需要 ${board} SDK tarball（来自 Mega.nz）；如 megatools 已装好可让脚本自动下载，否则："
    rkb_warn "  1) 浏览器打开 https://mega.nz/flder/T1QyjKSI#ysQfY6-w_V1g0kBio79TOQ"
    rkb_warn "  2) 下载整个目录（含 SDK tarball），将 *.tar.xz 放到 ${OUTPUT}/src/atk-sdk-${board}.tar.xz"
    rkb_warn "  3) 重跑 make fetch"

    if rkb_alien_check_megatools; then
        local url
        url="$(rkb_vendor_get "${board^^}_URL" 2>/dev/null || true)"
        # 兼容形如 ATK_DLRK3588B_URL / QUARKPI_URL
        if [[ -z "$url" ]]; then
            url="$(rkb_vendor_get "$(echo "${board}" | tr '[:lower:]' '[:upper:]' | tr - _)_URL" 2>/dev/null || true)"
        fi
        if [[ -n "$url" ]]; then
            rkb_alien_download_tarball "$url" "$dst" "$(rkb_vendor_get "$(echo "${board}" | tr '[:lower:]' '[:upper:]' | tr - _)_SHA256" 2>/dev/null || true)"
            printf '%s\n' "$dst"
            return 0
        fi
    fi

    rkb_die "缺少 ${board} SDK tarball，且 megatools 不可用"
}

# ---- SHA256 校验 ----
rkb_alien_verify_sha256() {
    local file="$1" expected="$2"
    [[ -f "$file" ]] || return 1
    if [[ -z "$expected" ]]; then
        rkb_warn "未提供 SHA256 期望值，跳过校验"
        return 0
    fi
    local actual
    actual="$(sha256sum "$file" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        rkb_log error "SHA256 不匹配："
        rkb_log error "  期望：$expected"
        rkb_log error "  实际：$actual"
        return 1
    fi
    rkb_log info "SHA256 校验通过：$file"
}

# ---- 应用 alientek headless 配置注入 ----
# 不再用 patch；改用 alientek-overlay/patches/<board>-headless.sh 直接 sed。
# 优势：
#   - 不依赖行号、不依赖上下文匹配
#   - SDK 升级后只要包名没变仍可工作
#   - 幂等：可重复跑
rkb_alien_apply_headless_patch() {
    local sdk_dir="$1" board="$2"
    local script="${ALIEN_DIR}/patches/${board}-headless.sh"
    if [[ ! -f "$script" ]]; then
        rkb_warn "未找到 headless 注入脚本：$script（跳过；alientek GUI 模式默认）"
        return 0
    fi
    if [[ "${VARIANT}" != "headless" ]]; then
        rkb_log info "VARIANT=${VARIANT}，跳过 headless 注入"
        return 0
    fi
    rkb_log info "应用 headless 注入脚本：$script"
    sh "$script" "$sdk_dir"
    rkb_ok "headless 注入已完成"
}