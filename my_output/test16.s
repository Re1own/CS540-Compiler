
fact:
	addi $sp, $sp, -100
	sw $ra, 96($sp)
	sw $a0, 36($sp)
	lw $t0, 36($sp)
	li $t1, 1
	slt $t2, $t0, $t1
	beqz $t2, L0
	li $t0, 1
	move $v0, $t0
	j fact_ret
	j L1
L0:
	lw $t0, 36($sp)
	lw $t1, 36($sp)
	li $t3, 1
	sub $t1, $t1, $t3
	move $a0, $t1
	sw $t0, toyger_main_t_regs+0
	sw $t1, toyger_main_t_regs+4
	sw $t2, toyger_main_t_regs+8
	jal fact
	lw $t0, toyger_main_t_regs+0
	lw $t1, toyger_main_t_regs+4
	lw $t2, toyger_main_t_regs+8
	move $t1, $v0
	mul $t0, $t0, $t1
	move $v0, $t0
	j fact_ret
L1:
	fact_ret:
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
	li $t0, 6
	move $a0, $t0
	sw $t0, toyger_main_t_regs+0
	jal fact
	lw $t0, toyger_main_t_regs+0
	move $t0, $v0
	li $v0, 1
	move $a0, $t0
	syscall
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
