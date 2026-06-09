#!/system/bin/sh
#
# 随心 / 空白 HAP 自由开发 —— 删除一个工程副本（A 方案）。
# 删除 projects/<工程名>/ 整个目录；若 current.txt 正指向它则清空当前指针。
# 只读模板 template/ 与其它副本一律不动。
#
#   用法: sh /data/local/tmp/blank-hapbuild/blank_delete.sh <工程名>
#
set -eu

ROOT="/data/local/tmp/blank-hapbuild"
PROJECTS="$ROOT/projects"
CURRENT="$ROOT/current.txt"

NAME_RAW="${1:-}"
[ -n "$NAME_RAW" ] || { echo "ERROR: 缺工程名。用法: blank_delete.sh <工程名>" >&2; exit 2; }
# 校验工程名：只允许字母/数字/下划线/点/连字符并防路径穿越（纯 shell case，板上可能没有 tr/sed）。
NAME="$NAME_RAW"
case "$NAME" in
  ''|.|..|*/*|*[!A-Za-z0-9_.-]*)
    echo "ERROR: 工程名非法（仅允许字母数字及 . _ -）: $NAME_RAW" >&2; exit 2 ;;
esac

DEST="$PROJECTS/$NAME"
[ -d "$DEST" ] || { echo "ERROR: 工程不存在: $NAME" >&2; exit 1; }

rm -rf "$DEST"

# 若当前激活指针指向被删工程，清空指针（避免悬空）。
if [ -f "$CURRENT" ]; then
  CUR="$(cat "$CURRENT" 2>/dev/null || true)"
  if [ "$CUR" = "$DEST" ]; then : > "$CURRENT"; fi
fi

echo "DELETE_OK $DEST"
