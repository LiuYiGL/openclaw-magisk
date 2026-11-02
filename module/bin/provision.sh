#!/system/bin/sh
# First-time provisioning: Ubuntu 24.04 arm64 rootfs + Node 26 + OpenClaw.
# Runs on the phone as root, outside the chroot. Safe to re-run.
BIN_DIR=${0%/*}
. "$BIN_DIR/common.sh"

CACHE=$BASE/cache
UBUNTU_FILE=ubuntu-base-24.04.3-base-arm64.tar.gz
NODE_VER=v26.13.0
NODE_FILE=node-$NODE_VER-linux-arm64.tar.gz

UBUNTU_URLS="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/$UBUNTU_FILE https://mirrors.aliyun.com/ubuntu-cdimage/ubuntu-base/releases/24.04/release/$UBUNTU_FILE https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/$UBUNTU_FILE"
NODE_URLS="https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/$NODE_VER/$NODE_FILE https://registry.npmmirror.com/-/binary/node/$NODE_VER/$NODE_FILE https://nodejs.org/dist/$NODE_VER/$NODE_FILE"

fetch() {
  dest=$1
  shift
  for u in "$@"; do
    log "downloading $u"
    if command -v curl >/dev/null 2>&1; then
      curl -fL --retry 3 --connect-timeout 20 -o "$dest.part" "$u" && mv "$dest.part" "$dest" && return 0
    else
      "$BB" wget -O "$dest.part" "$u" && mv "$dest.part" "$dest" && return 0
    fi
  done
  rm -f "$dest.part"
  return 1
}

wait_network() {
  i=0
  while [ "$i" -lt 60 ]; do
    if ping -c 1 -W 2 223.5.5.5 >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
    i=$((i + 1))
  done
  return 1
}

if [ -f "$ROOTFS/.provisioned" ]; then
  log "runtime already provisioned"
  exit 0
fi

if [ -z "$BB" ]; then
  log "busybox not found; cannot provision the runtime"
  exit 1
fi

abi=$(getprop ro.product.cpu.abi)
if [ "$abi" != "arm64-v8a" ]; then
  log "unsupported ABI: $abi (this module requires arm64-v8a)"
  exit 1
fi

free_kb=$(df -Pk /data 2>/dev/null | awk 'NR==2 {print $4}')
if [ -n "$free_kb" ] && [ "$free_kb" -lt 4194304 ]; then
  log "not enough free space on /data (need at least 4 GB, have $((free_kb / 1024)) MB)"
  exit 1
fi

mkdir -p "$BASE" "$CACHE" "$ROOTFS" "$HOME_DIR" "$LOGS" "$RUN"
if ! mkdir "$BASE/.provision.lock" 2>/dev/null; then
  log "another provisioning run is already active"
  exit 1
fi
trap 'rmdir "$BASE/.provision.lock" 2>/dev/null' EXIT INT TERM

if ! wait_network; then
  log "no network after 5 minutes; connect Wi-Fi and run 'openclawctl provision'"
  exit 1
fi

if [ ! -x "$ROOTFS/bin/sh" ]; then
  [ -f "$CACHE/$UBUNTU_FILE" ] || fetch "$CACHE/$UBUNTU_FILE" $UBUNTU_URLS || exit 1
  log "extracting Ubuntu rootfs"
  "$BB" tar -xzf "$CACHE/$UBUNTU_FILE" -C "$ROOTFS" || exit 1
fi

if [ ! -x "$ROOTFS/usr/local/bin/node" ]; then
  [ -f "$CACHE/$NODE_FILE" ] || fetch "$CACHE/$NODE_FILE" $NODE_URLS || exit 1
  log "extracting Node $NODE_VER"
  mkdir -p "$ROOTFS/usr/local"
  "$BB" tar -xzf "$CACHE/$NODE_FILE" -C "$ROOTFS/usr/local" --strip-components=1 || exit 1
fi

printf 'nameserver 223.5.5.5\nnameserver 119.29.29.29\nnameserver 8.8.8.8\n' > "$ROOTFS/etc/resolv.conf"
printf '127.0.0.1 localhost\n' > "$ROOTFS/etc/hosts"
mkdir -p "$ROOTFS/tmp" "$ROOTFS/root"
chmod 1777 "$ROOTFS/tmp"

cat > "$ROOTFS/etc/apt/sources.list.d/ubuntu.sources" <<'EOF'
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu-ports/
Suites: noble noble-updates noble-backports noble-security
Components: main universe restricted multiverse
EOF

mounts_up

log "installing runtime libraries"
chroot_cmd /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get \
  -o APT::Sandbox::User=root -o Acquire::ForceIPv4=true -o Acquire::Retries=3 update || exit 1
chroot_cmd /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get \
  -o APT::Sandbox::User=root -o Acquire::ForceIPv4=true -y install libatomic1 ca-certificates || exit 1

log "installing OpenClaw (this can take several minutes)"
chroot_cmd /usr/local/bin/npm install -g openclaw@latest \
  --allow-scripts=openclaw --no-fund --no-audit || {
    log "official registry failed, retrying with npmmirror"
    chroot_cmd /usr/local/bin/npm install -g openclaw@latest \
      --allow-scripts=openclaw --no-fund --no-audit \
      --registry=https://registry.npmmirror.com || exit 1
  }

"$BIN_DIR/patch-openclaw.sh" || exit 1

ensure_config
publish_token
touch "$ROOTFS/.provisioned"
log "provisioning complete"
"$BIN_DIR/start.sh"
