.data
	toyger_main_ret_addr: .word 0
	toyger_main_t_regs: .space 40
.text
.globl toyger_main
toyger_main:
	sw $ra, toyger_main_ret_addr
	la $t0, str0
	li $v0, 4
	move $a0, $t0
	syscall
	li $v0, 5
	syscall
	sw $v0, gvar_x
	lw $t0, gvar_x
	li $v0, 1
	move $a0, $t0
	syscall
.data
.align 2
str0: .asciiz "enter an integer:"
gvar_x: .word 0
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
