#include <stdio.h>

/* Write to an address that isn't in any allocated page, isn't in the
 * stack guard region, and isn't covered by the data segment or program
 * break. The VM should throw std::runtime_error("Illegal memory access"),
 * which the harness reports as "VM error: Illegal memory access".
 *
 * Companion to bad_read.c -- exercises the writeByte translator codepath
 * rather than readByte. */

int main(void)
{
    printf("before\n");
    fflush(stdout);

    volatile char *p = (volatile char *)0x80000000u;
    *p = 0x42;

    printf("after: wrote\n");  /* unreachable */
    return 0;
}
