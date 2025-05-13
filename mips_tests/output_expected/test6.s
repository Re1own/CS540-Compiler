
.data
global_x: .word 0

.text

.data
global_y: .word 0

.text

.text
.globl toyger_main
toyger_main:

	li $t0, 5

	sw $t0, global_x

	lw $t0, global_x

	li $t1, 2
	mul $t0, $t0, $t1

	sw $t0, global_y

	lw $t0, global_y

	li $v0, 1
	move $a0, $t0
	syscall
toyger_main_end:
	jr $ra
