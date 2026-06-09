#!/system/bin/sh
#
# 随心 / 空白 HAP 自由开发 —— 切换到一个已有工程副本继续开发。
# 把 current.txt 指向所选工程；并安装该工程上次构建的 HAP（若有），
# 否则退回基线空白 HAP。不清空、不删除任何工程。
#
#     sh /data/local/tmp/blank-hapbuild/blank_select.sh <工程名>
#
set -eu

ROOT="/data/local/tmp/blank-hapbuild"
PROJECTS="$ROOT/projects"
CURRENT="$ROOT/current.txt"
BUNDLE="com.openclaw.blankhap"
BASELINE_HAP="$ROOT/blank-signed.hap"

NAME_RAW="${1:-}"
[ -n "$NAME_RAW" ] || { echo "ERROR: 缺少工程名（用法: blank_select.sh <工程名>）" >&2; exit 2; }
# 校验工程名：只允许字母/数字/下划线/点/连字符（用纯 shell 内置 case，板上可能没有 tr/sed）。
NAME="$NAME_RAW"
case "$NAME" in
  ''|.|..|*/*|*[!A-Za-z0-9_.-]*)
    echo "ERROR: 工程名非法（仅允许字母数字及 . _ -）: $NAME_RAW" >&2; exit 2 ;;
esac

DEST="$PROJECTS/$NAME"
[ -d "$DEST" ] || { echo "ERROR: 工程不存在: $NAME" >&2; exit 1; }
echo "$DEST" > "$CURRENT"

# 优先装该工程自己上次构建的产物，否则退回基线空白 HAP。
HAP="$DEST/.build/blankhap-signed.hap"
[ -s "$HAP" ] || HAP="$BASELINE_HAP"
if [ -s "$HAP" ]; then
  aa force-stop "$BUNDLE" >/dev/null 2>&1 || true
  bm uninstall -n "$BUNDLE" >/dev/null 2>&1 || true
  INSTALL_OUTPUT="$(bm install -p "$HAP" 2>&1)" || { echo "$INSTALL_OUTPUT" >&2; echo "WARN: HAP 安装失败" >&2; }
  echo "$INSTALL_OUTPUT"
  aa start -a EntryAbility -b "$BUNDLE" >/dev/null 2>&1 || true
fi

echo "SELECT_OK $DEST"
