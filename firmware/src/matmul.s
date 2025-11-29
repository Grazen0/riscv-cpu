.text
.global matmul

# a0: const float* mat1
# a1: const float* mat2
# a2: int m
# a3: int n
# a4: int p
# a5: float* dest
matmul:
    # t0 -> i
    # t1 -> j
    # t2 -> k
    # t3 -> m1_base
    # t4 -> dest_base
    # t5 -> m2_base
    # t6 -> tmp

    # ft0 -> sum
    # ft1, ft2 -> tmp

    li      t3, 0   # m1_base = 0
    li      t4, 0   # dest_base = 0

    li      t0, 0   # i = 0
    fori:
        bge     t0, a2, fori_done

        li      t1, 0   # j = 0
        forj:
            bge     t1, a4, forj_done

            fmv.w.x ft0, zero   # sum = 0.0
            li      t5, 0       # m2_base = 0

            li      t2, 0   # k = 0
            fork:
                bge     t2, a3, fork_done

                # ft1 = mat1[m1_base + k]
                add     t6, t3, t2  # t6 = m1_base + k
                slli    t6, t6, 2   # t6 *= 4
                add     t6, t6, a0  # t6 += mat1
                flw     ft1, 0(t6)

                # ft2 = mat2[m2_base + j]
                add     t6, t5, t1  # t6 = m2_base + j
                slli    t6, t6, 2   # t6 *= 4
                add     t6, t6, a1  # t6 += mat2
                flw     ft2, 0(t6)
                addi    t2, t2, 1
                fmul.s  ft1, ft1, ft2

                fadd.s  ft0, ft0, ft1   # sum += ft1
                add     t5, t5, a4      # m2_base += p

                j       fork
            fork_done:

            # dest[dest_base + j] = sum
            add     t6, t4, t1  # t6 = dest_base + j
            slli    t6, t6, 2   # t6 *= 4
            add     t6, t6, a5  # t6 += dest
            fsw     ft0, 0(t6)

            addi    t1, t1, 1
            j       forj
        forj_done:

        add     t3, t3, a3  # m1_base += n
        add     t4, t4, a4  # dest_base += p

        addi    t0, t0, 1
        j       fori
    fori_done:

    ret
