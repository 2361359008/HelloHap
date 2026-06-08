#!/system/bin/sh
# 进入「教学之路」初始化时执行：仅启动（aa start）完整主日程 HAP
# （schedule-signed.hap，bundle=com.openclaw.schedulehap），不卸载、不重装。
# 要求板上已安装该应用（DevEco run 或手动 bm install 装过即可）；纯启动只把主 HAP 拉到前台，不重置数据。
# 与自由发挥的 install_initial_advanced.sh 对称（板端直跑、不经 OpenClaw），区别是这里只启动主 HAP。
set -u

BUNDLE=com.openclaw.schedulehap

echo "==> 启动完整主日程 HAP: $BUNDLE"
if aa start -a EntryAbility -b "$BUNDLE" -m entry; then
  echo "ok: 已启动完整主日程 HAP"
else
  echo "ERROR: aa start 失败（请确认板上已安装 $BUNDLE）"
  exit 1
fi
