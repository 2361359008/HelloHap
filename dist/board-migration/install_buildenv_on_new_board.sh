#!/system/bin/sh
set -eu

ROOT=/data/local/tmp
META=$ROOT/hellohap-migration
IMAGE_TAR=$META/openclaw-linux-env-portable.tar

chmod 755 /data/local/bin/* 2>/dev/null || true
mkdir -p /data/docker2/etc
if [ ! -f /data/docker2/etc/daemon.json ]; then
  echo -n '{}' > /data/docker2/etc/daemon.json
fi

if [ -x /data/local/bin/docker2-start ]; then
  /data/local/bin/docker2-start || true
fi

tries=0
while [ "$tries" -lt 30 ]; do
  if /data/local/bin/dockerc2 info >/dev/null 2>&1; then
    break
  fi
  tries=$((tries + 1))
  sleep 2
done

if ! /data/local/bin/dockerc2 info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon did not become ready"
  tail -n 80 /data/docker2/dockerd.log 2>/dev/null || true
  exit 1
fi

if [ -f "$IMAGE_TAR" ]; then
  /data/local/bin/dockerc2 load -i "$IMAGE_TAR"
fi

/data/local/bin/dockerc2 rm -f linux-env >/dev/null 2>&1 || true
/data/local/bin/dockerc2 run -d \
  --name linux-env \
  --network host \
  --privileged \
  --security-opt label=disable \
  --security-opt seccomp=unconfined \
  --cgroupns host \
  -v /data/local/tmp:/data/local/tmp \
  -v /data/houmo:/root/houmo \
  -v /data/miniconda3:/root/miniconda3 \
  -v /dev:/dev \
  openclaw-linux-env:portable \
  /bin/bash -c 'while true; do sleep 3600; done'

echo "[buildenv] restore complete"
echo "[buildenv] check with: /data/local/bin/dockerc2 ps"
