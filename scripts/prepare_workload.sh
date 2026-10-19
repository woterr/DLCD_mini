#!/usr/bin/env bash
# Build the MIPS workload, downloading the cross compiler if necessary.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/workload/mips_multicycle.s"
OUT_DIR="$ROOT/workload/build"
OUT="$OUT_DIR/mips_multicycle.elf"
TOOLCHAIN_DIR="$ROOT/.toolchain"
LOCAL_CC="$TOOLCHAIN_DIR/mipsel-linux-musl-cross/bin/mipsel-linux-musl-gcc"
TOOLCHAIN_URL="https://musl.cc/mipsel-linux-musl-cross.tgz"
ARCHIVE="$TOOLCHAIN_DIR/mipsel-linux-musl-cross.tgz"

CC="${MIPS_CC:-}"
if [[ -z "$CC" ]]; then
    for candidate in "$LOCAL_CC" mipsel-linux-musl-gcc mipsel-linux-gnu-gcc mipsel-linux-gcc; do
        if [[ -x "$candidate" ]] || command -v "$candidate" >/dev/null 2>&1; then
            CC="$candidate"
            break
        fi
    done
fi

if [[ -z "$CC" ]]; then
    echo "No MIPS cross compiler found. Downloading one into .toolchain/ ..."
    mkdir -p "$TOOLCHAIN_DIR"
    curl -L --fail --output "$ARCHIVE" "$TOOLCHAIN_URL"
    tar -xzf "$ARCHIVE" -C "$TOOLCHAIN_DIR"
    CC="$LOCAL_CC"
fi

if ! command -v "$CC" >/dev/null 2>&1; then
    echo "MIPS compiler is not executable: $CC" >&2
    exit 1
fi

echo "Using MIPS compiler: $CC"
mkdir -p "$OUT_DIR"
"$CC" -EL -mabi=32 -march=mips32 -nostdlib -nostartfiles -static -no-pie \
    -fno-pic -mno-abicalls -Wl,-e,_start -o "$OUT" "$SRC"

echo "Prepared $OUT"
