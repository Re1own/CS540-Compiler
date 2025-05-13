
f:
	addi $sp, $sp, -100
	sw $ra, 96($sp)
	li $t0, 1
	li $v0, 1
	move $a0, $t0
	syscall
	f_ret:
	lw $ra, 96($sp)
	addi $sp, $sp, 100
	jr $ra
.data
	toyger_main_ret_addr: .word 0
	toyger_main_t_regs: .space 40
.text
.globl toyger_main
toyger_main:
	sw $ra, toyger_main_ret_addr
	li $t0, 0
	li $v0, 1
	move $a0, $t0
	syscall
	# call f with no args
	jal f
	move $t0, $v0
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
