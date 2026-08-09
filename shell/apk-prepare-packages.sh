#!/bin/sh
set -eu

BASE_DIR="extra-packages"
TEMP_DIR="$BASE_DIR/temp-unpack"
TARGET_DIR="packages"

# 只清理临时解包目录。25.12 ImageBuilder 的 packages/ 目录自带
# base-files、libc、kernel 等基础 APK，删除它们会让后续 apk 安装失效。
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR" "$TARGET_DIR"

# 解压 .run 文件
for run_file in "$BASE_DIR"/*.run; do
    [ -e "$run_file" ] || continue
    echo "🧩 解压 $run_file -> $TEMP_DIR"
    sh "$run_file" --target "$TEMP_DIR" --noexec
done

# 1. 收集 run 解压出的 .apk 文件
find "$TEMP_DIR" -type f -name "*.apk" -exec cp -v {} "$TARGET_DIR"/ \;

# 2. 收集 extra-packages 下的 .apk 文件。
#    递归查找可以兼容第三方仓库调整目录层级的情况。

find "$BASE_DIR" -type f -name "*.apk" ! -path "$TEMP_DIR/*" \
  -exec echo "👉 Found:" {} \; \
  -exec cp -v {} "$TARGET_DIR"/ \;

echo "✅ 所有 .apk 文件已整理至 $TARGET_DIR/"
