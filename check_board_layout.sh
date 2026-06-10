#!/system/bin/sh
# check_board_layout.sh —— 换新板后核对 OpenClaw 导学 HAP 全部板端路径是否就位。
# 用法：把本脚本 push 到板子，hdc shell "sh /data/local/tmp/check_board_layout.sh"
# 输出 [OK]/[缺失]，并在末尾汇总缺失项与端口监听状态。

MISS=0
chk() {  # chk <类型 f|d> <路径> <说明>
  t="$1"; p="$2"; d="$3"
  if [ "$t" = d ]; then [ -d "$p" ]; else [ -e "$p" ]; fi
  if [ $? -eq 0 ]; then
    echo "[OK]   $p  ($d)"
  else
    echo "[缺失] $p  ($d)"
    MISS=$((MISS+1))
  fi
}

echo "===== 1. 服务 / 运行时 / 配置 ====="
chk f /data/local/tmp/node                 "Node 运行时"
chk f /data/local/tmp/openclaw/openclaw.mjs "OpenClaw 网关"
chk f /data/local/tmp/shell-bridge.js       "Shell-Bridge"
chk f /data/local/tmp/https-proxy.js        "HTTPS 反代(可选)"
chk f /data/local/tmp/proxy-cert.pem        "代理证书"
chk f /data/local/tmp/proxy-key.pem         "代理私钥"
chk f /data/local/tmp/.openclaw/openclaw.json "网关配置(token)"
chk f /data/local/tmp/bin/openclaw-boot.sh  "开机脚本"
chk f /system/etc/init/openclaw.cfg         "init 自启配置"

echo
echo "===== 2. 主 HAP + 课程/高级 工程 ====="
chk f /data/local/tmp/entry-signed.hap                                   "主HAP签名包(learnhap)"
chk d /data/local/tmp/oh61-hapbuild/project                              "主课程工程"
chk f /data/local/tmp/oh61-hapbuild/restore_course_project.sh            "主课程还原脚本"
chk f /data/local/tmp/oh61-hapbuild/backups/course-initial/project.tar   "主课程基线"
chk d /data/local/tmp/advanced-hapbuild/project                          "高级工程"
chk f /data/local/tmp/advanced-hapbuild/restore_advanced_project.sh      "高级还原脚本"
chk f /data/local/tmp/advanced-hapbuild/backups/course-initial/project.tar "高级基线"
chk f /data/local/tmp/advanced-hapbuild/install_initial_advanced.sh      "高级安装脚本"
chk f /data/local/tmp/advanced-hapbuild/install_initial_teaching.sh      "教学启动脚本"
chk f /data/local/tmp/advanced-hapbuild/schedule-initial-signed.hap      "schedulehap.lite 包"

echo
echo "===== 3. 五个功能 HAP（initial 基线）====="
for x in minesweeper calculator tetris videoplayer blank; do
  chk d /data/local/tmp/$x-hapbuild/project                        "$x 工程"
  chk f /data/local/tmp/$x-hapbuild/restore_${x}_project.sh        "$x 还原脚本"
  chk f /data/local/tmp/$x-hapbuild/install_initial_$x.sh          "$x 安装脚本"
  chk f /data/local/tmp/$x-hapbuild/$x-signed.hap                  "$x 签名包"
  chk f /data/local/tmp/$x-hapbuild/backups/initial/project.tar    "$x 基线"
done

echo
echo "===== 4. 随心(blank) 额外 ====="
chk d /data/local/tmp/blank-hapbuild/projects   "随心副本目录"
chk d /data/local/tmp/blank-hapbuild/template   "随心模板"
for s in blank_new blank_select blank_delete blank_clear_all; do
  chk f /data/local/tmp/blank-hapbuild/$s.sh    "随心脚本 $s"
done

echo
echo "===== 5. 构建链 / 签名 ====="
chk f /data/local/tmp/assemble_deploy.sh        "万能构建脚本"
chk f /data/local/bin/dockerc2                  "Docker 客户端"
chk d /data/local/tmp/signature                 "签名材料目录"
chk f /data/local/tmp/signature/HelloHap_debug_profile.json "签名 profile"
chk f /data/local/tmp/signature/OpenHarmony.p12            "签名密钥库"
chk f /data/local/tmp/signature/OpenHarmonyAppChain.pem    "签名证书链"

echo
echo "===== 6. AI 人格 / 记忆 ====="
chk d /data/local/tmp/.openclaw/workspace/memory       "记忆目录"
chk d /data/local/tmp/.openclaw/agents                 "agents 会话目录"

echo
echo "===== 7. 端口监听 ====="
for port in 7681 18800; do
  if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
    echo "[OK]   :$port 监听中"
  else
    echo "[未起] :$port 未监听"
    MISS=$((MISS+1))
  fi
done

echo
if [ "$MISS" -eq 0 ]; then
  echo "===== 全部就位，无缺失 ====="
else
  echo "===== 共 $MISS 项缺失/未起，请按上面 [缺失]/[未起] 补齐 ====="
fi
