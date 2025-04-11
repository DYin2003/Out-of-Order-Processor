ooo_test.s:
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # demonstrating OOO-ness

    # This test is NOT exhaustive
_start:

# ! spike uses x5, x10, x11 so don't use them

# initialize
li x1, 10
li x2, 20
li x7, 50
li x4, 60
li x8, 21
li x9, 28
# li x10, 11
# li x11, 12
li x13, 8
li x12, 4
li x14, 3
li x15, 1
li x16, 2
li x17, 3
li x18, 4
li x19, 5
li x20, 6
li x21, 7
li x22, 8
li x23, 9
li x24, 10
li x25, 11
li x26, 12
li x27, 14
auipc x4, 0;

lui x14, 0xFFFF
lui x15, 0xEEEE


lw x16, LOAD_TEST   #try load 
sw x17, 0(x16)       # 
sw x17, 4(x16)
sw x17, 8(x16)
sw x17, 12(x16)
sw x26, 12(x16)

lw x1, 12(x16)      #try load


# targeted test to force a cache writeback
sw x1, 0(x4)    # should store to 1eceb000, making it dirty
lb x2, LOAD_TEST # this should force a cache writeback



# lw x18, LOAD_TEST #try load 
# lw x19, LOAD_TEST #try load 
# lw x20, LOAD_TEST #try load 

# Test Load Word (lw) and Store Word (sw)
    # lui x4, 0x1ECE0          # Load upper immediate (for address)
    # addi x4, x4, 0x128      # Add lower 12 bits to form the full address (0x1ECEF128)
    sw x7, 0(x4)            # store word from address x4 into x7
    # # Expected value: 0x1ECEF128
    lw x4, 0(x4)            # Store the value from x7 to the address in x1

    # # Test Load Halfword (lh) and Store Halfword (sh)
    # # lui x8, 0xAA55          # Load upper immediate (for address)
    # # addi x8, x8, 0x5A6     # Add lower 12 bits to form the full address (0xAA555A5)
    # sh x9, 2(x4)            # Load signed halfword from address x8 into x9
    # # Exected value: 0xAA55 (halfword stored at 0xAA55AA6)
    # lh x2, 2(x4)            # Store the value from x9 as halfword at the address in x2

    # # Test Load Halfword Unsigned (lhu) and Store Halfword (sh)
    # # lui x10, 0x1234         # Load upper immediate (for address)
    # # addi x10, x10, 0x568  # Add lower 12 bits to form the full address (0x1234567)
    # sh x30, -2(x4)         # Load unsigned halfword from address x10 into x11
    # # Expected value: 0x567 (halfword loaded at 0x1234568)
    # lhu x31, -2(x4)           # Store unsigned halfword from x11 to address x3

    # # Test Load Byte (lb) and Store Byte (sb)
    # # lui x12, 0x1F1F         # Load upper immediate (for address)
    # # addi x12, x12, 0x1F1   # Add lower 12 bits to form the full address (0x1F1F1F1)
    # sb x13, 7(x4)          # Load signed byte from address x12 into x13
    # # Expected value: 0xF0 (byte stored at 0x1F1F1F1F)
    # lb x12, 7(x4)           # Store byte from x13 to the address in x4

    # # Test Load Byte Unsigned (lbu) and Store Byte (sb)
    # # lui x14, 0x5555         # Load upper immediate (for address)
    # # addi x14, x14, 0x555    # Add lower 12 bits to form the full address (0x55555555)
    # sb x15, 11(x4)         # Load unsigned byte from address x14 into x15
    # # Expected value: 0xF8 (byte loaded at 0x55555555)
    # # lbu x16, 11(x4)           # Store unsigned byte from x15 to the address in x5


nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop

halt:
    slti x0, x0, -256


.data   
LOAD_TEST: .word 0x1ecef128
