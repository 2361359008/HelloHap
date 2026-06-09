#!/system/bin/sh
# 多元开发·随心（空白工程）：把板端可编辑工程还原到空白初始基线（从 project.tar 解出覆盖 project/）。
# 与 restore_advanced_project.sh 同结构，仅路径不同。
set -eu

ROOT=/data/local/tmp/blank-hapbuild
PROJECT="$ROOT/project"
BASELINE="$ROOT/backups/initial/project.tar"
STAGING="$ROOT/.restore-staging"
PREVIOUS="$ROOT/.restore-previous"
LOCK="$ROOT/.restore-lock"

cleanup() {
  rm -rf "$STAGING"
  rmdir "$LOCK" 2>/dev/null || true
}

if ! mkdir "$LOCK" 2>/dev/null; then
  echo "error: blank project restore is already running"
  exit 1
fi
trap cleanup EXIT INT TERM

if [ ! -s "$BASELINE" ]; then
  echo "error: initial project baseline is missing: $BASELINE"
  exit 1
fi

rm -rf "$STAGING"
mkdir -p "$STAGING"
tar -xf "$BASELINE" -C "$STAGING"

RESTORED="$STAGING/project"
INDEX_ETS="$RESTORED/entry/src/main/ets/pages/Index.ets"
if [ ! -f "$INDEX_ETS" ]; then
  echo "error: baseline archive does not contain the expected HAP project"
  exit 1
fi

rm -rf "$PREVIOUS"
if [ -d "$PROJECT" ]; then
  mv "$PROJECT" "$PREVIOUS"
fi

if ! mv "$RESTORED" "$PROJECT"; then
  if [ -d "$PREVIOUS" ]; then
    mv "$PREVIOUS" "$PROJECT"
  fi
  echo "error: failed to replace the blank HAP project"
  exit 1
fi

rm -rf "$PREVIOUS"

echo "ok: blank HAP project restored from initial baseline"
echo "project: $PROJECT"
echo "source: $PROJECT/entry/src/main/ets/pages/Index.ets"
