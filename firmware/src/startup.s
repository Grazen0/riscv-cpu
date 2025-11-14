.section .text._start
.global _start

_start:
    la      sp, __stack_top
    la      gp, __global_pointer$

    #la      t0, irq_handler
    #csrw    mtvec, t0

    la      t0, x
    flw     ft0, 0(t0)

    la      t0, y
    flw     ft1, 0(t0)

    fsw     ft1, 4(t0)

    #call    main
    j       .

.data
x:  .float 1.5
y:  .float 2.0
