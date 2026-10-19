# DLCD_mini: MIPS multicycle simulation with gem5

This is a small Digital Logic and Computer Design mini project. It runs a
hand-written MIPS32 program on gem5 and prints the instructions gem5 executed,
with the PC, the instruction, and the result or memory address from gem5's
trace.

The program uses the basic MIPS ideas from the course notes: registers, the
program counter, arithmetic, load/store, and conditional branches.

## Run

```bash
python3 scripts/mips_demo.py
```

Expected output:

```text
MIPS program on gem5
====================
CPU model: MipsTimingSimpleCPU (gem5 timing model)

Program output: 6

D = value written by the instruction, A = memory address
PC          instruction                       result
----------------------------------------------------------------
0x4000d0    addiu $sp, $sp, -32               D=0x7fffdfe0
0x4000d4    addi $s4, $zero, 5                D=0x00000005
...
0x4000fc    bne $t2, $t3, fail
0x400100    nop
...
```

If gem5 is not at `~/gem5/build/MIPS/gem5.opt`, set `GEM5`:

```bash
GEM5=/path/to/gem5/build/MIPS/gem5.opt python3 scripts/mips_demo.py
```

The `D=` value is the value the instruction wrote (a register result, or the
data stored by `sw`/`sb`). The `A=` value is the memory address used by a load or
store. Both come directly from gem5's `ExecAll` trace.

The PC column is the address of each executed instruction. The same PC can
appear more than once when the program runs a loop or takes a branch.

## The program

`workload/mips_multicycle.s` computes two small results by hand:

```asm
addi    $s4, $zero, 5       # g = 5
addi    $s5, $zero, 3       # h = 3
addi    $s6, $zero, 4       # i = 4
addi    $s7, $zero, 2       # j = 2

add     $t0, $s4, $s5       # $t0 = g + h = 8
add     $t1, $s6, $s7       # $t1 = i + j = 6
sub     $s3, $t0, $t1       # f = 2

sw      $s3, 16($sp)        # store f
lw      $t2, 16($sp)        # load f back

addi    $t3, $zero, 2
bne     $t2, $t3, fail      # check the loaded value
nop

addi    $t4, $zero, 0       # sum = 0
addi    $t5, $zero, 3       # i = 3
loop:
add     $t4, $t4, $t5       # sum += i
addi    $t5, $t5, -1        # i--
bne     $t5, $zero, loop    # repeat while i != 0
nop
```

The expected values are:

| Item | Value |
|---|---:|
| `f = (5 + 3) - (4 + 2)` | 2 |
| sum after the loop (`3 + 2 + 1`) | 6 |
| `$t5` after the loop | 0 |
| word at `16($sp)` | 2 |
| word at `20($sp)` | 6 |
| byte at `24($sp)` | `0x36` (`'6'`) |
| program output | `6` |

The loop body runs three times. The `bne` after the loop is taken twice and not
taken on the third iteration. The program stores `'6'` and prints it with an
emulated `write` system call, then exits.

## About the gem5 CPU model

`configs/mips_se.py` uses:

- `SimpleProcessor(cpu_type=CPUTypes.TIMING, isa=ISA.MIPS)`, which gem5 creates
  as `MipsTimingSimpleCPU`;
- a `SimpleBoard`, no cache hierarchy, and a DDR3 memory model;
- syscall emulation (SE) mode, so no operating system is booted.

gem5 does not contain the textbook multicycle MIPS datapath. `TimingSimpleCPU`
executes one instruction at a time and models instruction and data memory
timing. It does not have the five-state multicycle FSM with a shared ALU, shared
memory and control signals, and it does not expose per-stage cycle counts.

The script therefore prints the real instruction sequence from gem5, not a
cycle-by-cycle multicycle stage trace. The course notes explain the register
file, PC, instruction formats and the fetch/decode/execute cycle, but they do
not contain the classic multicycle datapath either. Nothing from that datapath
is invented here.

No gem5 C++ code was modified; this uses an existing gem5 CPU model.

## Build from scratch

You need Linux, Python 3, a C++17 compiler, SCons, zlib headers, `m4` and Git.
On Fedora:

```bash
sudo dnf install gcc-c++ python3-devel zlib-devel m4 git
python3 -m pip install --user scons
```

Build gem5 with the MIPS target:

```bash
git clone --depth 1 --branch v25.1.0.1 https://github.com/gem5/gem5.git ~/gem5
cd ~/gem5
scons build/MIPS/gem5.opt -j4
```

Build the MIPS program from the project directory:

```bash
./scripts/get_toolchain.sh
MIPS_CC="$PWD/.toolchain/mipsel-linux-musl-cross/bin/mipsel-linux-musl-gcc" \
    ./scripts/build_workload.sh
```

Then run the demo:

```bash
python3 scripts/mips_demo.py
```

## Files

```text
configs/mips_se.py          gem5 configuration (MIPS, TimingSimpleCPU, SE mode)
workload/mips_multicycle.s  MIPS32 program
scripts/mips_demo.py        run gem5 and print the executed instruction trace
scripts/build_workload.sh   assemble and link the program
scripts/get_toolchain.sh    download the little-endian MIPS cross compiler
scripts/run.sh              plain gem5 run without the trace printout
```

Generated files (the ELF, `results/`, `.toolchain/`) are excluded by
`.gitignore`.

## Tested result

The checked run used Fedora 44 (x86_64), gem5 v25.1.0.1 built for MIPS, and the
musl.cc `mipsel-linux-musl-gcc` 11.2.1 cross compiler. The program printed `6`,
and the trace printed by the script comes from that gem5 run.
