# Exercises the rv32i set-less-than instructions:
#   slt, sltu (register), slti, sltiu (immediate).

    .globl test_main
test_main:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # slt (signed): -1 < 1 -> 1
    li      a0, -1
    li      t1, 1
    slt     a0, a0, t1
    call    print_int

    # slt: 1 < -1 -> 0
    li      a0, 1
    li      t1, -1
    slt     a0, a0, t1
    call    print_int

    # slt: equal -> 0
    li      a0, 7
    li      t1, 7
    slt     a0, a0, t1
    call    print_int

    # sltu: 1 < (uint)-1 = 0xFFFFFFFF -> 1
    li      a0, 1
    li      t1, -1
    sltu    a0, a0, t1
    call    print_int

    # sltu: (uint)-1 < 1 -> 0
    li      a0, -1
    li      t1, 1
    sltu    a0, a0, t1
    call    print_int

    # sltu: 0 < 1 -> 1
    li      a0, 0
    li      t1, 1
    sltu    a0, a0, t1
    call    print_int

    # slti (signed imm): -5 < 0 -> 1
    li      a0, -5
    slti    a0, a0, 0
    call    print_int

    # slti: 5 < 5 -> 0
    li      a0, 5
    slti    a0, a0, 5
    call    print_int

    # slti: 0 < -1 -> 0
    li      a0, 0
    slti    a0, a0, -1
    call    print_int

    # sltiu: imm sign-extended then compared unsigned.
    # 0 < 1 (unsigned) -> 1
    li      a0, 0
    sltiu   a0, a0, 1
    call    print_int

    # sltiu: imm = -1 sign-extends to 0xFFFFFFFF; (uint)-1 < 0xFFFFFFFF -> 0
    li      a0, -1
    sltiu   a0, a0, -1
    call    print_int

    # sltiu: 1 < 0xFFFFFFFF (unsigned) -> 1
    li      a0, 1
    sltiu   a0, a0, -1
    call    print_int

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
