ooo_test.s:
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # demonstrating OOO-ness

    # This test is NOT exhaustive
_start:

# initialize
Lui x2, 0xFFFF
li x1, 20
li x5, 50
li x6, 60
li x8, 21
li x9, 28
li x11, 8
li x12, 4
li x14, 3
li x15, 1
auipc   x3, 0


lui x14, 0xFFFF
lui x15, 0xEEEE

# cache writeback test: populate 4 ways in the cache, make one dirty, 
# and try to write back

# populate first way:
lw x1, 0(x3)
sw x2, 0(x3) # make it dirty 

# populate second way:
addi x4, x0, 0x100
slli x4, x4, 0x1
add x7, x4, x3 # make x7 point to 1eceb228
sw x1, 0(x7) # store into 1eceb228
lw x6, 0(x7) # load from 1eceb228

# populate third way:
slli x4, x4, 0x1
add x7, x4, x3 # make x7 point to 1eceb428
sw x1, 0(x7) # store into 0x1eceb428
lw x6, 0(x7) # load from 0x1eceb428

# populate fourth way:
slli x4, x4, 0x1
add x7, x4, x3 # make x7 point to 1eceb828
sw x1, 0(x7) # store into 0x1eceb828
lw x6, 0(x7) # load from 0x1eceb828

# trigger a writeback
slli x4, x4, 0x1
add x7, x4, x3 # make x7 point to 1ecec028
sw x1, 0(x7) # store into 1ecec028
lw x6, 0(x7) # load from 1ecec028

# now try to read back from 1eceb028
lw x1, 0(x3)


# mul x2,x6,x1
# addi x1,x0,1
# addi x2,x0,1
# beq x1, x2, halt; # if t0 == t1 then target


B1:
nop
nop
nop
nop
nop
B2:
nop
nop
nop
nop
nop
nop
nop

halt:
    slti x0, x0, -256
