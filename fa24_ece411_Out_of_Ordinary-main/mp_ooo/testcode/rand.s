ooo_test.s:
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # demonstrating OOO-ness

    # This test is NOT exhaustive
_start:

addi x1,x0,1
addi x2,x0,2
addi x3,x0,3
addi x4,x0,4
addi x5,x0,5
addi x6,x0,6
addi x7,x0,7
addi x8,x0,8
addi x9,x0,9
addi x10,x0,10
addi x11,x0,11
addi x12,x0,12
addi x13,x0,13
addi x14,x0,14
addi x15,x0,15
addi x16,x0,16
addi x17,x0,17
addi x18,x0,18
addi x19,x0,19
addi x20,x0,20
addi x21,x0,21
addi x22,x0,22
addi x23,x0,23

addi x4, x16, 929     # 0x3a183213
addi x20, x30, 1422   # 0x58ef7a13
lui x4, 0x6d790       # 0x6d790237
xor x28, x18, x29     # 0x01d91e33
add x0, x22, x8       # 0x008b7033
addi x4, x3, 172      # 0x0ac1b213
xor x8, x14, x23      # 0x01774433
sltiu x29, x24, 293   # 0x125c3e93
lui x13, 0x50081      # 0x500816b7
lui x12, 0xb5c3c      # 0xb5c3c637
xor x7, x8, x11       # 0x00b443b3
and x6, x3, x6        # 0x0061f333
lui x7, 0x4601b       # 0x4601b3b7
lui x9, 0xb1762       # 0xb17624b7
ori x4, x22, -1267    # 0xb0db6213
lui x1, 0xdeff9       # 0xdeff90b7
lui x19, 0x37942      # 0x379429b7
and x15, x11, x31     # 0x01f5f7b3
sll x10, x12, x31     # 0x01f61533
sltu x15, x26, x19    # 0x013d37b3
add x21, x0, x0       # 0x40000ab3
lui x14, 0x805fe      # 0x805fe737


halt:
    slti x0, x0, -256
