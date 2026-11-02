#!/system/bin/sh
# Android kernels do not expose /proc/self/ns/pid. OpenClaw uses that inode to
# verify that a Gateway owner lives in the same PID namespace, so without this
# patch every Gateway start fails with "different PID namespace".
# Patch it to a stable fallback value; both the recorded owner and the current
# process then read the same value and the ownership check passes.
BIN_DIR=${0%/*}
. "$BIN_DIR/common.sh"

OC="$ROOTFS/usr/local/lib/node_modules/openclaw"
[ -d "$OC/dist" ] || exit 0

OLD='fs.statSync("/proc/self/ns/pid", { bigint: true }).ino.toString()'
NEW='(()=>{try{return fs.statSync("/proc/self/ns/pid", { bigint: true }).ino.toString()}catch{return "android-nons"}})()'

changed=0
for f in $(grep -rlF "$OLD" "$OC/dist" 2>/dev/null); do
  if sed -i "s#${OLD}#${NEW}#g" "$f"; then
    changed=$((changed + 1))
  fi
done

if [ "$changed" -gt 0 ]; then
  log "patched $changed OpenClaw bundle(s) for Android PID namespace"
fi

UNPATCHED='pidNsInode: fs.statSync("/proc/self/ns/pid"'
if grep -rqF "$UNPATCHED" "$OC/dist" 2>/dev/null; then
  log "warning: some OpenClaw bundles are still unpatched"
  exit 1
fi

version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$OC/package.json" 2>/dev/null | head -1)
[ -n "$version" ] && echo "$version" > "$BASE/.patched-version"
exit 0
