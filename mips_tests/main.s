.globl main
.text
main:
      jal toyger_main
      move $a0, $v0
      li $v0,17
      syscall

