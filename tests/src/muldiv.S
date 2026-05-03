# Exercises the rv32m multiply/divide instructions:
#   mul, mulh, mulhsu, mulhu, div, divu, rem, remu.
#
# Note: risc2cpp deliberately does NOT implement the RISC-V spec's
# special rules for division by zero or signed division overflow
# (INT_MIN / -1) -- it lowers div/rem straight to C++ '/' and '%',
# whose behaviour in those cases is undefined. So those edge cases
# are intentionally not covered here.

    .globl test_main
test_main:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # mul: low 32 bits of product. 6 * 7 = 42.
    li      a0, 6
    li      t1, 7
    mul     a0, a0, t1
    call    print_int

    # mul wraparound: 0x10000 * 0x10000 = 2^32 -> low 32 bits = 0
    li      a0, 0x10000
    li      t1, 0x10000
    mul     a0, a0, t1
    call    print_int

    # mul with a negative operand: -3 * 4 = -12
    li      a0, -3
    li      t1, 4
    mul     a0, a0, t1
    call    print_int

    # mulh: signed * signed, top 32 bits.
    # 0x40000000 * 4 = 2^32 -> top word = 1
    li      a0, 0x40000000
    li      t1, 4
    mulh    a0, a0, t1
    call    print_int

    # mulh: -1 * -1 = 1 -> top word = 0
    li      a0, -1
    li      t1, -1
    mulh    a0, a0, t1
    call    print_int

    # mulhu: unsigned * unsigned. 0xFFFFFFFF * 0xFFFFFFFF = 0xFFFFFFFE_00000001
    # top word = 0xFFFFFFFE = -2 as signed
    li      a0, -1
    li      t1, -1
    mulhu   a0, a0, t1
    call    print_int

    # mulhsu: signed * unsigned. -1 (signed) * 0xFFFFFFFF (unsigned)
    # = -4294967295 = 0xFFFFFFFF_00000001 -> top word = -1
    li      a0, -1
    li      t1, -1
    mulhsu  a0, a0, t1
    call    print_int

    # div: signed, truncates toward zero. 20 / 3 = 6
    li      a0, 20
    li      t1, 3
    div     a0, a0, t1
    call    print_int

    # div: -20 / 3 = -6 (truncation toward zero, not flooring)
    li      a0, -20
    li      t1, 3
    div     a0, a0, t1
    call    print_int

    # div: -20 / -3 = 6
    li      a0, -20
    li      t1, -3
    div     a0, a0, t1
    call    print_int

    # divu: 0xFFFFFFFF / 2 = 0x7FFFFFFF = 2147483647
    li      a0, -1
    li      t1, 2
    divu    a0, a0, t1
    call    print_int

    # divu: 100 / 3 = 33
    li      a0, 100
    li      t1, 3
    divu    a0, a0, t1
    call    print_int

    # rem: signed, sign of dividend. -20 % 3 = -2
    li      a0, -20
    li      t1, 3
    rem     a0, a0, t1
    call    print_int

    # rem: 20 % -3 = 2
    li      a0, 20
    li      t1, -3
    rem     a0, a0, t1
    call    print_int

    # remu: 0xFFFFFFFF % 7 = 3
    li      a0, -1
    li      t1, 7
    remu    a0, a0, t1
    call    print_int

    # remu: 100 % 3 = 1
    li      a0, 100
    li      t1, 3
    remu    a0, a0, t1
    call    print_int

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
