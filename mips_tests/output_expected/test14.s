.text
get10:
.data
	get10_ret_addr:.word 0
.text
	sw $ra, get10_ret_addr
.data
	get10_t_regs:.space 40
.text

.data
get10_x: .word 0

.text

	li $t0, 10

	sw $t0, get10_x

	lw $t0, get10_x

	move $v0, $t0

	j get10_end

get10_end:
	lw $ra, get10_ret_addr
	jr $ra

.text
.globl toyger_main
toyger_main:
.data
	toyger_main_ret_addr:.word 0
.text
	sw $ra, toyger_main_ret_addr
.data
	toyger_main_t_regs:.space 40
.text

	sw $t0, toyger_main_t_regs+0
	sw $t1, toyger_main_t_regs+4
	sw $t2, toyger_main_t_regs+8
	sw $t3, toyger_main_t_regs+12
	sw $t4, toyger_main_t_regs+16
	sw $t5, toyger_main_t_regs+20
	sw $t6, toyger_main_t_regs+24
	sw $t7, toyger_main_t_regs+28
	jal get10

	lw $t0, toyger_main_t_regs+0
	lw $t1, toyger_main_t_regs+4
	lw $t2, toyger_main_t_regs+8
	lw $t3, toyger_main_t_regs+12
	lw $t4, toyger_main_t_regs+16
	lw $t5, toyger_main_t_regs+20
	lw $t6, toyger_main_t_regs+24
	lw $t7, toyger_main_t_regs+28
	move $t0, $v0

	li $v0, 1
	move $a0, $t0
	syscall

toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
