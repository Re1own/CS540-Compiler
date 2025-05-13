
.data
global_x: .word 0

.text

.text
.globl toyger_main
toyger_main:

.data
str0: .asciiz "enter an integer: "

.text
	la $t0, str0

	li $v0, 4
	move $a0, $t0
	syscall

	li $v0,5
	syscall
	sw $v0,global_x

	lw $t0, global_x

	li $t1, 3
	sgt $t0, $t0, $t1

	beqz $t0, L0
.data
str1: .asciiz ">3"

.text
	la $t1, str1

	li $v0, 4
	move $a0, $t1
	syscall
j L1
L0:

.data
str2: .asciiz "<=3"

.text
	la $t1, str2

	li $v0, 4
	move $a0, $t1
	syscall
L1:
toyger_main_end:
	jr $ra
