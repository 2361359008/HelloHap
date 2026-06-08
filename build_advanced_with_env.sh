#!/system/bin/sh
# 高级版「自由开发」用：先确保板端 linux-env 容器就绪，再就地编译/签名/安装/启动 schedulehap-lite。
# 由 OpenClaw 还原 agent 在改完 Index.ets 后执行（见 FreeDevContent.ets 的还原提示词），
# 用来在板上直接看到还原后的真实效果，不需要再从 PC 跑 deploy_to_board.ps1。
#
# 之所以包一层：板端编译/签名跑在 Docker 容器 linux-env 里，容器若没起来，直接跑
# advanced_build_sign_install_run.sh 会报 "Cannot connect to the Docker daemon / linux-env 未运行"。
# 这里复用 shell-bridge 里已验证可用的 docker / dockerc2 调用先把容器拉起来。
set -eu

ROOT=/data/local/tmp/advanced-hapbuild
BUILD="$ROOT/advanced_build_sign_install_run.sh"
DOCKER=/data/local/bin/docker
DOCKERC2=/data/local/bin/dockerc2
DOCKER_SOCK=unix:///data/docker2/run/docker.sock

if [ ! -f "$BUILD" ]; then
  echo "error: missing build script: $BUILD"
  exit 1
fi

# 1) 等待 dockerd 就绪（最多 ~60s）
i=0
while ! "$DOCKER" -H "$DOCKER_SOCK" info >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then
    echo "error: dockerd not ready after ~60s"
    exit 1
  fi
  sleep 2
done

# 2) 确保 linux-env 容器在运行；没在运行就启动它
if "$DOCKERC2" ps --format '{{.Names}} {{.Status}}' | grep -q '^linux-env .*Up'; then
  echo "==> linux-env already running"
else
  echo "==> starting linux-env"
  "$DOCKERC2" start linux-env || true
  sleep 3
  if ! "$DOCKERC2" ps --format '{{.Names}} {{.Status}}' | grep -q '^linux-env .*Up'; then
    echo "error: failed to start linux-env container"
    exit 1
  fi
fi

# 3) 就地编译/签名/安装/启动
echo "==> running advanced build: $BUILD"
sh "$BUILD"
