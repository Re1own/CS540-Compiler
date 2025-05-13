
.data
global_i: .word 0

.text

.data
global_p: .word 0

.text

.text
.globl toyger_main
toyger_main:

	li $t0, 1

	sw $t0, global_p

	li $t0, 1

	sw $t0, global_i
L0:

	li $t0, 5

	lw $t1, global_i

	sle $t1, $t1, $t0

	beqz $t1, L1

	lw $t0, global_p

	lw $t1, global_i
	mul $t0, $t0, $t1

	sw $t0, global_p

	lw $t0, global_i
	addi $t0, $t0, 1
	sw $t0,global_i
	j L0
L1:

	lw $t0, global_p

	li $v0, 1
	move $a0, $t0
	syscall
toyger_main_end: jr $ra
