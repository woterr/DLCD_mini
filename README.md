# DLCD_mini: MIPS execution trace on gem5

This is a small college mini project for the Digital Logic and Computer Design
course. It runs a hand-written MIPS32 program on gem5 and prints the
instructions gem5 executed, one line per instruction.

MIPS is a 32-bit RISC instruction set. Instructions are stored in memory like
data, arithmetic uses the 32 general-purpose registers, and `lw`/`sw` move data
between registers and memory. The program counter (PC) holds the address of the
instruction being fetched. Normally the next PC is `PC + 4`, while a branch
changes it to a target address.

The program uses `add`, `sub`, `addi`, `lw`, `sw`, `beq`, and `bne`. It computes
`(5 + 3) - (4 + 2) = 2`, then sums `3 + 2 + 1 = 6` in a loop and prints `6`.

## Prerequisites

- Linux with Python 3.
- gem5 built for MIPS, by default expected at
  `~/gem5/build/MIPS/gem5.opt`.
- `curl` and `tar`, only if no MIPS cross compiler is installed.

If gem5 is not built yet:

```bash
git clone --depth 1 --branch v25.1.0.1 https://github.com/gem5/gem5.git ~/gem5
cd ~/gem5
scons build/MIPS/gem5.opt -j4
```

## Prepare and run

From the project directory:

```bash
./scripts/prepare_workload.sh
python3 scripts/mips_demo.py
```

`prepare_workload.sh` uses `MIPS_CC` if it is set, then checks for a compiler in
`.toolchain/` or the usual `mipsel-*` names in `PATH`. If none is found, it
downloads the musl.cc little-endian MIPS toolchain into `.toolchain/`. It then
builds `workload/build/mips_multicycle.elf`.

The demo runs gem5 and prints the executed instruction trace. The expected
program output is:

```text
Program output: 6
```

The trace looks like this:

```text
D = value written by the instruction, A = memory address
PC          instruction                       result
----------------------------------------------------------------
0x4000d0    addiu $sp, $sp, -32               D=0x7fffdfe0
0x4000d4    addi $s4, $zero, 5                D=0x00000005
...
0x4000e4    add $t0, $s4, $s5                 D=0x00000008
0x4000f0    sw $s3, 16($sp)                   D=0x00000002 A=0x7fffdff0
...
```

`D=` is the value written by the instruction. `A=` is the memory address used
by a load or store. Both come directly from gem5's execution trace. The same PC
appears more than once when the program runs a loop.

If gem5 is somewhere else:

```bash
GEM5=/path/to/gem5/build/MIPS/gem5.opt python3 scripts/mips_demo.py
```

## Project files

- `configs/mips_se.py` configures gem5. It selects the MIPS timing CPU
  (`MipsTimingSimpleCPU`), a simple board, memory, and the MIPS ELF workload.
- `scripts/mips_demo.py` runs the gem5 simulation and presents the executed
  instruction trace in a readable format.
- `scripts/prepare_workload.sh` checks for or obtains the MIPS compiler and
  builds the assembly workload into an executable.
- `workload/mips_multicycle.s` contains the MIPS assembly program used to
  demonstrate arithmetic, register operations, memory access, and conditional
  branches.
- `.gitignore` excludes the generated ELF, the downloaded toolchain, and gem5
  simulation output.

## Note on the CPU model

gem5's existing `TimingSimpleCPU` executes one instruction at a time and models
instruction and data memory timing. It is not the classic textbook multicycle
datapath with its five-state control FSM, shared ALU, and shared memory. The
trace shows the real instruction sequence executed by gem5, not a cycle-by-cycle
multicycle stage trace. No new CPU model was written for this project.
