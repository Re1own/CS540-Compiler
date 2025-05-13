
.text
.globl toyger_main
toyger_main:

.data
str0: .asciiz "Hello World!\n"

.text
	la $t0, str0

	li $v0, 4
	move $a0, $t0
	syscall
toyger_main_end:
	jr $ra
