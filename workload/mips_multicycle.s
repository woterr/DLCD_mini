# MIPS32 demonstration program for the DLCD mini project.
#
# It follows the examples in the course notes (Section 6):
#   * variables in registers ($s4..$s7), like Code Example 6.1
#   * add, sub and addi arithmetic
#   * sw and lw for a byte-addressed memory word on the stack
#   * bne and beq conditional branches (with explicit nop delay slots)
#   * a countdown loop whose result can be checked by hand
#
# Hand calculation:
#   f   = (g + h) - (i + j) = (5 + 3) - (4 + 2) = 2
#   sum = 3 + 2 + 1 = 6
# The program prints the sum as one ASCII digit, so the expected output is "6".

        .set    noreorder
        .set    noat

        .text
        .globl  _start

_start:
        # Make a small stack frame.  The initial value of $sp is chosen by
        # gem5's program loader; this instruction only lowers it by 32 bytes.
        addiu   $sp, $sp, -32

        # g = 5, h = 3, i = 4, j = 2
        addi    $s4, $zero, 5
        addi    $s5, $zero, 3
        addi    $s6, $zero, 4
        addi    $s7, $zero, 2

        # f = (g + h) - (i + j)
        add     $t0, $s4, $s5       # $t0 = 5 + 3 = 8
        add     $t1, $s6, $s7       # $t1 = 4 + 2 = 6
        sub     $s3, $t0, $t1       # $s3 = f = 2

        # Store f to the stack and load it back.
        sw      $s3, 16($sp)        # memory[$sp + 16] = 2
        lw      $t2, 16($sp)        # $t2 = 2

        # Check the loaded value: if it is not 2, exit with status 1.
        addi    $t3, $zero, 2
        bne     $t2, $t3, fail
        nop                         # branch delay slot

        # Countdown loop: sum = 3 + 2 + 1 = 6
        addi    $t4, $zero, 0       # $t4 = sum
        addi    $t5, $zero, 3       # $t5 = i
loop:
        add     $t4, $t4, $t5       # sum = sum + i
        addi    $t5, $t5, -1        # i = i - 1
        bne     $t5, $zero, loop    # repeat while i != 0
        nop                         # branch delay slot

        # Store the sum, load it back, and check the load with beq.
        sw      $t4, 20($sp)        # memory[$sp + 20] = 6
        lw      $t6, 20($sp)        # $t6 = 6
        beq     $t6, $t4, ok        # the loaded value equals the sum
        nop                         # branch delay slot

fail:
        addi    $a0, $zero, 1
        addi    $v0, $zero, 4001    # exit(1): the checks failed
        syscall

ok:
        # Convert 6 to ASCII '6' = 54 and write it to stdout.
        addi    $t7, $t6, 48        # $t7 = 6 + 48 = 54 = '6'
        sb      $t7, 24($sp)        # memory[$sp + 24] = '6' (one byte)
        addi    $a1, $sp, 24        # $a1 = address of the byte
        addi    $a2, $zero, 1       # $a2 = length 1
        addi    $a0, $zero, 1       # $a0 = file descriptor 1 (stdout)
        addi    $v0, $zero, 4004    # write(1, $a1, 1)
        syscall

        addi    $a0, $zero, 0
        addi    $v0, $zero, 4001    # exit(0)
        syscall
