.section .text._start
.global _start

_start:
    la      sp, __stack_top

    la      t0, irq_handler
    csrw    mtvec, t0

    call    start

1:
    call    loop
    j       1b
