ebr.s:
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # EBR

    # This test is NOT exhaustive
_start:

li x1, 10
li x2, 20
li x5, 50
li x6, 60
li x8, 21
li x9, 28
li x11, 8
li x12, 4
li x14, 3
li x15, 1

bne x1,x1, label5
lw x16, LOAD_TEST   #try load 
sw x17, 0(x16)       # 
lw x17, 0(x16)
# add x1,x1,x1
# add x1,x1,x1 #should be flushed 
mul x4,x5,x1
bne x1,x1, label5 #44
lw x16, LOAD_TEST   #try load 
sw x17, 0(x16)       # 
lw x17, 0(x16)

bne x1,x2, label5
add x1,x1,x1
add x1,x1,x1 #should be flushed 
 

label1:
   jal x5, halt
label2:
    add x4,x5,x6
label3:
    add x3,x4,x5
label4:
    add x0,x0,x0
label5:
    nop
    nop
    nop
    j label1
    nop
    nop
    nop
    nop
halt:
    slti x0, x0, -256


.data   
LOAD_TEST: .word 0x1ecef128

