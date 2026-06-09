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
# 只保留安全字符并把空格转连字符，避免路径穿越。
NAME="$(echo "$NAME_RAW" | tr ' ' '-' | sed 's/[^A-Za-z0-9_.-]//g')"
[ -n "$NAME" ] || { echo "ERROR: 工程名非法" >&2; exit 2; }
# 进一步防穿越：拒绝 . / .. 这类名字。
case "$NAME" in
  .|..|*/*) echo "ERROR: 工程名非法" >&2; exit 2 ;;
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
