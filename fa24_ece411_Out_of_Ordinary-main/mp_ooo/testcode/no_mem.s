no_mem.s:
.align 4
.section .text
.globl _start

_start:
    # Initialize registers with various values
    li x1, 10
    li x2, 20
    li x3, 30
    li x4, 40
    li x5, 50
    li x6, 60
    li x7, 70
    li x8, 80
    li x9, 90
    li x10, 100

    # Create some initial dependencies
    add x11, x1, x2      # x11 = 30
    sub x12, x4, x3      # x12 = 10
    and x13, x5, x6      # x13 = 48
    or x14, x7, x8       # x14 = 86
    xor x15, x9, x10     # x15 = 62

branch_sequence1:
    bne x11, x12, branch_target1
    # Instructions that should be flushed
    add x16, x11, x12
    sub x17, x13, x14
    xor x18, x15, x16

branch_target1:
    # Create more dependencies
    add x19, x11, x13    # Depends on earlier computation
    sub x20, x14, x15    # Depends on earlier computation
    
    # Another branch sequence
    beq x19, x20, branch_target2
    # Should be flushed
    or x21, x19, x20
    and x22, x21, x19
    add x23, x22, x20

branch_target2:
    # Arithmetic sequence with dependencies
    srl x24, x19, x1     # Shift right logical
    sll x25, x20, x2     # Shift left logical
    sra x26, x24, x3     # Shift right arithmetic
    
    # Complex conditional branch
    blt x24, x25, branch_target3
    # Should be flushed
    add x27, x24, x25
    sub x28, x26, x27
    xor x29, x28, x27

branch_target3:
    # More arithmetic with dependencies
    add x30, x24, x25    # Depends on shifts
    sub x31, x26, x30    # Depends on previous add
    
    # Create a long dependency chain
    add x1, x30, x31
    sub x2, x1, x30
    and x3, x2, x1
    or x4, x3, x2
    xor x5, x4, x3

    # Branch based on computed value
    bge x5, x4, branch_target4
    # Should be flushed
    add x6, x5, x4
    sub x7, x6, x5
    and x8, x7, x6

branch_target4:
    # Complex arithmetic sequence
    slli x9, x5, 2       # Shift left immediate
    srli x10, x4, 1      # Shift right logical immediate
    srai x11, x3, 3      # Shift right arithmetic immediate

    # Final branch sequence
    bne x9, x10, final_target
    # Should be flushed
    add x12, x9, x10
    sub x13, x11, x12
    xor x14, x13, x12

final_target:
    # Final computations
    add x15, x9, x11     # Dependent on shifts
    sub x16, x10, x15    # Dependent on previous add
    and x17, x16, x15    # Dependent on previous sub
    or x18, x17, x16     # Dependent on previous and
    xor x19, x18, x17    # Dependent on previous or

    # Unconditional jump to exit
    j exit

    # These instructions should never execute
    add x20, x19, x18
    sub x21, x20, x19
    and x22, x21, x20

exit:
    # Program termination
    addi x0, x0, 0       # NOP
    addi x0, x0, 0       # NOP
    addi x0, x0, 0       # NOP
halt:
    slti x0, x0, -256