#include <stdio.h>

/* Call through a function pointer set to a garbage address. The VM's
 * indirect-jump dispatch should fail to find this in its case_table and
 * throw std::runtime_error("Invalid code address"), which the harness
 * reports as "VM error: Invalid code address". */

typedef void (*fn_t)(void);

int main(void)
{
    printf("before\n");
    fflush(stdout);

    /* volatile prevents -O2 from constant-folding away the indirect call. */
    fn_t volatile fp = (fn_t)0xdeadbeefu;
    fp();

    printf("after\n");  /* unreachable */
    return 0;
}
