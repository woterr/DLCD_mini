#!/usr/bin/env bash
# Download a small prebuilt little-endian MIPS cross compiler into .toolchain/.
# This is only needed on systems without a mipsel cross compiler (for example
# Fedora).  The toolchain is not committed to git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/.toolchain"
URL="https://musl.cc/mipsel-linux-musl-cross.tgz"
ARCHIVE="$DEST/mipsel-linux-musl-cross.tgz"

if [[ -x "$DEST/mipsel-linux-musl-cross/bin/mipsel-linux-musl-gcc" ]]; then
    echo "Toolchain already present in $DEST"
    exit 0
fi

mkdir -p "$DEST"
curl -L --fail --output "$ARCHIVE" "$URL"
tar -xzf "$ARCHIVE" -C "$DEST"
echo "Installed toolchain in $DEST"
