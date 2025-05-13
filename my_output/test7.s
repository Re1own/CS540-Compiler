.data
	toyger_main_ret_addr: .word 0
	toyger_main_t_regs: .space 40
.text
.globl toyger_main
toyger_main:
	sw $ra, toyger_main_ret_addr
	li $t0, 5
	li $t1, 3
	sgt $t2, $t0, $t1
	beqz $t2, L0
	li $t0, 5
	li $v0, 1
	move $a0, $t0
	syscall
L0:
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
