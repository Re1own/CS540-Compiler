.text
my_print:
.data
	my_print_ret_addr:.word 0
.text
	sw $ra, my_print_ret_addr
.data
	my_print_t_regs:.space 40
.text

.data
my_print_x: .word 0

.text
	 sw $a0, my_print_x

	lw $t0, my_print_x

	li $t1, 40
	add $t0, $t0, $t1

	li $v0, 1
	move $a0, $t0
	syscall

	lw $t0, my_print_x

	li $t1, 40
	sub $t0, $t0, $t1

	li $v0, 1
	move $a0, $t0
	syscall

my_print_end:
	lw $ra, my_print_ret_addr
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

	li $t0, 400

	move $a0, $t0

	sw $t0, toyger_main_t_regs+0
	sw $t1, toyger_main_t_regs+4
	sw $t2, toyger_main_t_regs+8
	sw $t3, toyger_main_t_regs+12
	sw $t4, toyger_main_t_regs+16
	sw $t5, toyger_main_t_regs+20
	sw $t6, toyger_main_t_regs+24
	sw $t7, toyger_main_t_regs+28
	jal my_print

	lw $t0, toyger_main_t_regs+0
	lw $t1, toyger_main_t_regs+4
	lw $t2, toyger_main_t_regs+8
	lw $t3, toyger_main_t_regs+12
	lw $t4, toyger_main_t_regs+16
	lw $t5, toyger_main_t_regs+20
	lw $t6, toyger_main_t_regs+24
	lw $t7, toyger_main_t_regs+28
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
