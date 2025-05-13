.data
	toyger_main_ret_addr: .word 0
	toyger_main_t_regs: .space 40
.text
.globl toyger_main
toyger_main:
	sw $ra, toyger_main_ret_addr
	li $t0, 1
	sw $t0, gvar_p
	li $t0, 1
	li $t1, 5
	sw $t0, gvar_i
L0:
	lw $t0, gvar_i
	sle $t2, $t0, $t1
	beqz $t2, L1
	lw $t0, gvar_p
	lw $t2, gvar_i
	mul $t0, $t0, $t2
	sw $t0, gvar_p
	lw $t0, gvar_i
	addi $t0, $t0, 1
	sw $t0, gvar_i
	j L0
L1:
	lw $t0, gvar_p
	li $v0, 1
	move $a0, $t0
	syscall
.data
.align 2
gvar_i: .word 0
gvar_p: .word 0
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
