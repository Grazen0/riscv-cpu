#include "matmul_c.h"

void matmul_c(const float *const mat1, const float *const mat2, const int m, const int n,
              const int p, float *const dest)
{
    int m1_base = 0;
    int dest_base = 0;

    for (int i = 0; i < m; ++i) {
        for (int j = 0; j < p; ++j) {
            float sum = 0;
            int m2_base = 0;

            for (int k = 0; k < n; ++k) {
                sum += mat1[m1_base + k] * mat2[m2_base + j];
                m2_base += p;
            }

            dest[dest_base + j] = sum;
        }

        dest_base += p;
        m1_base += n;
    }
}
