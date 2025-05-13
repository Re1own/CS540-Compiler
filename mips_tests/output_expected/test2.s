
.text
.globl toyger_main
toyger_main:

	li $t0, 440

	li $v0, 1
	move $a0, $t0
	syscall
toyger_main_end:
	jr $ra
