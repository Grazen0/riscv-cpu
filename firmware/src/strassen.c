#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define UMBRAL 16

static void strassen_mul(const float *A, const float *B, float *C, int n)
{
    if (n <= UMBRAL) {
        const float *row_a = A;
        float *row_c = C;
        int i = 0;
        while (i < n) {
            int j = 0;
            while (j < n) {
                const float *col_b = B;
                float sum = 0;
                int k = 0;
                while (k < n) {
                    float prod = row_a[k] * col_b[j];
                    sum += prod;
                    col_b += n;
                    ++k;
                }
                row_c[j] = sum;
                ++j;
            }
            row_a += n;
            row_c += n;
            ++i;
        }
        return;
    }

    const int m = n >> 1;
    const int mm = m * m;
    const int mn = mm << 1;

    const float *A11 = A;
    const float *A12 = A + m;
    const float *A21 = A + mn;
    const float *A22 = A21 + m;

    const float *B11 = B;
    const float *B12 = B + m;
    const float *B21 = B + mn;
    const float *B22 = B21 + m;

    float *C11 = C;
    float *C12 = C + m;
    float *C21 = C + mn;
    float *C22 = C21 + m;

    float buffer[9 * mm];
    float *M1 = buffer;
    float *M2 = buffer + mm;
    float *M3 = M2 + mm;
    float *M4 = M3 + mm;
    float *M5 = M4 + mm;
    float *M6 = M5 + mm;
    float *M7 = M6 + mm;
    float *T1 = M7 + mm;
    float *T2 = T1 + mm;

    int i = 0;
    int lin = 0;
    int offset = 0;
    while (i < m) {
        int j = 0;
        while (j < m) {
            T1[lin] = A11[offset] + A22[offset];
            T2[lin] = B11[offset] + B22[offset];
            ++j;
            ++lin;
            ++offset;
        }
        offset += m;
        ++i;
    }
    strassen_mul(T1, T2, M1, m);

    i = 0;
    lin = 0;
    offset = 0;
    while (i < m) {
        int j = 0;
        while (j < m) {
            T1[lin] = A21[offset] + A22[offset];
            T2[lin] = B11[offset];
            ++j;
            ++lin;
            ++offset;
        }
        offset += m;
        ++i;
    }
    strassen_mul(T1, T2, M2, m);

    i = 0;
    lin = 0;
    offset = 0;
    while (i < m) {
        int j = 0;
        while (j < m) {
            T1[lin] = A11[offset];
            T2[lin] = B12[offset] - B22[offset];
            ++j;
            ++lin;
            ++offset;
        }
        offset += m;
        ++i;
    }
    strassen_mul(T1, T2, M3, m);

    i = 0;
    lin = 0;
    offset = 0;
    while (i < m) {
        int j = 0;
        while (j < m) {
            T1[lin] = A22[offset];
            T2[lin] = B21[offset] - B11[offset];
            ++j;
            ++lin;
            ++offset;
        }
        offset += m;
        ++i;
    }
    strassen_mul(T1, T2, M4, m);

    i = 0;
    lin = 0;
    offset = 0;
    while (i < m) {
        int j = 0;
        while (j < m) {
            T1[lin] = A11[offset] + A12[offset];
            T2[lin] = B22[offset];
            ++j;
            ++lin;
            ++offset;
        }
        offset += m;
        ++i;
    }
    strassen_mul(T1, T2, M5, m);

    i = 0;
    lin = 0;
    offset = 0;
    while (i < m) {
        int j = 0;
        while (j < m) {
            T1[lin] = A21[offset] - A11[offset];
            T2[lin] = B11[offset] + B12[offset];
            ++j;
            ++lin;
            ++offset;
        }
        offset += m;
        ++i;
    }
    strassen_mul(T1, T2, M6, m);

    i = 0;
    lin = 0;
    offset = 0;
    while (i < m) {
        int j = 0;
        while (j < m) {
            T1[lin] = A12[offset] - A22[offset];
            T2[lin] = B21[offset] + B22[offset];
            ++j;
            ++lin;
            ++offset;
        }
        offset += m;
        ++i;
    }
    strassen_mul(T1, T2, M7, m);

    i = 0;
    lin = 0;
    offset = 0;
    while (i < m) {
        int j = 0;
        while (j < m) {
            C11[offset] = M1[lin] + M4[lin] - M5[lin] + M7[lin];
            C12[offset] = M3[lin] + M5[lin];
            C21[offset] = M2[lin] + M4[lin];
            C22[offset] = M1[lin] - M2[lin] + M3[lin] + M6[lin];
            ++j;
            ++lin;
            ++offset;
        }
        offset += m;
        ++i;
    }
}

static void classical_mul(const float *A, const float *B, float *C, int n)
{
    memset(C, 0, sizeof(float) * n * n);
    for (int i = 0; i < n; ++i) {
        for (int k = 0; k < n; ++k) {
            for (int j = 0; j < n; ++j) {
                C[i * n + j] += A[i * n + k] * B[k * n + j];
            }
        }
    }
}

static int equal_mat(const float *A, const float *B, int n)
{
    for (int i = 0; i < n * n; ++i) {
        float diff = A[i] - B[i];
        if (diff < 0)
            diff = -diff;
        if (diff > 1e-9)
            return 0;
    }
    return 1;
}

int main(void)
{
    srand((unsigned)time(NULL));
    int n = 512;

    float A[n * n];
    float B[n * n];
    for (int i = 0; i < n * n; ++i) {
        A[i] = (float)(rand() % 10);
        B[i] = (float)(rand() % 10);
    }

    struct timespec t1, t2;
    double tiempo_strassen, tiempo_naive;

    clock_gettime(CLOCK_MONOTONIC, &t1);
    float C1[n * n];
    strassen_mul(A, B, C1, n);
    clock_gettime(CLOCK_MONOTONIC, &t2);

    tiempo_strassen = (t2.tv_sec - t1.tv_sec) + (t2.tv_nsec - t1.tv_nsec) / 1e9;

    clock_gettime(CLOCK_MONOTONIC, &t1);
    float C2[n * n];
    classical_mul(A, B, C2, n);
    clock_gettime(CLOCK_MONOTONIC, &t2);

    tiempo_naive = (t2.tv_sec - t1.tv_sec) + (t2.tv_nsec - t1.tv_nsec) / 1e9;

    printf("Comparando resultados...\n");
    if (equal_mat(C1, C2, n))
        printf("OK: resultados coinciden.\n");
    else
        printf("ERROR: discrepancia entre Strassen y naive.\n");

    printf("Tiempo Strassen: %.6f s\n", tiempo_strassen);
    printf("Tiempo tradicional: %.6f s\n", tiempo_naive);

    return 0;
}
