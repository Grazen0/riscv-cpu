.section .text._start
.global _start

_start:
    la      sp, __stack_top
    call    start
1:
    j       1b
