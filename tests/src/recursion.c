#include <stdio.h>

/* Deep-but-bounded recursion. Exercises the VM's stack growth /
 * guard-page allocation path. The recursion is deep enough to require
 * allocating multiple stack pages. */

static long sum_to(int n)
{
    if (n == 0) return 0;
    return (long)n + sum_to(n - 1);
}

/* Classic Ackermann; stays modest in depth but tests heavily recursive
 * control flow. */
static int ackermann(int m, int n)
{
    if (m == 0) return n + 1;
    if (n == 0) return ackermann(m - 1, 1);
    return ackermann(m - 1, ackermann(m, n - 1));
}

int main(void)
{
    printf("sum_to(5000)    = %ld\n", sum_to(5000));
    printf("sum_to(20000)   = %ld\n", sum_to(20000));
    printf("ackermann(3, 8) = %d\n", ackermann(3, 8));
    return 0;
}
