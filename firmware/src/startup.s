.section .text._start
.global _start

_start:
    la      sp, __stack_top
    la      gp, __global_pointer$

    la      t0, irq_handler
    csrw    mtvec, t0

    # la      a0, mat1
    # la      a1, mat2
    # li      a2, 3
    # li      a3, 2
    # li      a4, 3
    # la      a5, dest
    # call    matmul

    call    main
    j       .
