br_jmp_test.s:
.align 4
.section .text
.globl _start


_start:

# initialize
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

# Branch if equal
beq x1, x2, label1
nop
nop

# Branch if not equal
bne x1, x2, label2
nop
nop

# Branch if less than
blt x1, x2, label3
nop
nop

# Branch if greater than or equal
bge x2, x1, label4
nop
nop

# Jump and link
jal x5, label5
nop
nop

# Jump and link register
jalr x6, x7, 0
nop
nop

label1:
    add x1, x1, x2
    j end

label2:
    sub x2, x2, x1
    j end

label3:
    mul x3, x3, x4
    j end

label4:
    div x4, x4, x3
    j end

label5:
    and x5, x5, x6
    j end

end:
    halt:
        slti x0, x0, -256