#!/system/bin/sh
#
# 随心 / 空白 HAP 自由开发 —— 新建一个工程副本。
# 从只读模板复制出一个独立工程目录到 projects/<名字>/，并设为当前工程；
# 保留 projects/ 下已有的所有工程，绝不删除/覆盖；模板永不修改。
#
#     sh /data/local/tmp/blank-hapbuild/blank_new.sh <工程名>
#
set -eu

ROOT="/data/local/tmp/blank-hapbuild"
TEMPLATE="$ROOT/template"
PROJECTS="$ROOT/projects"
CURRENT="$ROOT/current.txt"
BUNDLE="com.openclaw.blankhap"
BASELINE_HAP="$ROOT/blank-signed.hap"

NAME_RAW="${1:-}"
[ -n "$NAME_RAW" ] || { echo "ERROR: 缺少工程名（用法: blank_new.sh <工程名>）" >&2; exit 2; }
# 校验工程名：只允许字母/数字/下划线/点/连字符（用纯 shell 内置 case，板上可能没有 tr/sed）。
NAME="$NAME_RAW"
case "$NAME" in
  ''|.|..|*/*|*[!A-Za-z0-9_.-]*)
    echo "ERROR: 工程名非法（仅允许字母数字及 . _ -）: $NAME_RAW" >&2; exit 2 ;;
esac

[ -d "$TEMPLATE" ] || { echo "ERROR: 只读模板不存在: $TEMPLATE" >&2; exit 1; }
mkdir -p "$PROJECTS"

DEST="$PROJECTS/$NAME"
[ -e "$DEST" ] && { echo "ERROR: 工程已存在: $NAME（不覆盖）" >&2; exit 1; }

# 从模板复制出独立副本（模板本身不动）。
cp -a "$TEMPLATE" "$DEST"
echo "$DEST" > "$CURRENT"

# 不在这里安装基线空白 HAP：新建只负责建工程副本 + 置当前工程；
# 设备上的应用等 AI 按目标开发完、跑 assemble_deploy.sh 时再装真正的 HAP，
# 避免先闪一个空白「随心」应用。
echo "NEW_PROJECT_OK $DEST"
