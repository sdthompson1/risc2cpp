#include <stdio.h>
#include <stdlib.h>

/* Exercises function pointers / indirect jumps via qsort + a comparator. */

static int cmp_int_asc(const void *a, const void *b)
{
    int x = *(const int *)a, y = *(const int *)b;
    return (x > y) - (x < y);
}

static int cmp_int_desc(const void *a, const void *b)
{
    int x = *(const int *)a, y = *(const int *)b;
    return (y > x) - (y < x);
}

int main(void)
{
    /* Deterministic pseudo-random sequence (LCG). */
    unsigned state = 12345u;
    enum { N = 50 };
    int arr[N];
    for (int i = 0; i < N; i++) {
        state = state * 1103515245u + 12345u;
        arr[i] = (int)((state >> 16) % 1000);
    }

    qsort(arr, N, sizeof(int), cmp_int_asc);
    printf("ascending:");
    for (int i = 0; i < N; i++) printf(" %d", arr[i]);
    printf("\n");

    qsort(arr, N, sizeof(int), cmp_int_desc);
    printf("descending:");
    for (int i = 0; i < N; i++) printf(" %d", arr[i]);
    printf("\n");

    return 0;
}
