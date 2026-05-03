# Exercises rv32i unconditional jumps:
#   jal (jump and link, direct), jalr (jump and link register, indirect).
# Note: ret is jalr x0, 0(ra), and is exercised every time a function
# returns. The `call` pseudo expands to auipc+jalr, so it exercises
# jalr to a 32-bit absolute target.

    .globl test_main
test_main:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # jal direct call: helper prints 7
    jal     ra, helper

    # jalr through a register: load helper's address, call it
    la      t0, helper
    jalr    ra, 0(t0)

    # jal with x0 as link register == unconditional forward jump (j pseudo).
    # The intervening print_int(999) must be skipped.
    jal     x0, after_skip
    li      a0, 999
    call    print_int           # not reached
after_skip:
    li      a0, 42
    call    print_int

    # jalr to a computed address: jump table style.
    # Build address = base + 0 -> branch_a; print_int(101) and continue.
    la      t0, branch_a
    jalr    x0, 0(t0)           # tail-jump, no link
back_from_branch:
    li      a0, 202
    call    print_int

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# Helper invoked by jal/jalr above.
helper:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, 7
    call    print_int
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# Tail-jump destination from test_main.
branch_a:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, 101
    call    print_int
    lw      ra, 12(sp)
    addi    sp, sp, 16
    la      t0, back_from_branch
    jalr    x0, 0(t0)
