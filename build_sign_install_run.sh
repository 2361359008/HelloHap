#!/bin/sh
# =============================================================================
# OpenHarmony 6.1 — 一键编译 + 签名 + 安装 + 启动 HAP
#
# 运行位置：板子宿主 shell（不是 Docker 容器内）
# 前提：Docker 容器 linux-env 已经启动，/data/local/bin/dockerc2可用
#
# 用法：
#   cd /data/local/tmp/oh61-hapbuild
#   sh build_sign_install_run.sh [--sign-only]
#
# =============================================================================
set -e

CONTAINER=${CONTAINER:-linux-env}
DOCKER_CLI=${DOCKER_CLI:-/data/local/bin/dockerc2}
REMOTE_DIR=${REMOTE_DIR:-/root/oh61-hapbuild}
OUT_HAP=${OUT_HAP:-/data/local/tmp/entry-signed.hap}
UNSIGNED_HAP=${UNSIGNED_HAP:-/data/local/tmp/entry-unsigned.hap}
BUNDLE_NAME=${BUNDLE_NAME:-com.openclaw.studenthap}
ABILITY_NAME=${ABILITY_NAME:-EntryAbility}

PKG_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_ARGS=""
HAS_DEVICE_ID=0
SIGN_ONLY=0

log() {
  echo ""
  echo "========== $* =========="
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for a in "$@"; do
  case "$a" in
    --sign-only)
      SIGN_ONLY=1
      ;;
    --device-id|--device-ids|--auto-device-id)
      HAS_DEVICE_ID=1
      INSTALL_ARGS="$INSTALL_ARGS $a"
      ;;
    *)
      INSTALL_ARGS="$INSTALL_ARGS $a"
      ;;
  esac
done

[ -x "$DOCKER_CLI" ] || fail "找不到 $DOCKER_CLI，请先部署 Docker"
[ -f "$PKG_DIR/install.sh" ] || fail "当前目录不是 oh61-hapbuild 包目录：$PKG_DIR"

if [ "$SIGN_ONLY" -eq 1 ]; then
  [ -s "$UNSIGNED_HAP" ] || fail "找不到待签名的未签名 HAP：$UNSIGNED_HAP，请先完成第一关编译"
  $DOCKER_CLI exec "$CONTAINER" test -f "/root/HAP-BuildKit/ohos_sdk/23/toolchains/lib/hap-sign-tool.jar" 2>/dev/null || \
    fail "容器内未找到 hap-sign-tool，请先确认 HAP-BuildKit SDK 已就绪"

  log "1/2 只执行 HAP 数字签名"

  $DOCKER_CLI exec "$CONTAINER" mkdir -p \
    /root/HAP-BuildKit/project/entry/build/default/outputs/default \
    /root/HAP-BuildKit/signing
  $DOCKER_CLI exec "$CONTAINER" rm -rf /root/HAP-BuildKit/signing
  $DOCKER_CLI cp "$PKG_DIR/signing" "$CONTAINER:/root/HAP-BuildKit/"
  $DOCKER_CLI cp "$UNSIGNED_HAP" "$CONTAINER:/root/HAP-BuildKit/project/entry/build/default/outputs/default/entry-default-unsigned.hap"

  echo "    [Sign] 正在使用已有未签名 HAP 执行签名..."
  $DOCKER_CLI exec "$CONTAINER" sh -c "
    set -e
    date -s '2026-06-03 12:00:00' >/dev/null 2>&1 || true

    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
    [ -d /usr/lib/jvm/java-17-openjdk ] && export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
    export PATH=\$JAVA_HOME/bin:\$PATH

    KIT=/root/HAP-BuildKit
    SDK=\$KIT/ohos_sdk/23
    SIGN=\$KIT/signing
    UNSIGNED=\$KIT/project/entry/build/default/outputs/default/entry-default-unsigned.hap
    SIGNED=\$KIT/project/entry/build/default/outputs/default/entry-default-signed.hap
    SIGN_TOOL=\$SDK/toolchains/lib/hap-sign-tool.jar
    PROFILE_CERT=\$SDK/toolchains/lib/OpenHarmonyProfileRelease.pem
    PROFILE_JSON=\$SIGN/HelloHap_debug_profile.json

    /root/miniconda3/bin/python3 -c \"
import json
p='\$PROFILE_JSON'
with open(p, encoding='utf-8-sig') as f: d=json.load(f)
d['validity']={'not-before':1704067200,'not-after':1924905600}
d['type']='release'
d['app-distribution-type']='os_integration'
d.pop('debug-info', None)
bi=d.get('bundle-info', {})
if 'development-certificate' in bi:
    bi['distribution-certificate']=bi.pop('development-certificate')
with open(p,'w',encoding='utf-8') as f: json.dump(d,f,indent=4)
\"

    java -jar \"\$SIGN_TOOL\" sign-profile \
      -mode localSign \
      -keyAlias \"openharmony application profile release\" \
      -keyPwd 123456 \
      -profileCertFile \"\$PROFILE_CERT\" \
      -inFile \"\$PROFILE_JSON\" \
      -signAlg SHA256withECDSA \
      -keystoreFile \"\$SIGN/OpenHarmony.p12\" \
      -keystorePwd 123456 \
      -outFile \"\$SIGN/debug.p7b\" 2>/dev/null

    java -jar \"\$SIGN_TOOL\" sign-app \
      -mode localSign \
      -keyAlias \"openharmony application release\" \
      -keyPwd 123456 \
      -appCertFile \"\$SIGN/OpenHarmonyAppChain.pem\" \
      -profileFile \"\$SIGN/debug.p7b\" \
      -inFile \"\$UNSIGNED\" \
      -signAlg SHA256withECDSA \
      -keystoreFile \"\$SIGN/OpenHarmony.p12\" \
      -keystorePwd 123456 \
      -compatibleVersion 23 \
      -outFile \"\$SIGNED\" \
      -signCode 1 2>/dev/null

    [ -s \"\$SIGNED\" ] || { echo \"ERROR: 签名产物未生成：\$SIGNED\" >&2; exit 1; }
    cp \"\$SIGNED\" \$KIT/entry-signed.hap
  "

  log "2/2 拷出 signed HAP 包产物"
  $DOCKER_CLI cp "$CONTAINER:/root/HAP-BuildKit/entry-signed.hap" "$OUT_HAP"
  ls -lh "$OUT_HAP"

  echo ""
  echo "数字签名成功完毕："
  echo "  Unsigned HAP: $UNSIGNED_HAP"
  echo "  Signed HAP:   $OUT_HAP"
  exit 0
fi

log "1/3 极速同步并编译、签名"
if $DOCKER_CLI exec "$CONTAINER" test -f "/root/HAP-BuildKit/ohos_sdk/23/toolchains/restool" 2>/dev/null; then
  echo "    [INFO] 检测到板载 SDK 已就绪，启用【极致直通编译模式】。"
  echo "           (零重叠多重拷贝开销，用 Python 进行内容比对同步，极限保护增量编译缓存)"

  # 1. 极速同步项目源码和签名到容器过渡目录 (仅同步 2MB 源码，不复制 500MB+ SDK 压缩包)
  $DOCKER_CLI exec "$CONTAINER" mkdir -p "$REMOTE_DIR"
  $DOCKER_CLI cp "$PKG_DIR/install.sh" "$CONTAINER:$REMOTE_DIR/"
  $DOCKER_CLI exec "$CONTAINER" rm -rf "$REMOTE_DIR/project" "$REMOTE_DIR/signing"
  $DOCKER_CLI cp "$PKG_DIR/project" "$CONTAINER:$REMOTE_DIR/"
  $DOCKER_CLI cp "$PKG_DIR/signing" "$CONTAINER:$REMOTE_DIR/"

  # 2. 容器内用 Python 进行智能增量同步，仅对真正修改过的文件执行 copy 并保持未改动文件的 mtime
  echo "    [Sync] 正在执行 Python 智能增量合并..."
  $DOCKER_CLI exec "$CONTAINER" sh -c "
    export PY_PKG=\"$REMOTE_DIR\"
    export PY_KIT=\"/root/HAP-BuildKit\"
    /root/miniconda3/bin/python3 -c \"
import os, shutil, filecmp
pkg, kit = os.environ['PY_PKG'], os.environ['PY_KIT']
def sync_dir(src, dst):
    if not os.path.exists(dst): os.makedirs(dst)
    for item in os.listdir(src):
        s = os.path.join(src, item)
        d = os.path.join(dst, item)
        if os.path.isdir(s):
            sync_dir(s, d)
        elif os.path.isfile(s):
            if not os.path.exists(d) or not filecmp.cmp(s, d, shallow=False):
                shutil.copy2(s, d)
                print('    [SYNC] 已更新: %s' % os.path.relpath(d, kit))

sync_dir(os.path.join(pkg, 'project/entry/src'), os.path.join(kit, 'project/entry/src'))
sync_dir(os.path.join(pkg, 'project/AppScope'), os.path.join(kit, 'project/AppScope'))
sync_dir(os.path.join(pkg, 'signing'), os.path.join(kit, 'signing'))
for f in ['build-profile.json5', 'hvigorfile.ts', 'oh-package.json5']:
    s, d = os.path.join(pkg, 'project', f), os.path.join(kit, 'project', f)
    if os.path.exists(s):
        if not os.path.exists(d) or not filecmp.cmp(s, d, shallow=False):
            shutil.copy2(s, d)
            print('    [SYNC] 已更新: %s' % f)
\"
  "

  # 2.5 动态剥离签名配置以执行无损 Hvigor 编译
  $DOCKER_CLI exec "$CONTAINER" sed -i 's/"signingConfig": "default"/\/\/ "signingConfig": "default"/' /root/HAP-BuildKit/project/build-profile.json5
  $DOCKER_CLI exec "$CONTAINER" rm -rf \
    /root/HAP-BuildKit/project/entry/build/default/intermediates/res \
    /root/HAP-BuildKit/project/entry/build/default/intermediates/process_profile \
    /root/HAP-BuildKit/project/entry/build/default/generated/r

  # 3. 容器内直接执行 Hvigor 增量编译
  echo "    [Hvigor] 正在执行增量编译..."
  $DOCKER_CLI exec "$CONTAINER" sh -c "
    export OHOS_SDK_HOME=/root/HAP-BuildKit/ohos_sdk
    cd /root/HAP-BuildKit/project
    node node_modules/@ohos/hvigor/bin/hvigor.js assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
  "

  # 4. 容器内直接执行 HAP 签名
  echo "    [Sign] 正在执行签名..."
  $DOCKER_CLI exec "$CONTAINER" sh -c "
    set -e
    date -s '2026-06-03 12:00:00' >/dev/null 2>&1 || true

    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
    [ -d /usr/lib/jvm/java-17-openjdk ] && export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
    export PATH=\$JAVA_HOME/bin:\$PATH

    KIT=/root/HAP-BuildKit
    SDK=\$KIT/ohos_sdk/23
    SIGN=\$KIT/signing
    UNSIGNED=\$KIT/project/entry/build/default/outputs/default/entry-default-unsigned.hap
    SIGNED=\$KIT/project/entry/build/default/outputs/default/entry-default-signed.hap
    SIGN_TOOL=\$SDK/toolchains/lib/hap-sign-tool.jar
    PROFILE_CERT=\$SDK/toolchains/lib/OpenHarmonyProfileRelease.pem
    PROFILE_JSON=\$SIGN/HelloHap_debug_profile.json

    /root/miniconda3/bin/python3 -c \"
import json
p='\$PROFILE_JSON'
with open(p, encoding='utf-8-sig') as f: d=json.load(f)
d['validity']={'not-before':1704067200,'not-after':1924905600}
d['type']='release'
d['app-distribution-type']='os_integration'
d.pop('debug-info', None)
bi=d.get('bundle-info', {})
if 'development-certificate' in bi:
    bi['distribution-certificate']=bi.pop('development-certificate')
with open(p,'w',encoding='utf-8') as f: json.dump(d,f,indent=4)
\"

    java -jar \"\$SIGN_TOOL\" sign-profile \
      -mode localSign \
      -keyAlias \"openharmony application profile release\" \
      -keyPwd 123456 \
      -profileCertFile \"\$PROFILE_CERT\" \
      -inFile \"\$PROFILE_JSON\" \
      -signAlg SHA256withECDSA \
      -keystoreFile \"\$SIGN/OpenHarmony.p12\" \
      -keystorePwd 123456 \
      -outFile \"\$SIGN/debug.p7b\" 2>/dev/null

    java -jar \"\$SIGN_TOOL\" sign-app \
      -mode localSign \
      -keyAlias \"openharmony application release\" \
      -keyPwd 123456 \
      -appCertFile \"\$SIGN/OpenHarmonyAppChain.pem\" \
      -profileFile \"\$SIGN/debug.p7b\" \
      -inFile \"\$UNSIGNED\" \
      -signAlg SHA256withECDSA \
      -keystoreFile \"\$SIGN/OpenHarmony.p12\" \
      -keystorePwd 123456 \
      -compatibleVersion 23 \
      -outFile \"\$SIGNED\" \
      -signCode 1 2>/dev/null

    [ -s \"\$SIGNED\" ] || { echo \"ERROR: 签名产物未生成：\$SIGNED\" >&2; exit 1; }
    cp \"\$SIGNED\" \$KIT/entry-signed.hap
  "
else
  echo "    [INFO] 首次完整同步目录并运行完整 install 脚本..."
  $DOCKER_CLI exec "$CONTAINER" rm -rf "$REMOTE_DIR"
  $DOCKER_CLI exec "$CONTAINER" mkdir -p "$REMOTE_DIR"
  $DOCKER_CLI cp "$PKG_DIR/." "$CONTAINER:$REMOTE_DIR/"
  $DOCKER_CLI exec "$CONTAINER" sh -c "cd $REMOTE_DIR && sh install.sh $INSTALL_ARGS"
fi

log "2/3 拷出 signed HAP 包产物"
$DOCKER_CLI cp "$CONTAINER:/root/HAP-BuildKit/entry-signed.hap" "$OUT_HAP"
ls -lh "$OUT_HAP"

# 🏁 Check if `--sign-only` is provided. If so, exit immediately and skip install/run!
if [ "$SIGN_ONLY" -eq 1 ]; then
  echo ""
  echo "数字签名成功完毕："
  echo "  Signed HAP: $OUT_HAP"
  exit 0
fi

log "3/3 拷贝安装并启动应用"
bm install -p "$OUT_HAP"
aa start -a "$ABILITY_NAME" -b "$BUNDLE_NAME"

echo ""
echo "全部完成："
echo "  HAP:    $OUT_HAP"
echo "  Bundle: $BUNDLE_NAME"
echo "  Ability:$ABILITY_NAME"
