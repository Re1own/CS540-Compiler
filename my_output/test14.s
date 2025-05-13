
get10:
	addi $sp, $sp, -100
	sw $ra, 96($sp)
	li $t0, 10
	sw $t0, 52($sp)
	lw $t0, 52($sp)
	move $v0, $t0
	j get10_ret
	get10_ret:
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
	# call get10 with no args
	jal get10
	move $t0, $v0
	li $v0, 1
	move $a0, $t0
	syscall
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
