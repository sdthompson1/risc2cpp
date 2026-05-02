#include <stdio.h>

/* Read from an address that isn't in any allocated page, isn't in the
 * stack guard region, and isn't covered by the data segment or program
 * break. The VM should throw std::runtime_error("Illegal memory access"),
 * which the harness reports as "VM error: Illegal memory access".
 *
 * 0x80000000 is in the upper half of the 32-bit address space, well
 * above the heap (which starts low and grows up via brk) and well below
 * the stack top (0xfffefff0). Using a non-zero address avoids any
 * compiler "dereference of null is UB" optimisations. */

int main(void)
{
    printf("before\n");
    fflush(stdout);

    volatile char *p = (volatile char *)0x80000000u;
    char c = *p;

    printf("after: read 0x%02x\n", (unsigned char)c);  /* unreachable */
    return 0;
}
