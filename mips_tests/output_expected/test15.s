
.data
global_y: .word 0

.text
.text
abs:

	addi $sp, $sp, -100

	sw $ra, 96($sp)
	sw $a0, 80($sp)

	lw $t0, 80($sp)

	li $t1, 0
	slt $t0, $t0, $t1

	beqz $t0, L0
	li $t0, 0

	lw $t1, 80($sp)
	sub $t0, $t0, $t1

	sw $t0, 36($sp)

	j L1
L0:

	lw $t0, 80($sp)

	sw $t0, 36($sp)
L1:

	lw $t0, 36($sp)

	move $v0, $t0

	j abs_end

abs_end:
	lw $ra, 96($sp)
	addi $sp, $sp, 100
	jr $ra

.text
.globl toyger_main
toyger_main:

	addi $sp, $sp, -100

	sw $ra, 96($sp)
	li $t0, 0

	li $t1, 5
	sub $t0, $t0, $t1

	move $a0, $t0

	sw $t0, 4($sp)
	sw $t1, 8($sp)
	sw $t2, 12($sp)
	sw $t3, 16($sp)
	sw $t4, 20($sp)
	sw $t5, 24($sp)
	sw $t6, 28($sp)
	sw $t7, 32($sp)
	jal abs

	lw $t0, 4($sp)
	lw $t1, 8($sp)
	lw $t2, 12($sp)
	lw $t3, 16($sp)
	lw $t4, 20($sp)
	lw $t5, 24($sp)
	lw $t6, 28($sp)
	lw $t7, 32($sp)
	move $t0, $v0

	sw $t0, global_y

	lw $t0, global_y

	li $v0, 1
	move $a0, $t0
	syscall

toyger_main_end:
	lw $ra, 96($sp)
	addi $sp, $sp, 100
	jr $ra
