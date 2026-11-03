#!/system/bin/sh
# Module "Action" button: start the Gateway and try to open the Control UI.
SELF=$0
MODDIR=${SELF%/*}
[ "$MODDIR" = "$SELF" ] && MODDIR=.
[ -f "$MODDIR/bin/common.sh" ] || MODDIR=/data/adb/modules/openclaw-pocket
. "$MODDIR/bin/common.sh"

echo "- OpenClaw Pocket: starting Gateway"
"$MODDIR/bin/start.sh" >/dev/null 2>&1

echo "- Waiting for http://127.0.0.1:$PORT/"
ready=0
i=0
if command -v curl >/dev/null 2>&1; then
  while [ "$i" -lt 45 ]; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$PORT/" 2>/dev/null)
    if [ "$code" = "200" ]; then
      ready=1
      break
    fi
    sleep 1
    i=$((i + 1))
  done
else
  sleep 25
fi

ensure_config
publish_token
URL="http://127.0.0.1:$PORT/#token=$(cat "$TOKEN_FILE" 2>/dev/null)"
if [ "$ready" = "1" ]; then
  echo "- Gateway is ready"
else
  echo "- Gateway is still starting; opening the panel anyway"
fi
echo "- Panel: $URL"

if [ -x /system/bin/am ]; then
  /system/bin/am start -a android.intent.action.VIEW -d "$URL" >/dev/null 2>&1 || \
    /system/bin/cmd activity start-activity -a android.intent.action.VIEW -d "$URL" >/dev/null 2>&1 || true
fi
