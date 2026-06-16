#!/system/bin/sh
LOG_DIR=${LOG_DIR:-/data/local/tmp/.openclaw}
LOG_FILE=${LOG_FILE:-$LOG_DIR/ensure-board-ready.log}
DOCKER=${DOCKER:-/data/local/bin/docker}
DOCKERC=${DOCKERC:-/data/local/bin/dockerc2}
DOCKER_SOCK=${DOCKER_SOCK:-/data/docker2/run/docker.sock}
CONTAINER=${CONTAINER:-linux-env}
HDC_DIR=${HDC_DIR:-/root/oh51-hdc-arm64}
HDC_HOST=${HDC_HOST:-192.168.2.15}
SELF=${ENSURE_BOARD_READY_PATH:-/data/local/tmp/ensure_board_ready.sh}
HAP_BUNDLE=${HAP_BUNDLE:-com.openclaw.learnhap}
HAP_ABILITY=${HAP_ABILITY:-EntryAbility}
MODE=${1:-}

mkdir -p "$LOG_DIR"
if [ "$MODE" != "--inside-hdc-shell" ]; then
    : > "$LOG_FILE"
fi

exec 3>&1
exec >> "$LOG_FILE" 2>&1

echo "=================================================="
echo "$(date) ensure_board_ready start mode=${MODE:-outer}"

port_listening() {
    netstat -tln 2>/dev/null | grep -q ":$1 "
}

wait_host_port() {
    PORT=$1
    NAME=$2
    TIMEOUT=$3
    i=0
    while [ "$i" -lt "$TIMEOUT" ]; do
        if port_listening "$PORT"; then
            echo "[OK] $NAME listening on :$PORT"
            return 0
        fi
        i=$((i + 1))
        sleep 1
    done
    echo "[ERROR] $NAME did not listen on :$PORT within ${TIMEOUT}s"
    return 1
}

docker_ready() {
    [ -S "$DOCKER_SOCK" ] && DOCKER_HOST=unix://$DOCKER_SOCK "$DOCKER" info >/dev/null 2>&1
}

ensure_docker_and_container() {
    if docker_ready; then
        echo "[OK] Docker daemon is ready"
    else
        echo "[START] Docker daemon and linux-env stack"
        sh /data/local/tmp/houmo-stack-boot.sh || true
    fi

    if ! docker_ready; then
        echo "[ERROR] Docker daemon is unavailable"
        return 1
    fi

    STATE=$("$DOCKERC" inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null)
    if [ "$STATE" != "running" ]; then
        echo "[START] container $CONTAINER (state=${STATE:-missing})"
        "$DOCKERC" start "$CONTAINER" || true
        sleep 3
    fi

    STATE=$("$DOCKERC" inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null)
    if [ "$STATE" != "running" ]; then
        echo "[ERROR] container $CONTAINER is not running (state=${STATE:-missing})"
        return 1
    fi

    echo "[OK] container $CONTAINER is running"
    if "$DOCKERC" exec "$CONTAINER" test -d /root/HAP-BuildKit/project; then
        echo "[OK] HAP-BuildKit project is available"
    else
        echo "[ERROR] /root/HAP-BuildKit/project is missing"
        return 1
    fi

    if "$DOCKERC" exec "$CONTAINER" test -x "$HDC_DIR/hdc"; then
        echo "[OK] container hdc is available at $HDC_DIR/hdc"
    else
        echo "[ERROR] container hdc is missing at $HDC_DIR/hdc"
        return 1
    fi

    return 0
}

run_via_container_hdc_shell() {
    echo "[START] hdc shell via $CONTAINER -> $HDC_HOST:5555"
    HDC_CMD="
cd '$HDC_DIR' || exit 1
export LD_LIBRARY_PATH=\$PWD
./hdc -v
./hdc tconn '$HDC_HOST:5555' || echo '[WARN] hdc tconn failed, trying existing hdc session'
./hdc shell \"chmod 755 '$SELF' && /system/bin/sh '$SELF' --inside-hdc-shell\"
"
    "$DOCKERC" exec "$CONTAINER" /bin/sh -c "$HDC_CMD"
}

run_inside_hdc_shell() {
    FAILURES=0

    setenforce 0 >/dev/null 2>&1 || true

    echo "[START] OpenClaw shell-bridge and gateway"
    /system/bin/openclaw-ctl start || true
    wait_host_port 7681 "shell-bridge" 20 || FAILURES=$((FAILURES + 1))
    wait_host_port 18800 "OpenClaw gateway" 30 || FAILURES=$((FAILURES + 1))

    if bm dump -n "$HAP_BUNDLE" >/dev/null 2>&1; then
        echo "[START] HAP $HAP_BUNDLE/$HAP_ABILITY"
        aa start -a "$HAP_ABILITY" -b "$HAP_BUNDLE" >/dev/null 2>&1 || \
            echo "[WARN] HAP is installed but could not be brought to foreground"
        sleep 1
        if ps -ef | grep "$HAP_BUNDLE" | grep -v grep >/dev/null 2>&1; then
            echo "[OK] HAP process $HAP_BUNDLE is running"
        else
            echo "[ERROR] HAP process $HAP_BUNDLE is not running"
            FAILURES=$((FAILURES + 1))
        fi
    else
        echo "[ERROR] HAP $HAP_BUNDLE is not installed"
        FAILURES=$((FAILURES + 1))
    fi

    echo "--- final status ---"
    echo "container=$("$DOCKERC" inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null)"
    echo "shell-bridge=:7681"
    echo "openclaw-gateway=:18800"
    echo "hap=$HAP_BUNDLE"
    echo "$(date) ensure_board_ready done mode=inside-hdc-shell failures=$FAILURES"

    tail -n 120 "$LOG_FILE" >&3
    [ "$FAILURES" -eq 0 ]
}

if [ "$MODE" = "--inside-hdc-shell" ]; then
    run_inside_hdc_shell
    exit $?
fi

FAILURES=0
ensure_docker_and_container || FAILURES=$((FAILURES + 1))
if [ "$FAILURES" -eq 0 ]; then
    run_via_container_hdc_shell || FAILURES=$((FAILURES + 1))
fi

echo "--- outer final status ---"
echo "container=$("$DOCKERC" inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null)"
echo "hdc_host=$HDC_HOST:5555"
echo "$(date) ensure_board_ready done mode=outer failures=$FAILURES"

tail -n 160 "$LOG_FILE" >&3
[ "$FAILURES" -eq 0 ]
