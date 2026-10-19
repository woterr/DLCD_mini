#!/usr/bin/env bash
# Run the gem5 simulation

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEM5_BIN="${GEM5:-}"
OUT="${OUT:-$ROOT/results}"

if [[ -z "$GEM5_BIN" ]]; then
    if [[ -x "$HOME/gem5/build/MIPS/gem5.opt" ]]; then
        GEM5_BIN="$HOME/gem5/build/MIPS/gem5.opt"
    elif command -v gem5.opt >/dev/null 2>&1; then
        GEM5_BIN="$(command -v gem5.opt)"
    fi
fi

if [[ -z "$GEM5_BIN" ]]; then
    echo "Set GEM5 to the MIPS gem5 binary, for example:" >&2
    echo "  GEM5=~/gem5/build/MIPS/gem5.opt ./scripts/run.sh" >&2
    exit 1
fi
if [[ ! -x "$GEM5_BIN" ]]; then
    echo "gem5 binary is not executable: $GEM5_BIN" >&2
    exit 1
fi

"$GEM5_BIN" -d "$OUT" "$ROOT/configs/mips_se.py" "$@"
