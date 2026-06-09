#!/system/bin/sh
#
# 随心 / 空白 HAP 自由开发 —— 一键清空所有工程副本（A 方案，慎用）。
# 删除 projects/ 下全部副本并清空 current.txt；只读模板 template/ 不动。
#
#   用法: sh /data/local/tmp/blank-hapbuild/blank_clear_all.sh
#
set -eu

ROOT="/data/local/tmp/blank-hapbuild"
PROJECTS="$ROOT/projects"
CURRENT="$ROOT/current.txt"

if [ -d "$PROJECTS" ]; then
  rm -rf "$PROJECTS"
fi
mkdir -p "$PROJECTS"

# 清空当前激活指针。
if [ -f "$CURRENT" ]; then : > "$CURRENT"; fi

echo "CLEAR_ALL_OK"
