#!/system/bin/sh
# Gateway supervisor: restarts the OpenClaw Gateway if it exits.
BIN_DIR=${0%/*}
. "$BIN_DIR/common.sh"

mkdir -p "$LOGS" "$RUN"
echo $$ > "$RUN/supervisor.pid"
trap 'exit 0' TERM INT HUP

backoff=5
while [ ! -f "$RUN/stop" ]; do
  ensure_config
  mounts_up
  log "gateway starting"
  chroot_cmd /usr/local/bin/openclaw gateway run --port "$PORT" >> "$LOGS/gateway.log" 2>&1
  rc=$?
  log "gateway exited rc=$rc"
  [ -f "$RUN/stop" ] && break
  sleep "$backoff"
  [ "$backoff" -lt 60 ] && backoff=$((backoff * 2))
done

rm -f "$RUN/supervisor.pid"
