.section .text._start
.global _start

_start:
    # li      x2, 0xDEAFBEEF
    # li      x4, 0x000B00BA

    # li      x1, 0x12345678
    # csrw    mepc, x1
    # csrrw   x2, mepc, x2
    # mv      x3, x2

    la      sp, __stack_top

    # call    __libc_init_array
    call    start

    j       .
