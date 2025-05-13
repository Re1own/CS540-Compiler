
abs:
	addi $sp, $sp, -100
	sw $ra, 96($sp)
	sw $a0, 36($sp)
	lw $t0, 36($sp)
	li $t1, 0
	slt $t2, $t0, $t1
	beqz $t2, L0
	li $t0, 0
	lw $t1, 36($sp)
	sub $t0, $t0, $t1
	sw $t0, 52($sp)
	j L1
L0:
	lw $t0, 36($sp)
	sw $t0, 52($sp)
L1:
	lw $t0, 52($sp)
	move $v0, $t0
	j abs_ret
	abs_ret:
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
	li $t1, 5
	sub $t0, $t0, $t1
	move $a0, $t0
	sw $t0, toyger_main_t_regs+0
	jal abs
	lw $t0, toyger_main_t_regs+0
	move $t0, $v0
	sw $t0, gvar_y
	lw $t0, gvar_y
	li $v0, 1
	move $a0, $t0
	syscall
.data
.align 2
gvar_y: .word 0
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
