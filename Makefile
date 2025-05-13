# Makefile
# Usage:
#   make        (builds the compiler 'toyger')
#   make clean  (cleans generated files)

toyger: toyger.y toyger.l
	bison -d toyger.y
	flex toyger.l
	gcc toyger.tab.c lex.yy.c -o toyger -lfl

clean:
	rm -f toyger *.o *.tab.c *.tab.h lex.yy.c
