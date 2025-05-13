.text
f:

	addi $sp, $sp, -100

	sw $ra, 96($sp)
	sw $a0, 80($sp)

	lw $t0, 80($sp)

	li $t1, 40
	add $t0, $t0, $t1

	move $v0, $t0

	j f_end

f_end:
	lw $ra, 96($sp)
	addi $sp, $sp, 100
	jr $ra

.text
.globl toyger_main
toyger_main:

	addi $sp, $sp, -100

	sw $ra, 96($sp)
	li $t0, 200

	move $a0, $t0

	sw $t0, 4($sp)
	sw $t1, 8($sp)
	sw $t2, 12($sp)
	sw $t3, 16($sp)
	sw $t4, 20($sp)
	sw $t5, 24($sp)
	sw $t6, 28($sp)
	sw $t7, 32($sp)
	jal f

	lw $t0, 4($sp)
	lw $t1, 8($sp)
	lw $t2, 12($sp)
	lw $t3, 16($sp)
	lw $t4, 20($sp)
	lw $t5, 24($sp)
	lw $t6, 28($sp)
	lw $t7, 32($sp)
	move $t0, $v0

	li $t1, 200
	add $t0, $t0, $t1

	li $v0, 1
	move $a0, $t0
	syscall

toyger_main_end:
	lw $ra, 96($sp)
	addi $sp, $sp, 100
	jr $ra
