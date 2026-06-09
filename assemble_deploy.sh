#!/system/bin/sh
#
# 多元开发·万能「编译 → 签名 → 安装 → 启动」脚本。
# 任意一个自由开发工程，改完代码后跑这一条就能出包并装到板上看效果：
#
#     sh /data/local/tmp/assemble_deploy.sh <工程目录> [输出签名HAP路径]
#
# 例：
#     sh /data/local/tmp/assemble_deploy.sh /data/local/tmp/calculator-hapbuild/project
#     sh /data/local/tmp/assemble_deploy.sh /data/local/tmp/blank-hapbuild/projects/my-app
#
# 与各工程的 build_*.sh 同一套 Docker(linux-env) 编译 + hap-sign-tool 签名流程，
# 只是把「包名 / 容器目录 / 产物名」都改成自动从工程的 AppScope/app.json5 推导，
# 因此一个脚本通吃所有工程（含随心的多个副本工程）。
set -eu

PROJECT_DIR="${1:-}"
[ -n "$PROJECT_DIR" ] || { echo "用法: $0 <工程目录> [输出签名HAP路径]" >&2; exit 2; }
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || { echo "ERROR: 工程目录不存在: $1" >&2; exit 2; }

CONTAINER="${CONTAINER:-linux-env}"
DOCKER_CLI="${DOCKER_CLI:-/data/local/bin/dockerc2}"
SDK_ROOT="/root/HAP-BuildKit/ohos_sdk/23"
SIGN_TOOL="$SDK_ROOT/toolchains/lib/hap-sign-tool.jar"
PROFILE_CERT="$SDK_ROOT/toolchains/lib/OpenHarmonyProfileRelease.pem"

log()  { echo ""; echo "========== $* =========="; }
fail() { echo ""; echo "ERROR: $*" >&2; exit 1; }
run_docker() { "$DOCKER_CLI" "$@"; }

log "0/7 检查构建环境与工程"
[ -x "$DOCKER_CLI" ] || fail "Docker 客户端不存在: $DOCKER_CLI"
[ -f "$PROJECT_DIR/AppScope/app.json5" ] || fail "缺少 AppScope/app.json5: $PROJECT_DIR"
[ -f "$PROJECT_DIR/entry/src/main/ets/pages/Index.ets" ] || fail "缺少 entry/src/main/ets/pages/Index.ets"

# 从 AppScope/app.json5 自动读取包名（自由开发只改 Index.ets，不应手填包名）。
BUNDLE_NAME="$(grep -oE '"bundleName"[[:space:]]*:[[:space:]]*"[^"]+"' "$PROJECT_DIR/AppScope/app.json5" | head -1 | sed -E 's/.*:[[:space:]]*"([^"]+)".*/\1/')"
[ -n "$BUNDLE_NAME" ] || fail "无法从 AppScope/app.json5 读取 bundleName"
SLUG="${BUNDLE_NAME##*.}"               # 例: com.openclaw.calculator -> calculator
ABILITY_NAME="${ABILITY_NAME:-EntryAbility}"

# 输出 HAP：默认放在工程目录的上级，名字 <slug>-signed.hap。
OUT_DIR="${OUT_DIR:-$(dirname "$PROJECT_DIR")}"
SIGNED_HAP="${2:-$OUT_DIR/$SLUG-signed.hap}"
UNSIGNED_HAP="$OUT_DIR/$SLUG-unsigned.hap"

# 签名材料目录：可用 SIGNING_DIR 覆盖，否则按常见位置依次查找。
locate_signing_dir() {
  for d in "${SIGNING_DIR:-}" \
           "$PROJECT_DIR/signature" \
           "$PROJECT_DIR/../signature" \
           "$PROJECT_DIR/../../signature" \
           "/data/local/tmp/signature"; do
    [ -n "$d" ] || continue
    if [ -f "$d/HelloHap_debug_profile.json" ] && [ -f "$d/OpenHarmony.p12" ] && [ -f "$d/OpenHarmonyAppChain.pem" ]; then
      ( cd "$d" && pwd ); return 0
    fi
  done
  return 1
}
SIGNING_DIR="$(locate_signing_dir)" || fail "找不到签名材料目录（需含 HelloHap_debug_profile.json / OpenHarmony.p12 / OpenHarmonyAppChain.pem）。可用 SIGNING_DIR=... 指定。"

PROFILE_JSON="$SIGNING_DIR/HelloHap_debug_profile.json"
KEYSTORE="$SIGNING_DIR/OpenHarmony.p12"
APP_CERT="$SIGNING_DIR/OpenHarmonyAppChain.pem"

CONTAINER_PROJECT="/root/HAP-BuildKit/_$SLUG-project"
CONTAINER_SIGNING="/root/HAP-BuildKit/_$SLUG-signing"
CONTAINER_UNSIGNED="$CONTAINER_PROJECT/entry/build/default/outputs/default/entry-default-unsigned.hap"
CONTAINER_SIGNED="$CONTAINER_PROJECT/entry/build/default/outputs/default/$SLUG-signed.hap"

run_docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$" || fail "Docker 容器 $CONTAINER 未运行"
run_docker exec "$CONTAINER" test -f "$SIGN_TOOL" || fail "容器内缺少签名工具: $SIGN_TOOL"

if run_docker exec "$CONTAINER" test -x /root/miniconda3/bin/python3; then
  CONTAINER_PYTHON="/root/miniconda3/bin/python3"
elif run_docker exec "$CONTAINER" test -x /usr/bin/python3; then
  CONTAINER_PYTHON="/usr/bin/python3"
else
  CONTAINER_PYTHON="$(run_docker exec "$CONTAINER" which python3 2>/dev/null || true)"
fi
[ -n "$CONTAINER_PYTHON" ] || fail "容器内没有 Python 3"

echo "工程:   $PROJECT_DIR"
echo "包名:   $BUNDLE_NAME"
echo "产物:   $SIGNED_HAP"
echo "签名:   $SIGNING_DIR"

log "1/7 同步工程到 Docker"
if ! run_docker exec "$CONTAINER" test -d "$CONTAINER_PROJECT/node_modules"; then
  echo "首次构建: 基于基线工程创建依赖缓存"
  run_docker exec "$CONTAINER" rm -rf "$CONTAINER_PROJECT"
  run_docker exec "$CONTAINER" cp -a /root/HAP-BuildKit/project "$CONTAINER_PROJECT"
fi
run_docker cp "$PROJECT_DIR/." "$CONTAINER:$CONTAINER_PROJECT/"
run_docker exec "$CONTAINER" grep -q "\"bundleName\"[[:space:]]*:[[:space:]]*\"$BUNDLE_NAME\"" \
  "$CONTAINER_PROJECT/AppScope/app.json5" || fail "容器内 bundleName 与 $BUNDLE_NAME 不一致"

log "2/7 编译 HAP"
run_docker exec "$CONTAINER" rm -rf "$CONTAINER_PROJECT/entry/build"
run_docker exec \
  -e OHOS_SDK_HOME=/root/HAP-BuildKit/ohos_sdk \
  -w "$CONTAINER_PROJECT" \
  "$CONTAINER" \
  node node_modules/@ohos/hvigor/bin/hvigor.js \
  assembleHap --mode module -p product=default -p buildMode=debug --no-daemon

run_docker exec "$CONTAINER" test -s "$CONTAINER_UNSIGNED" || fail "编译失败（无 unsigned hap）"
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
  -outFile "$CONTAINER_SIGNING/$SLUG-profile.p7b"

log "5/7 签 HAP"
run_docker exec "$CONTAINER" rm -f "$CONTAINER_SIGNED"
run_docker exec "$CONTAINER" \
  java -jar "$SIGN_TOOL" sign-app \
  -mode localSign \
  -keyAlias "openharmony application release" \
  -keyPwd 123456 \
  -appCertFile "$CONTAINER_SIGNING/OpenHarmonyAppChain.pem" \
  -profileFile "$CONTAINER_SIGNING/$SLUG-profile.p7b" \
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
echo "构建完成并已上板！"
echo "Bundle:  $BUNDLE_NAME"
echo "Signed:  $SIGNED_HAP"
echo "============================================="
