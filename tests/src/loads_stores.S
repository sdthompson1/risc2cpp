# Exercises the rv32i load/store instructions:
#   lb, lh, lw, lbu, lhu, sb, sh, sw.
# The load tests read from a constant initialized buffer; the store
# tests write to a separate buffer and read the value back.

    .globl test_main
test_main:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # ---- Loads ----
    la      t0, buf

    lb      a0, 0(t0)           # 0x01 -> 1
    call    print_int
    lb      a0, 1(t0)           # 0xFF sign-extended -> -1
    call    print_int
    lb      a0, 2(t0)           # 0x80 sign-extended -> -128
    call    print_int
    lb      a0, 3(t0)           # 0x7F -> 127
    call    print_int

    lbu     a0, 1(t0)           # 0xFF zero-extended -> 255
    call    print_int
    lbu     a0, 2(t0)           # 0x80 zero-extended -> 128
    call    print_int

    lh      a0, 0(t0)           # 0xFF01 sign-extended -> -255
    call    print_int
    lhu     a0, 0(t0)           # 0xFF01 zero-extended -> 65281
    call    print_int
    lh      a0, 2(t0)           # 0x7F80 -> 32640
    call    print_int

    lw      a0, 0(t0)           # 0x7F80FF01 -> 2139160321
    call    print_int

    # ---- Stores ----
    la      t0, sbuf

    # sb writes one byte; lbu reads it back.
    li      t1, 0xAB
    sb      t1, 0(t0)
    lbu     a0, 0(t0)           # 0xAB -> 171
    call    print_int

    # sb truncates to low 8 bits.
    li      t1, 0x12345
    sb      t1, 1(t0)
    lbu     a0, 1(t0)           # low byte is 0x45 -> 69
    call    print_int

    # sh writes two bytes; lh reads them back.
    li      t1, 0x1234
    sh      t1, 4(t0)
    lh      a0, 4(t0)           # 0x1234 -> 4660
    call    print_int

    # sh with a value whose low halfword is negative when sign-extended.
    li      t1, 0xABCD8000
    sh      t1, 6(t0)
    lh      a0, 6(t0)           # low halfword 0x8000 sign-extended -> -32768
    call    print_int

    # sw round-trip.
    li      t1, 0x12345678
    sw      t1, 8(t0)
    lw      a0, 8(t0)           # 305419896
    call    print_int

    # sw of a value whose top bit is 1.
    li      t1, 0x80000001
    sw      t1, 12(t0)
    lw      a0, 12(t0)          # -2147483647
    call    print_int

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

    .section .rodata
    .align  2
buf:
    .byte   0x01, 0xFF, 0x80, 0x7F

    .section .data
    .align  2
sbuf:
    .word   0
    .word   0
    .word   0
    .word   0
