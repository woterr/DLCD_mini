#!/usr/bin/env bash
# Build the MIPS test program as a static, little-endian MIPS32 ELF.
#
# Set MIPS_CC to an existing cross compiler, for example:
#   MIPS_CC=/opt/mipsel-linux-musl/bin/mipsel-linux-musl-gcc ./scripts/build_workload.sh
# If MIPS_CC is not set, the script looks for common cross compiler names.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/workload/mips_multicycle.s"
OUT_DIR="$ROOT/workload/build"
OUT="$OUT_DIR/mips_multicycle.elf"

if [[ -z "${MIPS_CC:-}" ]]; then
    for candidate in mipsel-linux-musl-gcc mipsel-linux-gnu-gcc mipsel-linux-gcc; do
        if command -v "$candidate" >/dev/null 2>&1; then
            MIPS_CC="$candidate"
            break
        fi
    done
fi

if [[ -z "${MIPS_CC:-}" ]]; then
    echo "No little-endian MIPS cross compiler found." >&2
    echo "Install one, or run scripts/get_toolchain.sh and set MIPS_CC." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
"$MIPS_CC" -EL -mabi=32 -march=mips32 -nostdlib -nostartfiles -static -no-pie -fno-pic -mno-abicalls \
    -Wl,-e,_start -o "$OUT" "$SRC"

file "$OUT" 2>/dev/null || true
echo "Built $OUT"
