# Small MIPS32 little-endian program for gem5 syscall emulation.
#
# It performs:
#   - integer arithmetic (15 + 27 = 42)
#   - a store and a load through memory
#   - a conditional branch (checks the loaded value)
#   - a loop with a branch (sums 4 + 3 + 2 + 1 = 10)
#   - a write syscall that prints the arithmetic result as decimal
#   - an exit syscall
#
# This is a normal MIPS Linux user program: the syscall numbers below are
# the MIPS o32 Linux numbers used by gem5 (write = 4004, exit = 4001).

        .set noreorder
        .set noat

        .text
        .globl _start
_start:
        # Reserve a small stack frame and a scratch area.
        addiu   $sp, $sp, -32

        # 15 + 27 = 42.  t2 holds the result.
        addiu   $t0, $zero, 15
        addiu   $t1, $zero, 27
        addu    $t2, $t0, $t1

        # Store the result to memory and read it back.
        sw      $t2, 0($sp)
        lw      $t3, 0($sp)

        # Branch if the loaded value is wrong.
        addiu   $t4, $zero, 42
        bne     $t3, $t4, fail
        nop

        # Loop: 4 + 3 + 2 + 1 = 10 in t6.  This exercises backward branches.
        addiu   $t5, $zero, 4
        addiu   $t6, $zero, 0
loop:
        addu    $t6, $t6, $t5
        addiu   $t5, $t5, -1
        bne     $t5, $zero, loop
        nop

        # Convert the 42 in t3 to decimal characters, backwards, ending at
        # buffer+15.  t7 points at the first digit.
        la      $t7, buffer + 15
        sb      $zero, 0($t7)
        addiu   $t8, $zero, 10
        move    $t9, $t3
convert:
        divu    $t9, $t8
        mfhi    $s0
        mflo    $t9
        addiu   $s0, $s0, 48          # '0'
        addiu   $t7, $t7, -1
        sb      $s0, 0($t7)
        bne     $t9, $zero, convert
        nop

        # write(1, t7, buffer + 15 - t7)
        la      $t0, buffer + 15
        subu    $a2, $t0, $t7
        move    $a1, $t7
        addiu   $a0, $zero, 1
        addiu   $v0, $zero, 4004
        syscall

        # write(1, "\n", 1)
        la      $a1, newline
        addiu   $a2, $zero, 1
        addiu   $a0, $zero, 1
        addiu   $v0, $zero, 4004
        syscall

        # exit(0)
        addiu   $a0, $zero, 0
        addiu   $v0, $zero, 4001
        syscall
        nop

fail:
        # exit(1) if the memory check failed.
        addiu   $a0, $zero, 1
        addiu   $v0, $zero, 4001
        syscall
        nop

        .data
        .align  2
buffer:
        .space  16
newline:
        .byte   10
