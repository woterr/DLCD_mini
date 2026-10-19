#!/usr/bin/env python3
"""Print a few useful numbers from a gem5 stats.txt file."""

import argparse
import re
from pathlib import Path

BEGIN = "Begin Simulation Statistics"
END = "End Simulation Statistics"


def read_last_stats_block(path: Path) -> dict[str, float]:
    """Return the last complete simulation statistics block in the file."""
    blocks: list[dict[str, float]] = []
    current: dict[str, float] | None = None

    for line in path.read_text().splitlines():
        if BEGIN in line:
            current = {}
        elif END in line:
            if current is not None:
                blocks.append(current)
            current = None
        elif current is not None and line.strip():
            match = re.match(r"^(\S+)\s+([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)", line)
            if match:
                current[match.group(1)] = float(match.group(2))

    if not blocks:
        raise SystemExit(f"No simulation statistics block found in {path}")
    return blocks[-1]


def pick(
    stats: dict[str, float], exact: tuple[str, ...], suffix: str
) -> tuple[float | None, str | None]:
    """Find a stat by known names, then by suffix.

    The standard-library board names the core ``board.processor.cores.core``
    while classic gem5 scripts use ``system.cpu``.  Looking up a suffix keeps
    this script usable with both styles.
    """
    for name in exact:
        if name in stats:
            return stats[name], name

    matches = sorted((name for name in stats if name.endswith(suffix)), key=len)
    if matches:
        return stats[matches[0]], matches[0]
    return None, None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "stats_file",
        nargs="?",
        default="results/stats.txt",
        type=Path,
        help="gem5 stats.txt (default: results/stats.txt)",
    )
    args = parser.parse_args()

    if not args.stats_file.is_file():
        raise SystemExit(f"Stats file not found: {args.stats_file}")

    stats = read_last_stats_block(args.stats_file)

    cycles, _ = pick(
        stats,
        ("system.cpu.numCycles", "board.processor.cores.core.numCycles"),
        ".numCycles",
    )
    insts, _ = pick(
        stats,
        (
            "simInsts",
            "system.cpu.commitStats0.numInsts",
            "board.processor.cores.core.commitStats0.numInsts",
            "system.cpu.numInsts",
        ),
        ".commitStats0.numInsts",
    )
    sim_ticks = stats.get("simTicks")
    host_seconds = stats.get("hostSeconds")

    print(f"Stats file: {args.stats_file}")
    print(f"Simulated instructions: {int(insts) if insts is not None else 'not found'}")
    print(f"Simulated cycles:       {int(cycles) if cycles is not None else 'not found'}")

    if cycles and insts:
        print(f"CPI (cycles/instruction): {cycles / insts:.3f}")
    else:
        print("CPI:                     not available")

    # gem5 uses 1 ps ticks, so 1000 ticks are one nanosecond.  simSeconds is
    # rounded to six decimal places in stats.txt, which is too coarse for this
    # short run, so prefer the exact tick count.
    if sim_ticks is not None:
        print(f"Simulated time:          {sim_ticks / 1e3:.3f} ns")
    elif "simSeconds" in stats:
        print(f"Simulated time:          {stats['simSeconds'] * 1e9:.3f} ns")

    if host_seconds is not None:
        print(f"Host run time:           {host_seconds:.3f} s")


if __name__ == "__main__":
    main()
