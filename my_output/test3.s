.data
	toyger_main_ret_addr: .word 0
	toyger_main_t_regs: .space 40
.text
.globl toyger_main
toyger_main:
	sw $ra, toyger_main_ret_addr
	li $t0, 5
	li $t1, 8
	mul $t0, $t0, $t1
	li $t1, 3
	li $t2, 2
	mul $t1, $t1, $t2
	sub $t0, $t0, $t1
	li $v0, 1
	move $a0, $t0
	syscall
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
