#!/system/bin/sh
# Shared paths and helpers for the OpenClaw Magisk module.

BASE=/data/openclaw
ROOTFS=$BASE/rootfs
HOME_DIR=$BASE/home
LOGS=$BASE/logs
RUN=$BASE/run
TOKEN_FILE=$BASE/token
CONFIG=$HOME_DIR/.openclaw/openclaw.json
PORT=18789

detect_busybox() {
  for p in \
    /data/adb/modules/openclaw-pocket/bin/busybox \
    /data/adb/modules_update/openclaw-pocket/bin/busybox \
    /data/adb/ksu/bin/busybox \
    /data/adb/ap/bin/busybox \
    /data/adb/magisk/busybox; do
    [ -x "$p" ] && { printf '%s\n' "$p"; return 0; }
  done
  command -v busybox 2>/dev/null
}
BB=$(detect_busybox)

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

is_mounted() { grep -q " $1 " /proc/mounts 2>/dev/null; }

mounts_up() {
  mkdir -p "$ROOTFS/proc" "$ROOTFS/dev" "$ROOTFS/sys" "$HOME_DIR" "$LOGS" "$RUN"
  is_mounted "$ROOTFS/proc" || mount -t proc proc "$ROOTFS/proc" 2>/dev/null
  is_mounted "$ROOTFS/dev" || mount -o bind /dev "$ROOTFS/dev" 2>/dev/null
  is_mounted "$ROOTFS/sys" || mount -o bind /sys "$ROOTFS/sys" 2>/dev/null
  is_mounted "$ROOTFS/root" || mount -o bind "$HOME_DIR" "$ROOTFS/root" 2>/dev/null
  return 0
}

mounts_down() {
  for m in "$ROOTFS/root" "$ROOTFS/sys" "$ROOTFS/dev" "$ROOTFS/proc"; do
    is_mounted "$m" && umount "$m" 2>/dev/null
  done
}

chroot_cmd() {
  if command -v chroot >/dev/null 2>&1; then
    chroot "$ROOTFS" /usr/bin/env -i \
      HOME=/root USER=root LOGNAME=root SHELL=/bin/bash \
      PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
      LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color TMPDIR=/tmp \
      "$@"
  else
    if [ -n "$BB" ]; then
      "$BB" chroot "$ROOTFS" /usr/bin/env -i \
        HOME=/root USER=root LOGNAME=root SHELL=/bin/bash \
        PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin \
        LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color TMPDIR=/tmp \
        "$@"
    else
      echo "chroot binary not available" >&2
      return 1
    fi
  fi
}

gateway_pids() {
  for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    first=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | head -1)
    case "$first" in
      *openclaw-gateway*) printf '%s\n' "${p#/proc/}" ;;
      */node|node)
        tr '\0' '\n' < "$p/cmdline" 2>/dev/null | grep -q 'openclaw.*gateway' && printf '%s\n' "${p#/proc/}"
        ;;
    esac
  done
}

is_running() {
  if [ -f "$RUN/supervisor.pid" ] && kill -0 "$(cat "$RUN/supervisor.pid" 2>/dev/null)" 2>/dev/null; then
    return 0
  fi
  [ -n "$(gateway_pids)" ]
}

ensure_config() {
  mkdir -p "$HOME_DIR/.openclaw"
  if [ ! -s "$TOKEN_FILE" ] && [ -f "$CONFIG" ]; then
    sed -n 's/.*"token": *"\([^"]*\)".*/\1/p' "$CONFIG" | head -1 > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
  fi
  if [ ! -s "$TOKEN_FILE" ]; then
    if [ -n "$BB" ]; then
      head -c 24 /dev/urandom | "$BB" base64 | tr -d '\n/+=' | cut -c1-32 > "$TOKEN_FILE"
    else
      head -c 24 /dev/urandom | base64 | tr -d '\n/+=' | cut -c1-32 > "$TOKEN_FILE"
    fi
    chmod 600 "$TOKEN_FILE"
  fi
  if [ ! -f "$CONFIG" ]; then
    token=$(cat "$TOKEN_FILE")
    cat > "$CONFIG" <<EOF
{
  "gateway": {
    "mode": "local",
    "port": $PORT,
    "bind": "loopback",
    "auth": { "mode": "token", "token": "$token" }
  },
  "update": { "checkOnStart": false },
  "plugins": {
    "entries": {
      "browser": { "enabled": false },
      "cua-computer": { "enabled": false },
      "canvas": { "enabled": false }
    }
  }
}
EOF
    chmod 600 "$CONFIG"
  fi
}

publish_token() {
  [ -f "$TOKEN_FILE" ] || return 0
  for d in /sdcard/Download /data/media/0/Download; do
    [ -d "$d" ] || continue
    cp "$TOKEN_FILE" "$d/openclaw-token.txt" 2>/dev/null && chmod 644 "$d/openclaw-token.txt" 2>/dev/null && return 0
  done
}

lan_ip() {
  ip -4 addr show wlan0 2>/dev/null | sed -n 's/.*inet \([0-9.]*\)\/.*/\1/p' | head -1
}
