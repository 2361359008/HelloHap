#!/system/bin/sh
set -eu
CONTAINER="${CONTAINER:-linux-env}"
DOCKER_CLI="${DOCKER_CLI:-/data/local/bin/dockerc2}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="${BASE_DIR:-$(dirname "$SCRIPT_DIR")}"
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
SIGNING_DIR="${SIGNING_DIR:-$PROJECT_DIR/../../signature}"
CONTAINER_PROJECT="/root/HAP-BuildKit/tetris-project"
CONTAINER_SIGNING="/root/HAP-BuildKit/tetris-signing"
SDK_ROOT="/root/HAP-BuildKit/ohos_sdk/23"
SIGN_TOOL="$SDK_ROOT/toolchains/lib/hap-sign-tool.jar"
PROFILE_CERT="$SDK_ROOT/toolchains/lib/OpenHarmonyProfileRelease.pem"
CONTAINER_PYTHON=""
BUNDLE_NAME="com.openclaw.tetris"
ABILITY_NAME="EntryAbility"
UNSIGNED_HAP="$BASE_DIR/tetris-unsigned.hap"
SIGNED_HAP="$BASE_DIR/tetris-signed.hap"

log() { echo ""; echo "========== $* =========="; }
fail() { echo "ERROR: $*" >&2; exit 1; }
run_docker() { "$DOCKER_CLI" "$@"; }
find_sf() {
  if [ -f "$SIGNING_DIR/$1" ]; then echo "$SIGNING_DIR/$1"
  else return 1; fi
}

log "0/7 检查环境"
[ -x "$DOCKER_CLI" ] || fail "Docker 客户端不存在"
[ -d "$PROJECT_DIR" ] || fail "工程不存在"
PROFILE_JSON="$(find_sf HelloHap_debug_profile.json)" || fail "profile.json 缺失"
KEYSTORE="$(find_sf OpenHarmony.p12)" || fail "p12 缺失"
APP_CERT="$(find_sf OpenHarmonyAppChain.pem)" || fail "AppChain 缺失"
run_docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$" || fail "容器未运行"
if run_docker exec "$CONTAINER" test -x /usr/bin/python3; then CONTAINER_PYTHON="/usr/bin/python3"
elif run_docker exec "$CONTAINER" test -x /root/miniconda3/bin/python3; then CONTAINER_PYTHON="/root/miniconda3/bin/python3"
else CONTAINER_PYTHON="$(run_docker exec "$CONTAINER" which python3 2>/dev/null || true)"; fi
[ -n "$CONTAINER_PYTHON" ] || fail "Python 3 缺失"
echo "包名：$BUNDLE_NAME"

log "1/7 同步工程"
if ! run_docker exec "$CONTAINER" test -d "$CONTAINER_PROJECT/node_modules"; then
  run_docker exec "$CONTAINER" rm -rf "$CONTAINER_PROJECT"
  run_docker exec "$CONTAINER" cp -a /root/HAP-BuildKit/project "$CONTAINER_PROJECT"
fi
run_docker cp "$PROJECT_DIR/." "$CONTAINER:$CONTAINER_PROJECT/"

log "2/7 编译"
run_docker exec "$CONTAINER" rm -rf "$CONTAINER_PROJECT/entry/build"
run_docker exec -e OHOS_SDK_HOME=/root/HAP-BuildKit/ohos_sdk -w "$CONTAINER_PROJECT" "$CONTAINER" \
  node node_modules/@ohos/hvigor/bin/hvigor.js assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
CU="$CONTAINER_PROJECT/entry/build/default/outputs/default/entry-default-unsigned.hap"
run_docker exec "$CONTAINER" test -s "$CU" || fail "编译失败"
rm -f "$UNSIGNED_HAP"; run_docker cp "$CONTAINER:$CU" "$UNSIGNED_HAP"
ls -lh "$UNSIGNED_HAP"

log "3/7 签名材料"
run_docker exec "$CONTAINER" rm -rf "$CONTAINER_SIGNING"
run_docker exec "$CONTAINER" mkdir -p "$CONTAINER_SIGNING"
run_docker cp "$PROFILE_JSON" "$CONTAINER:$CONTAINER_SIGNING/profile.json"
run_docker cp "$KEYSTORE" "$CONTAINER:$CONTAINER_SIGNING/OpenHarmony.p12"
run_docker cp "$APP_CERT" "$CONTAINER:$CONTAINER_SIGNING/OpenHarmonyAppChain.pem"
run_docker exec -e P="$CONTAINER_SIGNING/profile.json" -e B="$BUNDLE_NAME" "$CONTAINER" "$CONTAINER_PYTHON" -c \
"import json,os
p=os.environ['P']
with open(p,encoding='utf-8-sig') as f: d=json.load(f)
d['validity']={'not-before':1704067200,'not-after':1924905600}
d['type']='release'; d['app-distribution-type']='os_integration'; d.pop('debug-info',None)
bi=d.setdefault('bundle-info',{}); bi['bundle-name']=os.environ['B']
if 'development-certificate' in bi: bi['distribution-certificate']=bi.pop('development-certificate')
with open(p,'w',encoding='utf-8') as f: json.dump(d,f,ensure_ascii=False,indent=2)"

log "4/7 签名 Profile"
run_docker exec "$CONTAINER" java -jar "$SIGN_TOOL" sign-profile -mode localSign \
  -keyAlias "openharmony application profile release" -keyPwd 123456 \
  -profileCertFile "$PROFILE_CERT" -inFile "$CONTAINER_SIGNING/profile.json" \
  -signAlg SHA256withECDSA -keystoreFile "$CONTAINER_SIGNING/OpenHarmony.p12" -keystorePwd 123456 \
  -outFile "$CONTAINER_SIGNING/tetris-profile.p7b"

log "5/7 签名 HAP"
CS="$CONTAINER_PROJECT/entry/build/default/outputs/default/tetris-signed.hap"
run_docker exec "$CONTAINER" rm -f "$CS"
run_docker exec "$CONTAINER" java -jar "$SIGN_TOOL" sign-app -mode localSign \
  -keyAlias "openharmony application release" -keyPwd 123456 \
  -appCertFile "$CONTAINER_SIGNING/OpenHarmonyAppChain.pem" \
  -profileFile "$CONTAINER_SIGNING/tetris-profile.p7b" \
  -inFile "$CU" -signAlg SHA256withECDSA \
  -keystoreFile "$CONTAINER_SIGNING/OpenHarmony.p12" -keystorePwd 123456 \
  -compatibleVersion 23 -outFile "$CS" -signCode 1
run_docker exec "$CONTAINER" test -s "$CS" || fail "签名失败"
rm -f "$SIGNED_HAP"; run_docker cp "$CONTAINER:$CS" "$SIGNED_HAP"
ls -lh "$SIGNED_HAP"

log "6/7 安装"
aa force-stop "$BUNDLE_NAME" >/dev/null 2>&1 || true
bm uninstall -n "$BUNDLE_NAME" >/dev/null 2>&1 || true
bm install -p "$SIGNED_HAP" 2>&1

log "7/7 启动"
aa start -a "$ABILITY_NAME" -b "$BUNDLE_NAME" 2>&1
sleep 2
ps -ef | grep "$BUNDLE_NAME" | grep -v grep && echo "" && echo "=============================================" && echo "🧱 俄罗斯方块 HAP 构建成功！" && echo "============================================="
