
.data
global_x: .word 0

.text

.text
.globl toyger_main
toyger_main:

	li $t0, 5

	li $t1, 8
	mul $t0, $t0, $t1

	li $t1, 3

	li $t2, 2
	mul $t1, $t1, $t2
	sub $t0, $t0, $t1

	sw $t0, global_x

	lw $t0, global_x

	li $v0, 1
	move $a0, $t0
	syscall
toyger_main_end:
	jr $ra
