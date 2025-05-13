.data
	toyger_main_ret_addr: .word 0
	toyger_main_t_regs: .space 40
.text
.globl toyger_main
toyger_main:
	sw $ra, toyger_main_ret_addr
	j toyger_main_end
toyger_main_end:
	lw $ra, toyger_main_ret_addr
	jr $ra
