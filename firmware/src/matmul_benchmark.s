.section .text._start
.global _start

matmul_benchmark._start:
    la      sp, __stack_top

    la      a0, mat_a
    la      a1, mat_b
    li      a2, 3
    li      a3, 2
    li      a4, 3
    la      a5, mat_dest
    call    matmul_bench

    la      a0, mat_b
    la      a1, mat_c
    li      a2, 2
    li      a3, 3
    li      a4, 3
    la      a5, mat_dest
    call    matmul_bench

    la      a0, mat_b
    la      a1, mat_d
    li      a2, 2
    li      a3, 3
    li      a4, 3
    la      a5, mat_dest
    call    matmul_bench

    la      a0, mat_c
    la      a1, mat_d
    li      a2, 3
    li      a3, 3
    li      a4, 3
    la      a5, mat_dest
    call    matmul_bench

    j       .

matmul_bench:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      s0, mcycle_dest
    csrr    t0, mcycle
    sw      t0, 0(s0)

    call    matmul

    csrr    t0, mcycle
    sw      t0, 0(s0)

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

.data

mat_a:
    .float 3.0, 4.0
    .float 7.0, 2.0
    .float 5.0, 9.0

mat_b:
    .float 3.0, 1.0, 5.0
    .float 6.0, 9.0, 7.0

mat_c:
    .float -6.2, 3.14,  0.2
    .float 42.5, -8.0, 16.4
    .float  3.0, 47.3,  0.0

mat_d:
    .float   0.0,  2.0,  6.2
    .float   1.0, -3.3, 90.2
    .float  -6.0,  0.0, -5.7

.bss

mat_dest:
    .space 3 * 3 * 4

mcycle_dest:
    .space 4
