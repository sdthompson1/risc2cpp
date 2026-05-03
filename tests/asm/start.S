# Shared startup + helper for the .S instruction tests in tests/src/.
#
# Each test file defines `test_main`, which we call after setting up a
# stack. When test_main returns we issue SYS_exit (93) with status 0.
#
# print_int(int32_t a0) issues the test-only SYS_print_int (0x10000)
# ecall, which the host harness renders as "%d\n" on stdout.

    .section .text._start, "ax"
    .globl _start
_start:
    la      sp, _stack_top
    call    test_main
    li      a7, 93              # SYS_exit
    li      a0, 0
    ecall
1:  j       1b

    .globl print_int
print_int:
    li      a7, 0x10000         # SYS_print_int
    ecall
    ret

    .section .bss
    .align  4
    .space  4096
_stack_top:
