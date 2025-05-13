# Toyger Compiler

This repository contains a toy compiler for a small language called **Toyger**, which generates MIPS assembly as its output. Below are various specifications (lexical, syntax, semantics), restrictions, and instructions on how to run the resulting assembly in the **MARS** simulator.

---

## 1. Toyger Language Overview

### 1.1 Lexical Specification

Toyger tokens include **keywords**, **punctuation elements**, **operators**, **IDs**, **integers**, **strings**, and **comments**.

- **Keywords**:  
  `let`, `in`, `end`, `var`, `function`, `printint`, `printstring`, `getint`, `return`, `if`, `then`, `else`, `for`, `do`, `to`, `int`, `string`, `void`

- **Punctuation**:  
  `(` `)` `:` `,` `=` `;`

- **Operators**:  
  - **Assignment**: `:=`  
  - **Arithmetic**: `+`, `-`, `*`, `/`  
  - **Comparison**: `==` (equality), `<`, `<=`, `>`, `>=`, `<>` (not equal)

- **Identifiers (ID)**:  
  Any non-empty sequence of letters (`a-z`, `A-Z`), digits (`0-9`), or underscores (`_`), **starting with** a letter or underscore, and **not** a keyword.

- **Numbers**:  
  Integers (decimal) with no redundant leading zeros.

- **Strings**:  
  A possibly empty sequence of characters between a pair of quotes (`"`).  
  - A string cannot span multiple lines.  
  - A literal quote `"` can appear via C-style escape format `\"`.

- **Comments**:  
  Start with double slash `//` until the end of the line or file. (Within a string, `//` loses its special meaning.)

**Notes**:

- Toyger is *case-sensitive*.
- Whitespace (space, tab, newline) can appear as delimiters but are not tokens themselves.
- Comments are recognized by the scanner but not reported to the parser.

---

### 1.2 Syntax Specification

A Toyger program consists of **declarations** followed by a sequence of statements.

program -> let decs in statements end
decs -> dec decs | ε
dec -> var_dec | function_dec
var_dec -> var ID : type
function_dec -> function ID (params) : type = local_dec statements end
| function ID () : type = local_dec statements end
local_dec -> let var_decs in | ε
var_decs -> var_decs var_dec | ε
params -> params , parameter | parameter
parameter -> ID : type
statements -> statements ; statement | statement
statement -> assignment_stmt | print_stmt | input_stmt
| if_stmt | for_stmt | call_stmt | return_stmt

assignment_stmt -> ID := expr
input_stmt -> ID := getint()
return_stmt -> return expr | return
call_stmt -> ID () | ID ( expr_list )
print_stmt -> printint ( expr ) | printstring ( expr )

rel_expr -> expr == expr | expr <> expr | expr < expr | expr <= expr
| expr > expr | expr >= expr
if_stmt -> if ( rel_expr ) then statements end
| if ( rel_expr ) then statements else statements end
for_stmt -> for ID := expr to expr do statements end

expr -> expr + term | expr - term | term
term -> term * factor | term / factor | factor
factor -> ( expr ) | NUMBER | STRING | ID | call_stmt
expr_list -> expr_list , expr | expr

pgsql
Copy

- Spaces shown in grammar rules are not required from the input—they’re there for clarity.
- Comments (starting with `//`) are ignored by the parser.

---

### 1.3 Semantic Rules

- **Scoping**:  
  - Global names (functions/variables) are visible after declaration until the end of the file.  
  - Each function introduces a local scope for parameters + local vars.  
  - No nested function definitions. Only top-level functions + their local declarations.

- **ID Definitions**:
  - A function must be declared before it can be called.
  - A variable must be declared before it is used.
  - An ID may not be declared twice in the same scope.
  - A local variable can shadow a global name with the same ID.

- **Types**:
  - Variables: `int` or `string`.
  - For this project, function parameters and return can be treated as integers (though grammar might allow `string` or `void`).
  - We do not allow more than four parameters to a function.

- **For-Statement**:  
  for ID := expr1 to expr2 do statements end

makefile
Copy
Pseudocode:
ID := expr1
while (ID <= expr2) {
statements
ID := ID + 1
}

markdown
Copy

---

## 2. MIPS as Intermediate Code

Our compiler generates MIPS code using:

- **Temporary registers** `$t0..$t7`.  
- `$ra`, `$a0..$a3`, and `$v0` if required by calling convention (for function calls and returns).
- All data in word size (32 bits).
- Comments start with `#`.
- `.data` and `.text` directives separate data definitions and instructions.

### 2.1 Addressing & Instructions

Common **addressing** forms we use:

- `lw reg, var` : load 32-bit word from label `var` into `reg`
- `sw reg, var` : store contents of `reg` into memory labeled `var`
- `la reg, var` : load the address of label `var` into `reg`
- `li reg, imm` : load an immediate integer `imm` into `reg`
- `move r1, r2` : copy `r2` into `r1`

Common **instructions**:

- **Arithmetic**: `add`, `sub`, `mul`, `div`, `neg`

- **Comparisons**: `seq`, `sne`, `slt`, `sle`, `sgt`, `sge`

- **Branch/Jump**: `j label`, `beqz reg, label`, `bnez reg, label`, `jal label`, `jr reg`

- **Syscall**: used for I/O

- Print integer:

  ```asm
  li   $v0, 1
  move $a0, $tX
  syscall
  ```

- Print string:

  ```asm
  li   $v0, 4
  move $a0, $tX
  syscall
  ```

- Read integer:

  ```asm
  li   $v0, 5
  syscall
  # result in $v0
  ```

### 2.2 Calling Conventions

- Up to 4 parameters in `$a0..$a3`.
- Return value in `$v0`.
- `$ra` is used to store return address for `jal`.
- `$t0..$t7` are caller-save registers (the caller must save them if needed).

---

### 3.1 Example Usage

there are 17 tests(test0-16), you can run:

 ```bash
./test.sh test1
 ```

output:

```sh
Test with test1.tog:
-------------------------------------------------------------
 - Use your compiler (toyger) to generate MIPS translation: test1.s
-------------------------------------------------------------
Input Accepted - MIPS Generation Completed

-------------------------------------------------------------
 - Verify generated MIPS assembles and runs under MARS
-------------------------------------------------------------
Running MIPS code your compiler generated (./my_output/test1.s):

MARS 4.5  Copyright 2003-2014 Pete Sanderson and Kenneth Vollmar

Hello World!


Done.
```

