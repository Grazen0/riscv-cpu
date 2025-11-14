.section .text._start
.global _start

_start:
    la      sp, __stack_top
    la      gp, __global_pointer$

    #la      t0, irq_handler
    #csrw    mtvec, t0

    # ft0 = 1.5
    la      t0, x
    flw     ft0, 0(t0)

    # ft1 = 2.0
    la      t0, y
    flw     ft1, 0(t0)

    fadd.s  ft2, ft0, ft1 # ft2 = 1.5 + 2.0 = 3.5
    fadd.s  ft2, ft2, ft0 # ft2 += 1.5 = 5.0

    fsw     ft2, 4(t0)

    #call    main
    j       .

.data
x:  .float 1.5
y:  .float 2.0
