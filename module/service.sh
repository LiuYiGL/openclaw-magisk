#!/system/bin/sh
# Magisk late_start service: start the Gateway (or provision on first boot).
MODDIR=${0%/*}
. "$MODDIR/bin/common.sh"

mkdir -p "$LOGS" "$RUN" "$HOME_DIR"

if [ ! -f "$ROOTFS/.provisioned" ]; then
  log "OpenClaw runtime missing; provisioning in the background"
  setsid "$MODDIR/bin/provision.sh" >> "$LOGS/provision.log" 2>&1 < /dev/null &
  exit 0
fi

"$MODDIR/bin/start.sh"
