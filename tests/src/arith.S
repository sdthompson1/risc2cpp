# Exercises the rv32i integer arithmetic / bitwise instructions:
#   add, sub, addi, and, or, xor, andi, ori, xori, lui, auipc.
# Each block computes a value into a0 and calls print_int.

    .globl test_main
test_main:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # add: 3 + 4 = 7
    li      a0, 3
    li      t1, 4
    add     a0, a0, t1
    call    print_int

    # sub: 10 - 7 = 3
    li      a0, 10
    li      t1, 7
    sub     a0, a0, t1
    call    print_int

    # sub producing a negative result: 5 - 8 = -3
    li      a0, 5
    li      t1, 8
    sub     a0, a0, t1
    call    print_int

    # addi with negative immediate: 100 + (-1) = 99
    li      a0, 100
    addi    a0, a0, -1
    call    print_int

    # add wraparound: 0x7fffffff + 1 = -2147483648
    li      a0, 0x7fffffff
    li      t1, 1
    add     a0, a0, t1
    call    print_int

    # and: 0xF0F0 & 0x0FF0 = 0x00F0 = 240
    li      a0, 0xF0F0
    li      t1, 0x0FF0
    and     a0, a0, t1
    call    print_int

    # or: 0xF0F0 | 0x0FF0 = 0xFFF0 = 65520
    li      a0, 0xF0F0
    li      t1, 0x0FF0
    or      a0, a0, t1
    call    print_int

    # xor: 0xF0F0 ^ 0x0FF0 = 0xFF00 = 65280
    li      a0, 0xF0F0
    li      t1, 0x0FF0
    xor     a0, a0, t1
    call    print_int

    # andi with sign-extended immediate: 0x12345678 & -1 = 0x12345678
    li      a0, 0x12345678
    andi    a0, a0, -1
    call    print_int

    # ori: 0x00FF | 0x0700 = 0x07FF = 2047
    li      a0, 0x00FF
    ori     a0, a0, 0x700
    call    print_int

    # xori with -1 = bitwise NOT: ~0 = -1, ~0x55 = 0xFFFFFFAA = -86
    li      a0, 0x55
    xori    a0, a0, -1
    call    print_int

    # lui: load 0x12345 into bits [31:12], so a0 = 0x12345000 = 305418240
    lui     a0, 0x12345
    call    print_int

    # auipc + addi gives the address of a known label; we don't print
    # the address (not deterministic across builds) but we can verify
    # auipc by computing (label - auipc_pc) which assembler+linker
    # resolve. The `la` pseudo expands to auipc+addi; subtracting two
    # such addresses yields a known constant.
    la      t0, marker_a
    la      t1, marker_b
    sub     a0, t1, t0          # bytes between the two markers
    call    print_int

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

    .section .rodata
    .align  2
marker_a:
    .word   0
    .space  16
marker_b:
    .word   0
