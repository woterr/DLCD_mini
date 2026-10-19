# DLCD_mini: a small MIPS workload on gem5

This project runs a hand-written MIPS32 program on gem5 and reports the
simulated instruction count and cycle count. The configuration is a normal
syscall-emulation (SE) setup, and the CPU model is gem5's existing
`TimingSimpleCPU`. No gem5 C++ code is modified.

The project was made for a Digital Logic and Computer Design mini project
about multicycle MIPS processors. It is deliberately small: one assembly file,
one gem5 configuration, and one statistics script.

## What this actually simulates

gem5 does not contain the classic textbook multicycle MIPS processor. It has a
MIPS instruction-set implementation, and it can run that instruction set on its
generic CPU models (`AtomicSimpleCPU`, `TimingSimpleCPU`, `MinorCPU`, `O3CPU`,
and so on). Those models are not the five-state FSM with a shared ALU, shared
memory, and control signals that is usually drawn in a computer architecture
course.

This project uses `TimingSimpleCPU` because it is the closest simple model in
spirit: it executes one instruction at a time and accounts for the latency of
instruction fetches and data accesses. It does **not** have the textbook
multicycle datapath. In particular, it does not report "this instruction spent
one cycle in IF, one in ID, ..." or expose control signals. The cycle count is
produced by gem5's timing model and the memory system, not by a five-cycle
state machine. The README explains this distinction and the limits of the
result.

## MIPS in one page

MIPS is a 32-bit RISC instruction set. The important properties for this
project are:

- Instructions are 32 bits and are stored in memory like data.
- There are 32 general-purpose integer registers.
- It is a load/store architecture: arithmetic instructions work on registers;
  only load and store instructions access memory.
- The program counter (PC) holds the address of the next instruction.
- Branches and jumps change the PC. In the MIPS32 ISA, the instruction after a
  branch is in the branch delay slot. The assembly in this project uses
  `.set noreorder` and explicit `nop` instructions so the delay slots are
  visible.

The workload is compiled as little-endian MIPS32 (`mipsel`), because gem5's
MIPS syscall emulation only supports little-endian MIPS ELF files. The program
uses the MIPS o32 Linux system-call convention. gem5 intercepts the `syscall`
instruction, so the program does not need a real MIPS Linux kernel.

## What a multicycle MIPS processor is

A single-cycle processor does a whole instruction in one clock period. That
makes the clock period long, because the slowest instruction (usually a load)
sets the critical path. A multicycle processor breaks an instruction into
several steps and uses one clock period per step. The same hardware is reused
in different steps, which keeps the clock period shorter. The cost is that an
instruction now takes several clock cycles.

The usual steps are:

1. **Instruction fetch (IF)**: read the instruction at the PC from memory and
   compute `PC + 4`.
2. **Decode / register read (ID)**: decode the opcode and read the source
   registers. The immediate field is sign-extended, and the branch target is
   calculated.
3. **Execution (EX)**: the ALU performs the operation. For an R-type
   instruction this is the arithmetic/logic operation. For a load or store it
   calculates the memory address. For a branch it compares the registers and
   decides whether to update the PC.
4. **Memory access (MEM)**: a load reads data memory; a store writes data
   memory. Arithmetic and branch instructions do not use this step.
5. **Writeback (WB)**: write the ALU result or the loaded data into the
   destination register. Stores do not write a register.

In the common Patterson/Hennessy multicycle design, the approximate cycle
counts are:

| Instruction type | Stages used | Cycles |
|---|---|---:|
| R-type (for example `addu`) | IF, ID, EX, WB | 4 |
| Load (for example `lw`) | IF, ID, EX, MEM, WB | 5 |
| Store (for example `sw`) | IF, ID, EX, MEM | 4 |
| Branch (for example `bne`) | IF, ID, EX | 3 |
| Jump | IF, ID, EX | 3 |

These numbers are for the textbook FSM. They are not what this gem5 project
measures. They are included so the difference between the two is clear.

## gem5 and the CPU model used

gem5 is an event-driven computer architecture simulator. A Python
configuration script describes the simulated machine: CPU, caches, memory,
clock, and workload. gem5 then executes the program instruction by instruction
and records statistics.

This project uses:

- gem5 **v25.1.0.1** (the `MIPS` build target).
- **Syscall emulation (SE)** mode. There is no booted operating system and no
  disk image. The MIPS program starts at its ELF entry point and uses emulated
  Linux system calls.
- **`MipsTimingSimpleCPU`**, created through the standard-library
  `SimpleProcessor` with `CPUTypes.TIMING`. This is gem5's MIPS-specialized
  subclass of `BaseTimingSimpleCPU`; `config.ini` therefore prints the base
  C++ type name `BaseTimingSimpleCPU`, while the Python object is
  `MipsTimingSimpleCPU`.
- A `SimpleBoard` with no cache hierarchy and a single-channel DDR3 memory
  model. This is intentionally minimal.
- A 1 GHz clock and 64 MiB of simulated memory.

Older gem5 tutorials use `configs/example/se.py`. In gem5 v25.1 that script
has been moved to `configs/deprecated/example/se.py` and the normal path prints
a deprecation error, so this project uses the standard-library API directly
instead of copying an old command line.

MIPS is present in the gem5 source tree, but it is marked as an orphaned
architecture in gem5's `MAINTAINERS.yaml`. It is not as actively maintained as
ARM, x86, or RISC-V. The MIPS build and the little-endian SE path work for this
small program, but this is not a reason to assume that every MIPS feature is
complete.

## The workload

`workload/mips_multicycle.s` is a small MIPS32 assembly program. It does the
following:

- Adds 15 + 27 and keeps the result (42) in a register.
- Stores the result to the stack and loads it back.
- Branches to an error exit if the loaded value is not 42.
- Runs a short loop that adds 4 + 3 + 2 + 1, which exercises a backward branch.
- Converts 42 to decimal with `divu`, `mfhi`, and `mflo`.
- Prints the result with the MIPS `write` system call (syscall number 4004).
- Exits with the MIPS `exit` system call (syscall number 4001).

The expected program output is one line:

```text
42
```

The assembly is compiled without libc or CRT startup code. The build script
uses `-nostdlib -nostartfiles -no-pie -mno-abicalls`, so the ELF has direct
addresses and a fixed entry point. This matters because gem5's SE loader is not
a full dynamic linker; a position-independent binary that expects `$gp` setup
from a C runtime would not run correctly here.

## Project files

```text
configs/mips_se.py          gem5 configuration: board, TimingSimpleCPU, memory
workload/mips_multicycle.s  MIPS assembly workload
scripts/build_workload.sh   assemble and link the workload
scripts/get_toolchain.sh    download a user-space mipsel cross compiler
scripts/run.sh              run gem5 and print the statistics summary
scripts/show_stats.py       print selected fields from results/stats.txt
.gitignore                  excludes builds, results, and downloaded tools
README.md                   this file
```

Generated files are not committed:

- `workload/build/mips_multicycle.elf` is the compiled workload.
- `results/` is the gem5 output directory.
- `.toolchain/` holds the downloaded cross compiler.
- A gem5 build directory (if you build gem5 inside this project, which is not
  recommended) is ignored too.

## Prerequisites

You need:

- A 64-bit Linux machine.
- Python 3.9 or newer. This was tested with Python 3.14.8.
- A C++17 compiler (g++ or clang++).
- SCons.
- zlib development headers and `m4`.
- Git, if you are cloning gem5.
- A little-endian MIPS cross compiler. The provided script downloads one if
  your distribution does not have `mipsel-linux-gnu-gcc`.

On Fedora:

```bash
sudo dnf install gcc-c++ python3-devel zlib-devel m4 git
python3 -m pip install --user scons
```

On Debian/Ubuntu, the equivalent packages are:

```bash
sudo apt install build-essential scons python3-dev zlib1g-dev m4 git
```

gem5's build also warns about missing optional libraries (protobuf, capstone,
libpng, HDF5). They are not needed for this project.

## Build gem5

MIPS is an ISA build target, not a separate gem5 repository. Clone gem5 outside
this project and build only the MIPS target:

```bash
git clone --depth 1 --branch v25.1.0.1 https://github.com/gem5/gem5.git ~/gem5
cd ~/gem5
scons build/MIPS/gem5.opt -j4
```

The resulting binary is `~/gem5/build/MIPS/gem5.opt`. This took a while on the
machine used here; a full gem5 build is much larger than the project itself.
Adjust `-j4` to the number of cores and the available RAM.

The build may print a warning if your GCC is newer than the versions gem5
officially supports. That is a warning, not automatically a failure. If the
build stops, read the actual compiler error before changing flags.

## Build the workload

From the project root:

```bash
./scripts/get_toolchain.sh
MIPS_CC="$PWD/.toolchain/mipsel-linux-musl-cross/bin/mipsel-linux-musl-gcc" \
    ./scripts/build_workload.sh
```

If a `mipsel` cross compiler is already in your `PATH`, this is enough:

```bash
./scripts/build_workload.sh
```

The script writes `workload/build/mips_multicycle.elf` and prints the ELF type.
It should say `ELF 32-bit LSB executable, MIPS`.

## Run the simulation

From the project root:

```bash
GEM5="$HOME/gem5/build/MIPS/gem5.opt"
"$GEM5" -d results configs/mips_se.py
```

The `-d results` option puts gem5's output in `results/`. The program prints
`42`. gem5 writes `results/stats.txt`, `results/config.ini`, and
`results/config.json`.

To use a different ELF:

```bash
"$GEM5" -d results configs/mips_se.py --binary /path/to/program.elf
```

The wrapper script does the same run and prints the selected statistics:

```bash
GEM5="$HOME/gem5/build/MIPS/gem5.opt" ./scripts/run.sh
```

Show a short summary of an existing run:

```bash
python3 scripts/show_stats.py results/stats.txt
```

## Understanding the statistics

The important fields in `results/stats.txt` are:

- `simInsts`: instructions executed by the simulated CPU.
- `board.processor.cores.core.numCycles`: simulated clock cycles at the
  configured 1 GHz. This is the core object created by `SimpleBoard`; older
  gem5 configurations call the same thing `system.cpu.numCycles`.
- `board.processor.cores.core.cpi` and `.ipc`: CPI and IPC for the core.
- `simTicks`: simulated time in 1 ps ticks. `simSeconds` also exists, but it is
  rounded to six decimal places, which is too coarse for a run this short.
- `hostSeconds`: real time spent running gem5 on the host.

`scripts/show_stats.py` reads the last completed statistics block and prints
the instruction count, cycle count, CPI, simulated time, and host time. It looks
up both the standard-library names above and the classic `system.cpu` names. It
does not calculate anything that gem5 did not measure; CPI is simply
`numCycles / numInsts`.

The cycle count here is **not** the four-or-five-cycles-per-instruction count
from the textbook FSM. `TimingSimpleCPU` waits for instruction fetches and data
accesses to complete. With the no-cache configuration, even an instruction
fetch goes to the memory system, so the measured CPI is dominated by memory
latency. This is useful for seeing that memory access cost is real, but it is
not a multicycle control-unit experiment.

## Observed result

The checked run used Fedora 44 (x86_64), GCC 16.2.1, Python 3.14.8, gem5
v25.1.0.1 built as `build/MIPS/gem5.opt`, and the musl.cc
`mipsel-linux-musl-gcc` 11.2.1 cross compiler. The command was:

```bash
GEM5=/home/user/gem5/build/MIPS/gem5.opt ./scripts/run.sh
```

The program output was:

```text
42
```

The statistics printed by the wrapper were:

```text
Stats file: /mnt/shared/Academic/DLCD/MiniProj/results/stats.txt
Simulated instructions: 65
Simulated cycles:       3569
CPI (cycles/instruction): 54.908
Simulated time:          3569.000 ns
Host run time:           0.010 s
```

| Metric | Value |
|---|---:|
| Committed instructions (`simInsts`) | 65 |
| CPU cycles (`board.processor.cores.core.numCycles`) | 3,569 |
| CPI (`board.processor.cores.core.cpi`) | 54.908 |
| IPC (`board.processor.cores.core.ipc`) | 0.0182 |
| Simulated time (`simTicks` = 3,569,000 at 1 ps/tick) | 3.569 µs |
| Simulated clock | 1 GHz |
| Host wall time (`hostSeconds`) | 0.01 s |

The 65 is the dynamic instruction count, not the number of source lines.
Assembler pseudo-instructions expand: `li` and `la` become `lui`/`addiu`
pairs, and the three-operand `divu rd, rs, rt` expands to a divide-by-zero
guard plus `divu`, `break`, and `mflo`. The conversion loop runs twice, and the
error branch is never taken.

The CPI of about 55 is not a textbook multicycle result. With `NoCache`, every
instruction fetch and every data access is a DDR3 transaction, and
`TimingSimpleCPU` does not overlap instructions. The cycle count is therefore
dominated by memory latency. This is a real gem5 measurement, but it measures
a cacheless simple core, not a five-state multicycle datapath.

gem5 printed several non-fatal warnings during the run:

- the DDR3 model's default device capacity (8 GiB) does not match the 64 MiB
  address range assigned by `SingleChannelDDR3_1600(size="64MiB")`;
- the ELF does not identify an operating system, so gem5 assumes Linux (which
  is the intended SE behavior);
- one legacy statistic, disabled GDB sockets, and non-terminal stdin also
  produce informational warnings.

None of these changed the program output or prevented the run from completing.

## Limitations

- **No textbook multicycle datapath.** There is no FSM, no shared ALU/memory
  datapath, no control-signal trace, and no per-stage cycle breakdown. This is
  the main limitation relative to a classic DLCD multicycle assignment.
- **`TimingSimpleCPU` is not a pipeline and not a multicycle CPU.** It issues
  one instruction at a time and uses gem5's event timing for memory accesses.
  `MinorCPU` and `O3CPU` are also available, but they are pipelined models, not
  the five-state multicycle design.
- **MIPS is orphaned in gem5.** Only the little-endian MIPS32 SE path is used
  here. Full-system MIPS, virtual memory details, and newer MIPS extensions
  should not be assumed to work.
- **The memory system is simplified.** There are no caches in this
  configuration. The cycle count therefore includes the modeled DDR3 latency
  on every fetch and data access and is not representative of a cached
  processor.
- **The workload is tiny.** It is meant to exercise arithmetic, memory, and
  control flow, not to benchmark a processor. The instruction count is too
  small to generalize from.
- **SE mode is not a complete OS.** The program uses a small set of emulated
  Linux system calls. Programs that need threads, signals, a dynamic loader, or
  unusual syscalls may not run.

If the assignment requires you to design and verify the multicycle datapath
itself, this project is an ISA-level companion, not a replacement. The
assembly, ELF preparation, gem5 configuration, and statistics collection here
are real, but the CPU microarchitecture is gem5's `TimingSimpleCPU`.
