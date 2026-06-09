#!/system/bin/sh
# 多元开发·随心（空白工程）：把空白初始签名 HAP 卸载+安装+启动到板上（不编译/不签名）。
# 与 install_initial_advanced.sh 对称，仅路径/包名不同。
set -u

HAP=/data/local/tmp/blank-hapbuild/blank-signed.hap
BUNDLE=com.openclaw.blankhap

echo "==> 安装空白初始签名 HAP（跳过编译/签名）: $HAP"
if [ ! -f "$HAP" ]; then
  echo "ERROR: 空白基线 HAP 不存在: $HAP（请先 hdc file send 上传该签名包）"
  exit 1
fi

echo "==> 卸载旧应用 $BUNDLE"
bm uninstall -n "$BUNDLE"

echo "==> 安装基线 HAP"
if ! bm install -p "$HAP"; then
  echo "ERROR: bm install 失败"
  exit 1
fi

echo "==> 启动应用"
aa start -a EntryAbility -b "$BUNDLE" -m entry

echo "ok: 空白初始 HAP 已安装并启动到板上"
