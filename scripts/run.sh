#!/usr/bin/env bash
# Run the gem5 simulation and print the main statistics.
#
#   GEM5=~/gem5/build/MIPS/gem5.opt ./scripts/run.sh
#
# Extra arguments are passed to configs/mips_se.py (for example --binary).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEM5_BIN="${GEM5:-}"
OUT="${OUT:-$ROOT/results}"

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
python3 "$ROOT/scripts/show_stats.py" "$OUT/stats.txt"
