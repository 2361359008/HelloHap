#!/system/bin/sh
set -eu

CONTAINER="${CONTAINER:-linux-env}"
DOCKER_CLI="${DOCKER_CLI:-/data/local/bin/dockerc2}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="${BASE_DIR:-$(dirname "$SCRIPT_DIR")}"
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
SIGNING_DIR="${SIGNING_DIR:-$PROJECT_DIR/../../signature}"
CONTAINER_PROJECT="/root/HAP-BuildKit/calculator-project"
CONTAINER_SIGNING="/root/HAP-BuildKit/calculator-signing"
SDK_ROOT="/root/HAP-BuildKit/ohos_sdk/23"
SIGN_TOOL="$SDK_ROOT/toolchains/lib/hap-sign-tool.jar"
PROFILE_CERT="$SDK_ROOT/toolchains/lib/OpenHarmonyProfileRelease.pem"
BUNDLE_NAME="com.openclaw.calculator"
ABILITY_NAME="EntryAbility"
UNSIGNED_HAP="$BASE_DIR/calculator-unsigned.hap"
SIGNED_HAP="$BASE_DIR/calculator-signed.hap"

log() { echo ""; echo "========== $* =========="; }
fail() { echo "ERROR: $*" >&2; exit 1; }
run_docker() { "$DOCKER_CLI" "$@"; }
find_signing_file() {
  [ -f "$SIGNING_DIR/$1" ] && echo "$SIGNING_DIR/$1" || return 1
}

log "0/7 Check environment"
[ -x "$DOCKER_CLI" ] || fail "Docker client is missing"
[ -d "$PROJECT_DIR" ] || fail "Project directory is missing"
PROFILE_JSON="$(find_signing_file HelloHap_debug_profile.json)" || fail "Profile is missing"
KEYSTORE="$(find_signing_file OpenHarmony.p12)" || fail "Keystore is missing"
APP_CERT="$(find_signing_file OpenHarmonyAppChain.pem)" || fail "App certificate is missing"
run_docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$" || fail "Container is not running"
if run_docker exec "$CONTAINER" test -x /usr/bin/python3; then
  CONTAINER_PYTHON=/usr/bin/python3
elif run_docker exec "$CONTAINER" test -x /root/miniconda3/bin/python3; then
  CONTAINER_PYTHON=/root/miniconda3/bin/python3
else
  CONTAINER_PYTHON="$(run_docker exec "$CONTAINER" which python3 2>/dev/null || true)"
fi
[ -n "$CONTAINER_PYTHON" ] || fail "Python 3 is missing"

log "1/7 Sync project"
if ! run_docker exec "$CONTAINER" test -d "$CONTAINER_PROJECT/node_modules"; then
  run_docker exec "$CONTAINER" rm -rf "$CONTAINER_PROJECT"
  run_docker exec "$CONTAINER" cp -a /root/HAP-BuildKit/project "$CONTAINER_PROJECT"
fi
run_docker cp "$PROJECT_DIR/." "$CONTAINER:$CONTAINER_PROJECT/"

log "2/7 Build"
run_docker exec "$CONTAINER" rm -rf "$CONTAINER_PROJECT/entry/build"
run_docker exec -e OHOS_SDK_HOME=/root/HAP-BuildKit/ohos_sdk \
  -w "$CONTAINER_PROJECT" "$CONTAINER" \
  node node_modules/@ohos/hvigor/bin/hvigor.js \
  assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
CONTAINER_UNSIGNED="$CONTAINER_PROJECT/entry/build/default/outputs/default/entry-default-unsigned.hap"
run_docker exec "$CONTAINER" test -s "$CONTAINER_UNSIGNED" || fail "Build failed"
rm -f "$UNSIGNED_HAP"
run_docker cp "$CONTAINER:$CONTAINER_UNSIGNED" "$UNSIGNED_HAP"

log "3/7 Prepare signing material"
run_docker exec "$CONTAINER" rm -rf "$CONTAINER_SIGNING"
run_docker exec "$CONTAINER" mkdir -p "$CONTAINER_SIGNING"
run_docker cp "$PROFILE_JSON" "$CONTAINER:$CONTAINER_SIGNING/profile.json"
run_docker cp "$KEYSTORE" "$CONTAINER:$CONTAINER_SIGNING/OpenHarmony.p12"
run_docker cp "$APP_CERT" "$CONTAINER:$CONTAINER_SIGNING/OpenHarmonyAppChain.pem"
run_docker exec -e P="$CONTAINER_SIGNING/profile.json" -e B="$BUNDLE_NAME" \
  "$CONTAINER" "$CONTAINER_PYTHON" -c \
"import json,os
p=os.environ['P']
with open(p,encoding='utf-8-sig') as f: d=json.load(f)
d['validity']={'not-before':1704067200,'not-after':1924905600}
d['type']='release'
d['app-distribution-type']='os_integration'
d.pop('debug-info',None)
bi=d.setdefault('bundle-info',{})
bi['bundle-name']=os.environ['B']
if 'development-certificate' in bi:
    bi['distribution-certificate']=bi.pop('development-certificate')
with open(p,'w',encoding='utf-8') as f:
    json.dump(d,f,ensure_ascii=False,indent=2)"

log "4/7 Sign profile"
run_docker exec "$CONTAINER" java -jar "$SIGN_TOOL" sign-profile \
  -mode localSign -keyAlias "openharmony application profile release" \
  -keyPwd 123456 -profileCertFile "$PROFILE_CERT" \
  -inFile "$CONTAINER_SIGNING/profile.json" -signAlg SHA256withECDSA \
  -keystoreFile "$CONTAINER_SIGNING/OpenHarmony.p12" -keystorePwd 123456 \
  -outFile "$CONTAINER_SIGNING/calculator-profile.p7b"

log "5/7 Sign HAP"
CONTAINER_SIGNED="$CONTAINER_PROJECT/entry/build/default/outputs/default/calculator-signed.hap"
run_docker exec "$CONTAINER" rm -f "$CONTAINER_SIGNED"
run_docker exec "$CONTAINER" java -jar "$SIGN_TOOL" sign-app \
  -mode localSign -keyAlias "openharmony application release" \
  -keyPwd 123456 -appCertFile "$CONTAINER_SIGNING/OpenHarmonyAppChain.pem" \
  -profileFile "$CONTAINER_SIGNING/calculator-profile.p7b" \
  -inFile "$CONTAINER_UNSIGNED" -signAlg SHA256withECDSA \
  -keystoreFile "$CONTAINER_SIGNING/OpenHarmony.p12" -keystorePwd 123456 \
  -compatibleVersion 23 -outFile "$CONTAINER_SIGNED" -signCode 1
run_docker exec "$CONTAINER" test -s "$CONTAINER_SIGNED" || fail "Signing failed"
rm -f "$SIGNED_HAP"
run_docker cp "$CONTAINER:$CONTAINER_SIGNED" "$SIGNED_HAP"

log "6/7 Install"
aa force-stop "$BUNDLE_NAME" >/dev/null 2>&1 || true
bm uninstall -n "$BUNDLE_NAME" >/dev/null 2>&1 || true
bm install -p "$SIGNED_HAP"

log "7/7 Launch"
aa start -a "$ABILITY_NAME" -b "$BUNDLE_NAME"
sleep 2
ps -ef | grep "$BUNDLE_NAME" | grep -v grep || fail "Application did not start"
echo "Calculator HAP build completed: $SIGNED_HAP"
