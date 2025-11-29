.section .text._start
.global _start
.extern irq_handler

_start:
    la      sp, __stack_top
    la      gp, __global_pointer$

    la      t0, irq_handler
    csrw    mtvec, t0

    call    main
    j       .
