#!/system/bin/sh
# Stop the OpenClaw Gateway and its supervisor.
BIN_DIR=${0%/*}
. "$BIN_DIR/common.sh"

mkdir -p "$RUN"
touch "$RUN/stop"

if [ -f "$RUN/supervisor.pid" ]; then
  kill "$(cat "$RUN/supervisor.pid" 2>/dev/null)" 2>/dev/null
fi

for p in $(gateway_pids); do
  kill -TERM "$p" 2>/dev/null
done
sleep 3
for p in $(gateway_pids); do
  kill -KILL "$p" 2>/dev/null
done

rm -f "$RUN/stop" "$RUN/supervisor.pid"
log "gateway stopped"
