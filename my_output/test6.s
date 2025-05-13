.data
	toyger_main_ret_addr: .word 0
	toyger_main_t_regs: .space 40
.text
.globl toyger_main
toyger_main:
	sw $ra, toyger_main_ret_addr
	li $t0, 5
	sw $t0, gvar_x
	lw $t0, gvar_x
	li $t1, 2
	mul $t0, $t0, $t1
	sw $t0, gvar_y
	lw $t0, gvar_y
	li $v0, 1
	move $a0, $t0
	syscall
.data
.align 2
gvar_x: .word 0
gvar_y: .word 0
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
