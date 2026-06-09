#!/system/bin/sh
# 多元开发·视频播放器：把视频播放器初始签名 HAP 卸载+安装+启动到板上（不编译/不签名，直接装预签好的包）。
# 与 install_initial_minesweeper.sh 对称，仅路径/包名不同。
set -u

HAP=/data/local/tmp/videoplayer-hapbuild/videoplayer-signed.hap
BUNDLE=com.openclaw.videoplayer

echo "==> 安装视频播放器初始签名 HAP（跳过编译/签名）: $HAP"
if [ ! -f "$HAP" ]; then
  echo "ERROR: 视频播放器基线 HAP 不存在: $HAP（请先 hdc file send 上传该签名包）"
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

echo "ok: 视频播放器初始 HAP 已安装并启动到板上"
