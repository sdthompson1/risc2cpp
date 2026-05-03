# Exercises the rv32i shift instructions:
#   sll, srl, sra (register), slli, srli, srai (immediate).
# RISC-V uses the low 5 bits of the shift amount.

    .globl test_main
test_main:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # sll: 1 << 4 = 16
    li      a0, 1
    li      t1, 4
    sll     a0, a0, t1
    call    print_int

    # sll: 0x80000000 << 1 -> top bit shifted off, result 0
    li      a0, 0x80000000
    li      t1, 1
    sll     a0, a0, t1
    call    print_int

    # sll with shift amount masked to low 5 bits: shift by 32 -> shift by 0
    li      a0, 5
    li      t1, 32
    sll     a0, a0, t1
    call    print_int

    # srl: 0x80000000 >> 1 (logical) = 0x40000000 = 1073741824
    li      a0, 0x80000000
    li      t1, 1
    srl     a0, a0, t1
    call    print_int

    # srl: -1 >> 4 (logical) = 0x0FFFFFFF = 268435455
    li      a0, -1
    li      t1, 4
    srl     a0, a0, t1
    call    print_int

    # sra: 0x80000000 >> 1 (arithmetic) = 0xC0000000 = -1073741824
    li      a0, 0x80000000
    li      t1, 1
    sra     a0, a0, t1
    call    print_int

    # sra: -8 >> 2 = -2
    li      a0, -8
    li      t1, 2
    sra     a0, a0, t1
    call    print_int

    # slli: 1 << 31 = 0x80000000 = -2147483648
    li      a0, 1
    slli    a0, a0, 31
    call    print_int

    # slli with shamt 0: identity
    li      a0, 12345
    slli    a0, a0, 0
    call    print_int

    # srli: -1 >>l 1 = 0x7FFFFFFF = 2147483647
    li      a0, -1
    srli    a0, a0, 1
    call    print_int

    # srai: -1 >>s 1 = -1
    li      a0, -1
    srai    a0, a0, 1
    call    print_int

    # srai: 1024 >>s 4 = 64
    li      a0, 1024
    srai    a0, a0, 4
    call    print_int

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
