#!/system/bin/sh
#
# 视频播放器 HAP：编译 + 签名 + 安装 + 启动（与 build_minesweeper.sh 对称，仅路径/包名不同）。
set -eu

CONTAINER="${CONTAINER:-linux-env}"
DOCKER_CLI="${DOCKER_CLI:-/data/local/bin/dockerc2}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="${BASE_DIR:-$(dirname "$SCRIPT_DIR")}"
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
SIGNING_DIR="${SIGNING_DIR:-$PROJECT_DIR/../../signature}"
CONTAINER_PROJECT="/root/HAP-BuildKit/videoplayer-project"
CONTAINER_SIGNING="/root/HAP-BuildKit/videoplayer-signing"
SDK_ROOT="/root/HAP-BuildKit/ohos_sdk/23"
SIGN_TOOL="$SDK_ROOT/toolchains/lib/hap-sign-tool.jar"
PROFILE_CERT="$SDK_ROOT/toolchains/lib/OpenHarmonyProfileRelease.pem"
CONTAINER_PYTHON=""

BUNDLE_NAME="com.openclaw.videoplayer"
ABILITY_NAME="EntryAbility"
UNSIGNED_HAP="$BASE_DIR/videoplayer-unsigned.hap"
SIGNED_HAP="$BASE_DIR/videoplayer-signed.hap"

log() { echo ""; echo "========== $* =========="; }
fail() { echo ""; echo "ERROR: $*" >&2; exit 1; }
run_docker() { "$DOCKER_CLI" "$@"; }

find_signing_file() {
  NAME="$1"
  if [ -f "$SIGNING_DIR/$NAME" ]; then echo "$SIGNING_DIR/$NAME"
  else return 1; fi
}

log "0/7 检查构建环境"
[ -x "$DOCKER_CLI" ] || fail "Docker 客户端不存在: $DOCKER_CLI"
[ -d "$PROJECT_DIR" ] || fail "工程目录不存在: $PROJECT_DIR"
[ -f "$PROJECT_DIR/AppScope/app.json5" ] || fail "缺少 AppScope/app.json5"
[ -f "$PROJECT_DIR/entry/src/main/ets/pages/Index.ets" ] || fail "缺少 Index.ets"

PROFILE_JSON="$(find_signing_file HelloHap_debug_profile.json)" || fail "找不到 profile.json"
KEYSTORE="$(find_signing_file OpenHarmony.p12)" || fail "找不到 OpenHarmony.p12"
APP_CERT="$(find_signing_file OpenHarmonyAppChain.pem)" || fail "找不到 AppChain.pem"

if ! run_docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  fail "Docker 容器 $CONTAINER 未运行"
fi

run_docker exec "$CONTAINER" test -f "$SIGN_TOOL" || fail "容器内缺少签名工具"

if run_docker exec "$CONTAINER" test -x /root/miniconda3/bin/python3; then
  CONTAINER_PYTHON="/root/miniconda3/bin/python3"
elif run_docker exec "$CONTAINER" test -x /usr/bin/python3; then
  CONTAINER_PYTHON="/usr/bin/python3"
else
  CONTAINER_PYTHON="$(run_docker exec "$CONTAINER" which python3 2>/dev/null || true)"
fi
[ -n "$CONTAINER_PYTHON" ] || fail "容器内没有 Python 3"

echo "工程: $PROJECT_DIR"
echo "包名: $BUNDLE_NAME"

log "1/7 同步工程到 Docker"
if ! run_docker exec "$CONTAINER" test -d "$CONTAINER_PROJECT/node_modules"; then
  echo "首次构建: 基于基线工程创建"
  run_docker exec "$CONTAINER" rm -rf "$CONTAINER_PROJECT"
  run_docker exec "$CONTAINER" cp -a /root/HAP-BuildKit/project "$CONTAINER_PROJECT"
fi
run_docker cp "$PROJECT_DIR/." "$CONTAINER:$CONTAINER_PROJECT/"

run_docker exec "$CONTAINER" grep -q "\"bundleName\"[[:space:]]*:[[:space:]]*\"$BUNDLE_NAME\"" \
  "$CONTAINER_PROJECT/AppScope/app.json5" || fail "bundleName 不是 $BUNDLE_NAME"

log "2/7 编译 HAP"
run_docker exec "$CONTAINER" rm -rf "$CONTAINER_PROJECT/entry/build"
run_docker exec \
  -e OHOS_SDK_HOME=/root/HAP-BuildKit/ohos_sdk \
  -w "$CONTAINER_PROJECT" \
  "$CONTAINER" \
  node node_modules/@ohos/hvigor/bin/hvigor.js \
  assembleHap --mode module -p product=default -p buildMode=debug --no-daemon

CONTAINER_UNSIGNED="$CONTAINER_PROJECT/entry/build/default/outputs/default/entry-default-unsigned.hap"
run_docker exec "$CONTAINER" test -s "$CONTAINER_UNSIGNED" || fail "编译失败"
rm -f "$UNSIGNED_HAP"
run_docker cp "$CONTAINER:$CONTAINER_UNSIGNED" "$UNSIGNED_HAP"
[ -s "$UNSIGNED_HAP" ] || fail "导出未签名 HAP 失败"
ls -lh "$UNSIGNED_HAP"

log "3/7 准备签名材料"
run_docker exec "$CONTAINER" rm -rf "$CONTAINER_SIGNING"
run_docker exec "$CONTAINER" mkdir -p "$CONTAINER_SIGNING"
run_docker cp "$PROFILE_JSON" "$CONTAINER:$CONTAINER_SIGNING/profile.json"
run_docker cp "$KEYSTORE" "$CONTAINER:$CONTAINER_SIGNING/OpenHarmony.p12"
run_docker cp "$APP_CERT" "$CONTAINER:$CONTAINER_SIGNING/OpenHarmonyAppChain.pem"

run_docker exec \
  -e PROFILE_PATH="$CONTAINER_SIGNING/profile.json" \
  -e TARGET_BUNDLE="$BUNDLE_NAME" \
  "$CONTAINER" "$CONTAINER_PYTHON" -c \
  "import json,os
p=os.environ['PROFILE_PATH']
with open(p,encoding='utf-8-sig') as f: d=json.load(f)
d['validity']={'not-before':1704067200,'not-after':1924905600}
d['type']='release'
d['app-distribution-type']='os_integration'
d.pop('debug-info',None)
bi=d.setdefault('bundle-info',{})
bi['bundle-name']=os.environ['TARGET_BUNDLE']
if 'development-certificate' in bi:
    bi['distribution-certificate']=bi.pop('development-certificate')
with open(p,'w',encoding='utf-8') as f: json.dump(d,f,ensure_ascii=False,indent=2)"

log "4/7 签 Profile"
run_docker exec "$CONTAINER" \
  java -jar "$SIGN_TOOL" sign-profile \
  -mode localSign \
  -keyAlias "openharmony application profile release" \
  -keyPwd 123456 \
  -profileCertFile "$PROFILE_CERT" \
  -inFile "$CONTAINER_SIGNING/profile.json" \
  -signAlg SHA256withECDSA \
  -keystoreFile "$CONTAINER_SIGNING/OpenHarmony.p12" \
  -keystorePwd 123456 \
  -outFile "$CONTAINER_SIGNING/videoplayer-profile.p7b"

log "5/7 签 HAP"
CONTAINER_SIGNED="$CONTAINER_PROJECT/entry/build/default/outputs/default/videoplayer-signed.hap"
run_docker exec "$CONTAINER" rm -f "$CONTAINER_SIGNED"
run_docker exec "$CONTAINER" \
  java -jar "$SIGN_TOOL" sign-app \
  -mode localSign \
  -keyAlias "openharmony application release" \
  -keyPwd 123456 \
  -appCertFile "$CONTAINER_SIGNING/OpenHarmonyAppChain.pem" \
  -profileFile "$CONTAINER_SIGNING/videoplayer-profile.p7b" \
  -inFile "$CONTAINER_UNSIGNED" \
  -signAlg SHA256withECDSA \
  -keystoreFile "$CONTAINER_SIGNING/OpenHarmony.p12" \
  -keystorePwd 123456 \
  -compatibleVersion 23 \
  -outFile "$CONTAINER_SIGNED" \
  -signCode 1

run_docker exec "$CONTAINER" test -s "$CONTAINER_SIGNED" || fail "签名失败"
rm -f "$SIGNED_HAP"
run_docker cp "$CONTAINER:$CONTAINER_SIGNED" "$SIGNED_HAP"
[ -s "$SIGNED_HAP" ] || fail "导出已签名 HAP 失败"
ls -lh "$SIGNED_HAP"

log "6/7 安装 HAP"
aa force-stop "$BUNDLE_NAME" >/dev/null 2>&1 || true
bm uninstall -n "$BUNDLE_NAME" >/dev/null 2>&1 || true
INSTALL_OUTPUT="$(bm install -p "$SIGNED_HAP" 2>&1)" || { echo "$INSTALL_OUTPUT" >&2; fail "安装失败"; }
echo "$INSTALL_OUTPUT"
echo "$INSTALL_OUTPUT" | grep -q "success" || fail "安装未返回 success"

log "7/7 启动应用"
START_OUTPUT="$(aa start -a "$ABILITY_NAME" -b "$BUNDLE_NAME" 2>&1)" || { echo "$START_OUTPUT" >&2; fail "启动失败"; }
echo "$START_OUTPUT"
sleep 2

echo ""
echo "============================================="
echo "视频播放器 HAP 构建完成！"
echo "Bundle:  $BUNDLE_NAME"
echo "Signed:  $SIGNED_HAP"
echo "============================================="
