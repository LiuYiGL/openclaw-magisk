#!/system/bin/sh
# Magisk install-time script.
SKIPUNZIP=0

ui_print "- OpenClaw Gateway for Android (arm64)"
ui_print "- Runtime and data live in /data/openclaw"

abi=$(getprop ro.product.cpu.abi)
if [ "$abi" != "arm64-v8a" ]; then
  abort "! Unsupported ABI: $abi. This module requires arm64-v8a."
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/customize.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm "$MODPATH/bin/busybox" 0 0 0755

BB="$MODPATH/bin/busybox"
chmod 0755 "$BB" 2>/dev/null
if [ ! -x "$BB" ]; then
  for p in /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/magisk/busybox; do
    [ -x "$p" ] && { BB="$p"; break; }
  done
fi
if [ ! -x "$BB" ]; then
  BB=$(command -v busybox 2>/dev/null)
fi

mkdir -p /data/openclaw/home /data/openclaw/logs /data/openclaw/run /data/openclaw/cache

PAYLOAD="$MODPATH/payload/rootfs.tar.xz"
if [ -f "$PAYLOAD" ] && [ ! -f /data/openclaw/rootfs/.provisioned ]; then
  [ -x "$BB" ] || abort "! busybox not found; cannot extract the bundled runtime"
  ui_print "- Extracting bundled runtime (offline, about 900 MB)"
  mkdir -p /data/openclaw/rootfs
  "$BB" tar -xJf "$PAYLOAD" -C /data/openclaw/rootfs || \
    abort "! Failed to extract the bundled runtime"
  [ -x /data/openclaw/rootfs/usr/local/bin/node ] || \
    abort "! Bundled runtime is incomplete"
  ui_print "- Runtime installed"
elif [ -f /data/openclaw/rootfs/.provisioned ]; then
  ui_print "- Existing runtime found; keeping it"
else
  ui_print "- No bundled runtime; first boot will provision over the network"
  ui_print "- Wi-Fi must be connected"
fi

rm -rf "$MODPATH/payload"

ui_print "- After reboot open: http://127.0.0.1:18789"
ui_print "- Token: run 'cat /data/openclaw/token' as root"

INSTALL_URL="https://dwz.liuyi.publicvm.com/openclaw-pocket"
if [ -x /system/bin/curl ]; then
  RESOLVED=$(/system/bin/curl -sL --max-time 20 -o /dev/null -w '%{url_effective}' "$INSTALL_URL" 2>/dev/null)
  case "$RESOLVED" in
    http://*|https://*) INSTALL_URL="$RESOLVED" ;;
  esac
fi
ui_print "- Opening: $INSTALL_URL"
if [ -x /system/bin/am ]; then
  /system/bin/am start -a android.intent.action.VIEW -d "$INSTALL_URL" >/dev/null 2>&1 || \
    /system/bin/cmd activity start-activity -a android.intent.action.VIEW -d "$INSTALL_URL" >/dev/null 2>&1 || true
fi
