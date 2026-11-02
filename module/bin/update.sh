#!/system/bin/sh
# Update the OpenClaw npm package in place and restart the Gateway.
BIN_DIR=${0%/*}
. "$BIN_DIR/common.sh"

mkdir -p "$LOGS"
log "updating OpenClaw"
"$BIN_DIR/stop.sh"

chroot_cmd /usr/local/bin/npm install -g openclaw@latest \
  --allow-scripts=openclaw --no-fund --no-audit >> "$LOGS/update.log" 2>&1 || {
    log "official registry failed, retrying with npmmirror"
    chroot_cmd /usr/local/bin/npm install -g openclaw@latest \
      --allow-scripts=openclaw --no-fund --no-audit \
      --registry=https://registry.npmmirror.com >> "$LOGS/update.log" 2>&1 || {
        log "update failed, see $LOGS/update.log"
        "$BIN_DIR/start.sh"
        exit 1
      }
  }

"$BIN_DIR/patch-openclaw.sh"
"$BIN_DIR/start.sh"
log "update complete"
