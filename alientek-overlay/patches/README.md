# alientek-overlay/patches/

本目录放的是**注入脚本**而非 patch 文件——`patch` 的缺点是要靠行号 + 上下文匹配，对 SDK 升级很脆弱。脚本用 `sed -i` 按"行首 token 匹配"修改包开关，**不依赖行号、不依赖上下文**。

## 当前脚本

- `atk-dlrk3588B-headless.sh`：把 SDK 内 `atk_dlrk3588B_defconfig` 的 GUI 包关闭、注入 Docker / RKNN / rkbuild-helper。

## 调用方式

`scripts/lib/alientek.sh` 里的 `rkb_alien_apply_headless_patch` 函数会在 `make fetch` 时自动调用（仅当 `VARIANT=headless`）。

也可手动调用：

```bash
export BOARD=atk-dlrk3588B
bash alientek-overlay/patches/atk-dlrk3588B-headless.sh dist/src/atk-sdk
```

## 脚本做了什么

1. **备份** defconfig 为 `<defconfig>.bak.<时间戳>`
2. **关闭 GUI 包**：把 `BR2_PACKAGE_QT5=y` 改成 `# BR2_PACKAGE_QT5 is not set`（幂等，重复跑无副作用）。覆盖 GUI_REMOVE 数组里列出的所有包名。
3. **追加 headless + Docker + RKNN + rkbuild-helper** 到文件末尾
4. **去重**：用 awk 去重（不影响空行）

## 适配新的 SDK 版本

如果正点原子升级了 SDK，新增了 GUI 包（比如 `BR2_PACKAGE_QT_QUICK3D`），把包名加到 `GUI_REMOVE` 数组即可。**不需要**重新生成 patch 或修改行号。

如果 SDK 的 defconfig 路径变了（罕见），改脚本顶部的 `case "$BOARD"` 分支。

## 为什么不直接 patch

考虑过用 `diff -u` 生成 patch，但：

1. patch 需要上下文匹配，SDK 升级后即使包名相同，行号/上下文也会漂移
2. 用户需要"先 fetch SDK → diff → 生成 patch → 再 fetch"两遍跑，UX 差
3. patch dry-run 失败后报错信息不友好，用户不知道是哪个 hunk 失败

sed 脚本的好处：单遍完成、对 SDK 升级鲁棒、错误信息明确。

## 加新板

复制 `atk-dlrk3588B-headless.sh` → `<newboard>-headless.sh`，修改：

- `case "$BOARD"` 中的 defconfig 路径
- GUI_REMOVE 数组（如该板有额外 GUI 包）
- APPEND_LINES（如需特定 overlay）