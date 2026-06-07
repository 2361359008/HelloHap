#!/system/bin/sh
set -eu

ROOT=/data/local/tmp/advanced-hapbuild
PROJECT="$ROOT/project"
BASELINE="$ROOT/backups/course-initial/project.tar"
STAGING="$ROOT/.course-restore-staging"
PREVIOUS="$ROOT/.course-restore-previous"
LOCK="$ROOT/.course-restore-lock"

cleanup() {
  rm -rf "$STAGING"
  rmdir "$LOCK" 2>/dev/null || true
}

if ! mkdir "$LOCK" 2>/dev/null; then
  echo "error: advanced project restore is already running"
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
  echo "error: failed to replace the advanced HAP project"
  exit 1
fi

rm -rf "$PREVIOUS"

echo "ok: advanced HAP project restored from initial baseline"
echo "project: $PROJECT"
echo "source: $PROJECT/entry/src/main/ets/pages/Index.ets"
