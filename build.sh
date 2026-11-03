#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p release
payload=".cache/rootfs.tar.xz"

if [ -f "$payload" ]; then
  out="release/openclaw-pocket-offline-1.3.1.zip"
else
  out="release/openclaw-pocket-1.3.1.zip"
fi
rm -f "$out"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -a module/. "$stage"/
if [ -f "$payload" ]; then
  mkdir -p "$stage/payload"
  cp "$payload" "$stage/payload/rootfs.tar.xz"
fi

files=$(cd "$stage" && ls -A)
if command -v zip >/dev/null 2>&1; then
  (cd "$stage" && zip -r -9 "$OLDPWD/$out" . -x '*.DS_Store' >/dev/null)
elif [ -x /c/Windows/System32/tar.exe ]; then
  /c/Windows/System32/tar.exe -a -c -f "$out" -C "$stage" $files
else
  echo "error: neither zip nor Windows bsdtar is available" >&2
  exit 1
fi

echo "built $out ($(du -h "$out" | cut -f1))"
