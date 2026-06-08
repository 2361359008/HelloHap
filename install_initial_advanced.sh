#!/system/bin/sh
# 进入「自由开发」初始化身份时执行：把最原始的日程 HAP 基线包安装到板上并启动。
# 跳过编译/签名（直接装预先备份好的基线签名包），所以比跑完整编译流程快很多。
# 由 restore agent 在身份初始化那一轮直接执行（见 FreeDevContent.buildScheduleIdentityPrompt）。
set -u

HAP=/data/local/tmp/advanced-hapbuild/schedule-initial-signed.hap
BUNDLE=com.openclaw.schedulehap.lite

echo "==> 安装最原始的日程 HAP 基线包（跳过编译/签名）: $HAP"
if [ ! -f "$HAP" ]; then
  echo "ERROR: 基线 HAP 不存在: $HAP（请先用 hdc file send 把基线签名包上传到该路径）"
  exit 1
fi

echo "==> 卸载旧应用: $BUNDLE"
bm uninstall -n "$BUNDLE"

echo "==> 安装基线 HAP"
if ! bm install -p "$HAP"; then
  echo "ERROR: bm install 失败"
  exit 1
fi

echo "==> 启动应用"
aa start -a EntryAbility -b "$BUNDLE" -m entry

echo "ok: 已把最原始的日程 HAP 安装并启动到板上"
