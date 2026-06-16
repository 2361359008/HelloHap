#!/system/bin/sh
# Restore and verify services required by the HelloHap teaching HAP.
# Outer mode starts Docker/container first. Then it uses the hdc bundled inside
# linux-env to re-enter this board through hdc shell, so bm/aa/openclaw run from
# a real hdc shell context.

LOG_DIR=${LOG_DIR:-/data/local/tmp/.openclaw}
LOG_FILE=${LOG_FILE:-$LOG_DIR/ensure-board-ready.log}
DOCKER=${DOCKER:-/data/local/bin/docker}
DOCKERC=${DOCKERC:-/data/local/bin/dockerc2}
DOCKER_SOCK=${DOCKER_SOCK:-/data/docker2/run/docker.sock}
CONTAINER=${CONTAINER:-linux-env}
HDC_DIR=${HDC_DIR:-/root/oh51-hdc-arm64}
HDC_HOST_FILE=${HDC_HOST_FILE:-$LOG_DIR/hdc-host}
HDC_FALLBACK_HOST=${HDC_FALLBACK_HOST:-192.168.2.15}
SELF=${ENSURE_BOARD_READY_PATH:-/data/local/tmp/ensure_board_ready.sh}
HAP_BUNDLE=${HAP_BUNDLE:-com.openclaw.learnhap}
HAP_ABILITY=${HAP_ABILITY:-EntryAbility}
MODE=${1:-}

if [ -z "$OPENCLAW_CTL" ]; then
    if [ -x /data/local/tmp/bin/openclaw-ctl ]; then
        OPENCLAW_CTL=/data/local/tmp/bin/openclaw-ctl
    else
        OPENCLAW_CTL=/system/bin/openclaw-ctl
    fi
fi

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

hap_running() {
    ps -ef | grep "$HAP_BUNDLE" | grep -v grep >/dev/null 2>&1
}

start_hap_with_retry() {
    TRIES=${1:-15}
    i=1
    while [ "$i" -le "$TRIES" ]; do
        echo "[START] HAP $HAP_BUNDLE/$HAP_ABILITY attempt $i/$TRIES"
        aa start -a "$HAP_ABILITY" -b "$HAP_BUNDLE" >/dev/null 2>&1 || true
        sleep 2
        if hap_running; then
            echo "[OK] HAP process $HAP_BUNDLE is running"
            return 0
        fi
        i=$((i + 1))
    done
    echo "[ERROR] HAP process $HAP_BUNDLE is not running"
    return 1
}

add_hdc_candidate() {
    HOST=$1
    [ -n "$HOST" ] || return 0
    case "$HOST" in
        127.*|169.254.*|0.0.0.0) return 0 ;;
    esac
    case " $HDC_CANDIDATES " in
        *" $HOST "*) return 0 ;;
    esac
    HDC_CANDIDATES="${HDC_CANDIDATES:+$HDC_CANDIDATES }$HOST"
}

discover_ifconfig_hosts() {
    IFACE=""
    ifconfig 2>/dev/null | while IFS= read -r LINE; do
        case "$LINE" in
            ""|" "*)
                ;;
            *)
                IFACE=${LINE%% *}
                IFACE=${IFACE%:}
                ;;
        esac

        case "$LINE" in
            *"inet addr:"*)
                HOST=${LINE#*inet addr:}
                HOST=${HOST%%[	 ]*}
                ;;
            *" inet "*)
                set -- $LINE
                HOST=""
                while [ "$#" -gt 0 ]; do
                    if [ "$1" = "inet" ]; then
                        shift
                        HOST=$1
                        break
                    fi
                    shift
                done
                ;;
            *)
                HOST=""
                ;;
        esac

        [ -n "$HOST" ] || continue
        case "$IFACE" in
            lo|docker*|br-*|veth*|virbr*) continue ;;
        esac
        case "$HOST" in
            127.*|169.254.*|0.0.0.0|172.16.*|172.17.*|172.18.*|172.19.*|172.20.*|172.21.*|172.22.*|172.23.*|172.24.*|172.25.*|172.26.*|172.27.*|172.28.*|172.29.*|172.30.*|172.31.*) continue ;;
        esac
        echo "$HOST"
    done
}

discover_hdc_candidates() {
    HDC_CANDIDATES=""

    add_hdc_candidate "$HDC_HOST"

    if [ -f "$HDC_HOST_FILE" ]; then
        read HDC_HOST_FROM_FILE < "$HDC_HOST_FILE"
        add_hdc_candidate "$HDC_HOST_FROM_FILE"
    fi

    for HOST in $(discover_ifconfig_hosts); do
        add_hdc_candidate "$HOST"
    done

    add_hdc_candidate "$HDC_FALLBACK_HOST"

    echo "$HDC_CANDIDATES"
}

wait_docker_ready() {
    TIMEOUT=${1:-20}
    i=0
    while [ "$i" -lt "$TIMEOUT" ]; do
        if docker_ready; then
            echo "[OK] Docker daemon is ready"
            return 0
        fi
        i=$((i + 1))
        sleep 1
    done
    echo "[ERROR] Docker daemon is unavailable after ${TIMEOUT}s"
    return 1
}

start_container_once() {
    START_LOG="$LOG_DIR/${CONTAINER}-start.log"
    rm -f "$START_LOG"
    "$DOCKERC" start "$CONTAINER" > "$START_LOG" 2>&1
    START_RC=$?
    cat "$START_LOG"
    return "$START_RC"
}

repair_runc_container_id_exists() {
    START_LOG="$LOG_DIR/${CONTAINER}-start.log"
    if ! grep -q "container with given ID already exists" "$START_LOG" 2>/dev/null; then
        return 1
    fi

    CID=$("$DOCKERC" inspect "$CONTAINER" --format '{{.Id}}' 2>/dev/null)
    if [ -z "$CID" ]; then
        echo "[ERROR] cannot inspect container id for $CONTAINER"
        return 1
    fi

    RUNC_ROOT=/data/docker2/exec/runtime-runc/moby
    RUNTIME_DIR="$RUNC_ROOT/$CID"
    TS=$(date +%s 2>/dev/null || echo unknown)
    BACKUP_DIR="$RUNTIME_DIR.bak.$TS"

    echo "[REPAIR] runc stale container id exists for $CONTAINER: $CID"
    pkill -9 -f containerd-shim 2>/dev/null || true
    pkill -9 -f runc 2>/dev/null || true
    pkill -9 -f dockerd 2>/dev/null || true
    pkill -9 -f containerd 2>/dev/null || true
    sleep 3

    if [ -d "$RUNTIME_DIR" ]; then
        echo "[REPAIR] move stale runtime dir $RUNTIME_DIR -> $BACKUP_DIR"
        mv "$RUNTIME_DIR" "$BACKUP_DIR" || return 1
    else
        echo "[REPAIR] stale runtime dir not found: $RUNTIME_DIR"
    fi

    echo "[REPAIR] restart Docker daemon and linux-env stack"
    sh /data/local/tmp/houmo-stack-boot.sh || true
    wait_docker_ready 30
}
ensure_docker_and_container() {
    if docker_ready; then
        echo "[OK] Docker daemon is ready"
    else
        echo "[START] Docker daemon and linux-env stack"
        sh /data/local/tmp/houmo-stack-boot.sh || true
    fi

    if ! wait_docker_ready 20; then
        return 1
    fi

    STATE=$("$DOCKERC" inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null)
    if [ "$STATE" != "running" ]; then
        echo "[START] container $CONTAINER (state=${STATE:-missing})"
        if ! start_container_once; then
            repair_runc_container_id_exists || true
            echo "[RETRY] container $CONTAINER after runc repair"
            start_container_once || true
        fi
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
    HDC_CANDIDATES=$(discover_hdc_candidates)
    echo "[START] hdc shell via $CONTAINER, candidates: $HDC_CANDIDATES"
    HDC_CMD="
cd '$HDC_DIR' || exit 1
export LD_LIBRARY_PATH=\$PWD
./hdc -v
CONNECTED=''
for HOST in $HDC_CANDIDATES; do
    echo \"[TRY] hdc tconn \${HOST}:5555\"
    ./hdc tconn \"\${HOST}:5555\" >/tmp/hellohap-hdc-tconn.log 2>&1 || true
    cat /tmp/hellohap-hdc-tconn.log
    if ./hdc shell \"echo hdc-shell-ready\" 2>/dev/null | grep -q hdc-shell-ready; then
        CONNECTED=\$HOST
        break
    fi
done
if [ -z \"\$CONNECTED\" ]; then
    echo '[ERROR] no hdc target reachable'
    exit 1
fi
echo \"[OK] hdc shell connected via \${CONNECTED}:5555\"
./hdc shell \"chmod 755 '$SELF' && /system/bin/sh '$SELF' --inside-hdc-shell\"
"
    "$DOCKERC" exec "$CONTAINER" /bin/sh -c "$HDC_CMD"
}

run_inside_hdc_shell() {
    FAILURES=0

    setenforce 0 >/dev/null 2>&1 || true

    echo "[START] OpenClaw shell-bridge and gateway"
    if [ -x "$OPENCLAW_CTL" ]; then
        "$OPENCLAW_CTL" start || true
    else
        echo "[ERROR] openclaw-ctl is missing or not executable: $OPENCLAW_CTL"
        FAILURES=$((FAILURES + 1))
    fi
    wait_host_port 7681 "shell-bridge" 30 || FAILURES=$((FAILURES + 1))
    wait_host_port 18800 "OpenClaw gateway" 45 || FAILURES=$((FAILURES + 1))

    if bm dump -n "$HAP_BUNDLE" >/dev/null 2>&1; then
        start_hap_with_retry 15 || FAILURES=$((FAILURES + 1))
    else
        echo "[ERROR] HAP $HAP_BUNDLE is not installed"
        FAILURES=$((FAILURES + 1))
    fi

    echo "--- final status ---"
    echo "container=$("$DOCKERC" inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null)"
    echo "openclaw_ctl=$OPENCLAW_CTL"
    echo "shell-bridge=:7681"
    echo "openclaw-gateway=:18800"
    echo "hap=$HAP_BUNDLE"
    echo "$(date) ensure_board_ready done mode=inside-hdc-shell failures=$FAILURES"

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
echo "hdc_candidates=$(discover_hdc_candidates)"
echo "openclaw_ctl=$OPENCLAW_CTL"
echo "$(date) ensure_board_ready done mode=outer failures=$FAILURES"

tail -n 160 "$LOG_FILE" >&3
[ "$FAILURES" -eq 0 ]
