
my_print:
	addi $sp, $sp, -100
	sw $ra, 96($sp)
	sw $a0, 36($sp)
	lw $t0, 36($sp)
	li $t1, 40
	add $t0, $t0, $t1
	li $v0, 1
	move $a0, $t0
	syscall
	lw $t0, 36($sp)
	li $t1, 40
	sub $t0, $t0, $t1
	li $v0, 1
	move $a0, $t0
	syscall
	my_print_ret:
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
	li $t0, 400
	move $a0, $t0
	sw $t0, toyger_main_t_regs+0
	jal my_print
	lw $t0, toyger_main_t_regs+0
	move $t0, $v0
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
