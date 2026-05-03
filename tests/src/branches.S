# Exercises the rv32i conditional branch instructions:
#   beq, bne, blt, bge, bltu, bgeu.
# Each test prints 1 if the branch is taken and 0 if not.

    .globl test_main
test_main:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # beq taken: 5 == 5
    li      t0, 5
    li      t1, 5
    beq     t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # beq not taken: 5 != 6
    li      t0, 5
    li      t1, 6
    beq     t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # bne taken: 5 != 6
    li      t0, 5
    li      t1, 6
    bne     t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # bne not taken: 5 == 5
    li      t0, 5
    li      t1, 5
    bne     t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # blt taken (signed): -1 < 1
    li      t0, -1
    li      t1, 1
    blt     t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # blt not taken (signed): 1 < -1 is false
    li      t0, 1
    li      t1, -1
    blt     t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # bge taken: 5 >= 5
    li      t0, 5
    li      t1, 5
    bge     t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # bge not taken (signed): -1 >= 0 is false
    li      t0, -1
    li      t1, 0
    bge     t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # bltu taken: 1 < 0xFFFFFFFF (unsigned)
    li      t0, 1
    li      t1, -1
    bltu    t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # bltu not taken: 0xFFFFFFFF < 1 (unsigned) is false
    li      t0, -1
    li      t1, 1
    bltu    t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # bgeu taken: 0xFFFFFFFF >= 0 (unsigned)
    li      t0, -1
    li      t1, 0
    bgeu    t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # bgeu not taken: 0 >= 1 (unsigned) is false
    li      t0, 0
    li      t1, 1
    bgeu    t0, t1, 1f
    li      a0, 0
    j       2f
1:  li      a0, 1
2:  call    print_int

    # Backward branch: small loop, sum 1..5 = 15
    li      t0, 1
    li      t1, 6
    li      a0, 0
3:  add     a0, a0, t0
    addi    t0, t0, 1
    blt     t0, t1, 3b
    call    print_int

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
