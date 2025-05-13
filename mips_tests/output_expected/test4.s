
.data
global_x: .word 0

.text

.text
.globl toyger_main
toyger_main:

.data
str0: .asciiz "enter an integer:"

.text
	la $t0, str0

	li $v0, 4
	move $a0, $t0
	syscall

	li $v0,5
	syscall
	sw $v0,global_x

	lw $t0, global_x

	li $v0, 1
	move $a0, $t0
	syscall
toyger_main_end:
	jr $ra
