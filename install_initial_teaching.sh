#!/system/bin/sh
# 进入「教学之路」初始化时执行：安装/启动完整主日程 HAP。
# 新板迁移后可能尚未安装该应用，因此这里会先用教学签名包补装，再启动。
# 与自由发挥的 install_initial_advanced.sh 对称（板端直跑、不经 OpenClaw），区别是这里只启动主 HAP。
set -u

BUNDLE=com.openclaw.schedulehap
HAP=/data/local/tmp/advanced-hapbuild/schedule-teaching-signed.hap

if ! bm dump -n "$BUNDLE" 2>/dev/null | grep -q "\"bundleName\": \"$BUNDLE\""; then
  echo "==> 教学 HAP 未安装，先安装: $HAP"
  if [ ! -f "$HAP" ]; then
    echo "ERROR: 教学 HAP 不存在: $HAP"
    exit 1
  fi
  if ! bm install -p "$HAP"; then
    echo "ERROR: bm install 失败"
    exit 1
  fi
fi

echo "==> 启动完整主日程 HAP: $BUNDLE"
START_OUT=$(aa start -a EntryAbility -b "$BUNDLE" -m entry 2>&1)
echo "$START_OUT"
if echo "$START_OUT" | grep -q "start ability successfully"; then
  echo "ok: 已启动完整主日程 HAP"
else
  echo "ERROR: aa start 失败（请确认板上已安装 $BUNDLE）"
  exit 1
fi
