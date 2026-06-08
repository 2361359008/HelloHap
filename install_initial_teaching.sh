#!/system/bin/sh
# 进入「教学之路」初始化时执行：把完整主日程 HAP（schedule-signed.hap，bundle=com.openclaw.schedulehap）
# 安装到板上并启动，作为教学之路的初始状态。跳过编译/签名（直接装预先备份好的签名包），所以很快。
# 与自由发挥的 install_initial_advanced.sh 对称，只是装的是完整主 HAP（非 .lite 分身）。
set -u

HAP=/data/local/tmp/advanced-hapbuild/schedule-signed.hap
BUNDLE=com.openclaw.schedulehap

echo "==> 安装完整主日程 HAP（跳过编译/签名）: $HAP"
if [ ! -f "$HAP" ]; then
  echo "ERROR: 主 HAP 不存在: $HAP（请先用 hdc file send 把主签名包上传到该路径）"
  exit 1
fi

echo "==> 卸载旧应用: $BUNDLE"
bm uninstall -n "$BUNDLE"

echo "==> 安装主 HAP"
if ! bm install -p "$HAP"; then
  echo "ERROR: bm install 失败"
  exit 1
fi

echo "==> 启动应用"
aa start -a EntryAbility -b "$BUNDLE" -m entry

echo "ok: 已把完整主日程 HAP 安装并启动到板上"
