#!/system/bin/sh
# Start the OpenClaw Gateway supervisor (idempotent).
BIN_DIR=${0%/*}
. "$BIN_DIR/common.sh"

mkdir -p "$LOGS" "$RUN" "$HOME_DIR"

if [ ! -f "$ROOTFS/.provisioned" ]; then
  log "OpenClaw runtime is not provisioned yet; run: openclawctl provision"
  exit 1
fi

cur=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ROOTFS/usr/local/lib/node_modules/openclaw/package.json" 2>/dev/null | head -1)
if [ -n "$cur" ] && [ "$cur" != "$(cat "$BASE/.patched-version" 2>/dev/null)" ]; then
  "$BIN_DIR/patch-openclaw.sh"
fi

mounts_up
ensure_config
publish_token
rm -f "$RUN/stop"

if is_running; then
  log "gateway already running"
  exit 0
fi

setsid "$BIN_DIR/supervise.sh" >> "$LOGS/gateway.log" 2>&1 < /dev/null &
sleep 1
log "gateway launch requested on port $PORT"
