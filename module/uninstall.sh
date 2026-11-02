#!/system/bin/sh
# Remove the OpenClaw runtime, config, logs and token on module uninstall.
MODDIR=${0%/*}
. "$MODDIR/bin/common.sh"

"$MODDIR/bin/stop.sh" 2>/dev/null
for p in $(gateway_pids); do
  kill -KILL "$p" 2>/dev/null
done
mounts_down

rm -rf "$BASE"
rm -f /sdcard/Download/openclaw-token.txt /data/media/0/Download/openclaw-token.txt

exit 0
