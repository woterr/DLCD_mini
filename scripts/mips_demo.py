#!/usr/bin/env python3
"""Run the MIPS program on gem5 and print the instructions gem5 executed."""

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GEM5 = Path(
    os.environ.get("GEM5", str(Path.home() / "gem5/build/MIPS/gem5.opt"))
).expanduser()
BINARY = ROOT / "workload" / "build" / "mips_multicycle.elf"
OUT = ROOT / "results" / "demo"

REGISTERS = [
    "$zero", "$at", "$v0", "$v1", "$a0", "$a1", "$a2", "$a3",
    "$t0", "$t1", "$t2", "$t3", "$t4", "$t5", "$t6", "$t7",
    "$s0", "$s1", "$s2", "$s3", "$s4", "$s5", "$s6", "$s7",
    "$t8", "$t9", "$k0", "$k1", "$gp", "$sp", "$fp", "$ra",
]

TRACE_LINE = re.compile(
    r"A\d+\s+T\d+\s*:\s*(0x[0-9a-fA-F]+)(?:\s+@\S+)?\s*:\s*"
    r"(.+?)\s*:\s*\S+\s*:\s*(.*)"
)
RESULT = re.compile(r"\bD=(0x[0-9a-fA-F]+)")
ADDRESS = re.compile(r"\bA=(0x[0-9a-fA-F]+)")


def mips_names(text):
    """Change gem5's register numbers (r29, f0) to assembly names ($sp, $zero)."""
    text = re.sub(r"\br(\d+)\b", lambda m: REGISTERS[int(m.group(1))], text)
    return re.sub(r"\bf0\b", "$zero", text)


def main():
    if not GEM5.is_file():
        sys.exit(f"gem5 not found at {GEM5}. Set GEM5 to the MIPS gem5.opt binary.")
    if not BINARY.is_file():
        sys.exit(
            f"Workload not found at {BINARY}.\n"
            "Run scripts/prepare_workload.sh first."
        )

    OUT.mkdir(parents=True, exist_ok=True)
    command = [
        str(GEM5),
        "-d", str(OUT),
        "--debug-flags=ExecAll",
        "--debug-file=trace.txt",
        str(ROOT / "configs" / "mips_se.py"),
        "--binary", str(BINARY),
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        sys.exit("gem5 failed")

    print("MIPS program on gem5")
    print("====================")
    print("CPU model: MipsTimingSimpleCPU (gem5 timing model)")
    print()
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    if lines:
        print(f"Program output: {lines[-1]}")
        print()

    print("D = value written by the instruction, A = memory address")
    print(f"{'PC':<10}  {'instruction':<32}  result")
    print("-" * 64)
    for line in (OUT / "trace.txt").read_text().splitlines():
        match = TRACE_LINE.search(line)
        if not match:
            continue
        pc, instruction, rest = match.groups()
        instruction = mips_names(" ".join(instruction.split()))
        data = RESULT.search(rest)
        address = ADDRESS.search(rest)
        extra = ""
        if data:
            extra += f"D=0x{int(data.group(1), 16):08x}"
        if address:
            extra += f" A=0x{int(address.group(1), 16):08x}"
        print(f"{pc:<10}  {instruction:<32}  {extra}".rstrip())


if __name__ == "__main__":
    main()
