
.text
.globl toyger_main
toyger_main:

	li $t0, 5

	li $t1, 3
	sgt $t0, $t0, $t1

	beqz $t0, L0
	li $t1, 5

	li $v0, 1
	move $a0, $t1
	syscall
L0:
toyger_main_end:
	jr $ra
