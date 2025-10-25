.section .text._start
.global _start

_start:
    la      gp, __global_pointer$
    la      sp, __stack_top

    call    __libc_init_array
    call    start

    j       .

.data
hello: .asciz "Hello, world!"
