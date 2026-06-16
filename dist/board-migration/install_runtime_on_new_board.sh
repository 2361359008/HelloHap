#!/system/bin/sh
set -eu

ROOT=/data/local/tmp
META=$ROOT/hellohap-migration
HAPS_DIR=$META/haps

install_extra_hap() {
  hap_path=$1
  hap_name=$2

  if [ ! -f "$hap_path" ]; then
    echo "[runtime] skip missing HAP: $hap_name ($hap_path)"
    return 0
  fi

  echo "[runtime] install HAP: $hap_name"
  if bm install -r -p "$hap_path"; then
    return 0
  fi

  echo "[runtime] replace install failed, retry normal install: $hap_name"
  bm install -p "$hap_path"
}

mkdir -p "$ROOT/.openclaw/logs" "$ROOT/.openclaw/tasks"

chmod 755 "$ROOT/node" 2>/dev/null || true
chmod 755 "$ROOT/bin"/* 2>/dev/null || true
chmod 755 "$ROOT"/*.sh 2>/dev/null || true
chmod 755 "$ROOT"/*-hapbuild/*.sh 2>/dev/null || true

install_extra_hap "$HAPS_DIR/entry-default-signed.hap" "entry-default-signed.hap"
install_extra_hap "$HAPS_DIR/inputmethod-2in1-V1.0.4.hap" "inputmethod-2in1-V1.0.4.hap"

if [ -d "$META/system-bin" ] && [ -w /system/bin ]; then
  cp "$META/system-bin/openclaw" /system/bin/openclaw 2>/dev/null || true
  cp "$META/system-bin/openclaw-ctl" /system/bin/openclaw-ctl 2>/dev/null || true
  cp "$META/system-bin/openclaw-boot.sh" /system/bin/openclaw-boot.sh 2>/dev/null || true
  chmod 755 /system/bin/openclaw /system/bin/openclaw-ctl /system/bin/openclaw-boot.sh 2>/dev/null || true
fi

if command -v openclaw-ctl >/dev/null 2>&1; then
  openclaw-ctl restart || openclaw-ctl start || true
elif [ -x "$ROOT/bin/openclaw-ctl" ]; then
  "$ROOT/bin/openclaw-ctl" restart || "$ROOT/bin/openclaw-ctl" start || true
fi

echo "[runtime] restore complete"
echo "[runtime] check with: /data/local/tmp/bin/openclaw-ctl status"
