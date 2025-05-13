/* toyger.y */
/*
   A simple compiler front-end using Bison that directly generates MIPS assembly.
   It demonstrates:
    - Symbol table for global/local variables
    - Function calls (with up to 4 parameters)
    - Expressions, if/else, for loops
    - MIPS .data section (strings & global vars)
    - Basic stack frame usage for functions
*/

%{
#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Bison external references */
extern int yylineno;
extern char *yytext;
int yyerror(const char *s);
extern int yylex();

/* We define data structures for symbol table, scope, register management, etc. */

/* Scope types for variables: global, param, or local */
typedef enum { GLOBAL_SCOPE, PARAM_SCOPE, LOCAL_SCOPE } ScopeType;

/* Variable location type in MIPS: global label or stack offset */
typedef enum { VAR_LOC_GLOBAL, VAR_LOC_STACK } VarLocationType;

/* SymbolInfo: how to locate this variable in generated code */
typedef struct {
    VarLocationType loc_type;  
    union {
        char *global_label;   
        int stack_offset;     
    } location;
} SymbolInfo;

/* Linked list node for symbol table */
typedef struct SymbolNode {
    char *name;           /* variable/function name */
    ScopeType scope;      /* global, param, local */
    SymbolInfo info;      /* how to find it in MIPS */
    struct SymbolNode *next;
} SymbolNode;

/* Global pointer to the symbol table (linked list).
   'symbol_table_head' stores the top-most scope, 'global_symbol_head' used for .data output. */
SymbolNode *symbol_table_head = NULL;
SymbolNode *global_symbol_head = NULL;

/* We'll keep track of errors */
int error_count = 0;

/* 
   We define some constants for stack frame size, 
   as well as the offset for saving RA, temporary registers, etc.
*/
#define NUM_TEMP_REGS 8
#define FRAME_SIZE 100
#define RA_OFFSET (FRAME_SIZE - 4)
#define TEMP_REG_SAVE_OFFSET 4
#define ARG_REG_SAVE_OFFSET (TEMP_REG_SAVE_OFFSET + NUM_TEMP_REGS * 4)
#define LOCAL_VAR_START_OFFSET (ARG_REG_SAVE_OFFSET + 4 * 4)

/* We'll keep a label counter for generating unique labels (L0, L1, ...) */
int label_count = 0;
char* new_label() {
    char buf[32];
    sprintf(buf, "L%d", label_count++);
    char* label = strdup(buf);
    if(!label) exit(EXIT_FAILURE);
    return label;
}

/* Temporary registers usage management ($t0..$t7) */
int temp_reg_available[NUM_TEMP_REGS];
int temp_reg_save_needed[NUM_TEMP_REGS];
void init_registers() {
    for(int i=0; i<NUM_TEMP_REGS; i++){
        temp_reg_available[i] = 0;  /* 0 means free */
        temp_reg_save_needed[i] = 0;
    }
}

/* Get a free temp register index. If none available, report error. */
int get_register() {
    for(int i=0; i<NUM_TEMP_REGS; i++){
        if(temp_reg_available[i] == 0){
            temp_reg_available[i] = 1; /* mark as used */
            return i;
        }
    }
    fprintf(stderr, "Error: Out of temp regs on line %d!\n", yylineno);
    error_count++;
    return -1;
}

/* Release a temp register */
void free_register(int r) {
    if(r >= 0 && r < NUM_TEMP_REGS) {
        temp_reg_available[r] = 0; /* mark as free */
    } else if(r != -1) {
        fprintf(stderr, "Warning: free invalid reg %d on line %d\n", r, yylineno);
    }
}

/* We'll store string literals in a linked list so we can output them in .data. */
typedef struct StringNode {
    char* label;
    char* value;
    struct StringNode* next;
} StringNode;
StringNode* string_list_head = NULL;
int string_label_count = 0;

/* Print a string with escaped chars turned into actual escape sequences in MIPS. */
void print_escaped_string(const char* src){
    while(*src){
        switch(*src){
            case '\n':printf("\\n");break;
            case '\t':printf("\\t");break;
            case '\\':printf("\\\\");break;
            case '"':printf("\\\"");break;
            default: putchar(*src);break;
        }
        src++;
    }
}

/* Add a new string literal to the list if it's not already in. Return the label. */
const char* add_string_literal(const char* val) {
    StringNode* cur = string_list_head;
    while(cur){
        if(strcmp(cur->value, val)==0) return cur->label;
        cur=cur->next;
    }
    StringNode* new_node = (StringNode*)malloc(sizeof(*new_node));
    if(!new_node) exit(EXIT_FAILURE);

    char buf[32];
    sprintf(buf, "str%d", string_label_count++);
    new_node->label = strdup(buf);
    new_node->value = strdup(val);
    new_node->next  = string_list_head;
    string_list_head = new_node;

    return new_node->label;
}

/* Print the .data section for string literals and global variables. */
int print_data_section(){
    int data_printed = 0;
    if(string_list_head){
        printf(".data\n.align 2\n");
        data_printed=1;
        StringNode* c = string_list_head;
        while(c){
            printf("%s: .asciiz \"", c->label);
            print_escaped_string(c->value);
            printf("\"\n");
            c = c->next;
        }
    }
    if(global_symbol_head){
        if(!data_printed){
            printf(".data\n.align 2\n");
            data_printed=1;
        }
        /* Reverse the global symbol list so we print in declaration order. */
        SymbolNode* cur=global_symbol_head,*prev=NULL,*nx=NULL;
        while(cur){
            nx=cur->next; 
            cur->next=prev; 
            prev=cur; 
            cur=nx;
        }
        global_symbol_head=prev;
        cur=global_symbol_head;
        while(cur){
            /* .word for integer global variables (MARS compatibility) */
            printf("%s: .word 0\n", cur->info.location.global_label);
            cur=cur->next;
        }
    }
    return data_printed;
}

/* Free the string literal list (cleanup). */
void free_string_literals(){
    StringNode* cur;
    while(string_list_head){
        cur=string_list_head;
        string_list_head=string_list_head->next;
        free(cur->label);
        free(cur->value);
        free(cur);
    }
}

/* We'll keep track of the current function name, local offset, param index. */
char* current_function_name=NULL;
int current_local_offset= LOCAL_VAR_START_OFFSET;
int current_param_index=0;

/* Enter scope for a function => reset offset, param index. */
void enter_scope(const char* func_name){
   current_function_name = strdup(func_name);
   current_local_offset = LOCAL_VAR_START_OFFSET;
   current_param_index = 0;
}

/* Exit scope => remove all local symbols from the symbol table. */
void exit_scope(){
   SymbolNode* cur = symbol_table_head;
   while(cur && cur->scope != GLOBAL_SCOPE){
     SymbolNode* tmp=cur;
     cur=cur->next;
     free(tmp->name);
     free(tmp);
   }
   symbol_table_head=cur;
   free(current_function_name);
   current_function_name=NULL;
}

/* Generate a label for a global variable in .data. */
char* generate_global_mips_label(const char* var_name){
   char* label = malloc(strlen("gvar_")+strlen(var_name)+1);
   if(!label) exit(EXIT_FAILURE);
   sprintf(label, "gvar_%s", var_name);
   return label;
}

/* Symbol table cleanup: free local and global separately. */
void free_symbol_table(){
   SymbolNode* cur;
   /* free local scope nodes */
   while(symbol_table_head && symbol_table_head->scope!=GLOBAL_SCOPE){
     cur=symbol_table_head;
     symbol_table_head=symbol_table_head->next;
     free(cur->name);
     free(cur);
   }
   /* free global symbol nodes */
   while(global_symbol_head){
     cur=global_symbol_head;
     global_symbol_head=global_symbol_head->next;
     free(cur->info.location.global_label);
     free(cur->name);
     free(cur);
   }
   symbol_table_head=NULL;
}

/* Insert a new symbol into the symbol_table_head. Also, if it's global, into global_symbol_head. */
void insert_symbol(const char* name, ScopeType scope, SymbolInfo info){
   SymbolNode* cur=symbol_table_head;

   /* Check redeclaration in the same scope. */
   while(cur && (cur->scope!=GLOBAL_SCOPE || scope==GLOBAL_SCOPE)){
     if(cur->scope==scope && strcmp(cur->name,name)==0){
       fprintf(stderr, "Semantic Error: Line %d: Redeclaration of variable '%s'\n", yylineno, name);
       error_count++;
       if(scope==PARAM_SCOPE) free((char*)name);
       if(scope==GLOBAL_SCOPE && info.loc_type==VAR_LOC_GLOBAL) free(info.location.global_label);
       return;
     }
     if(current_function_name && cur->scope==GLOBAL_SCOPE && scope!=GLOBAL_SCOPE) break;
     cur=cur->next;
   }

   /* Create the new node and link it in. */
   SymbolNode* new_node=(SymbolNode*)malloc(sizeof(SymbolNode));
   if(!new_node) exit(EXIT_FAILURE);
   new_node->name=(char*)name;
   new_node->scope=scope;
   new_node->info=info;
   new_node->next=symbol_table_head;
   symbol_table_head=new_node;

   /* If global => also keep in global_symbol_head. */
   if(scope==GLOBAL_SCOPE){
     SymbolNode* g_node=malloc(sizeof(SymbolNode));
     if(!g_node) exit(EXIT_FAILURE);
     g_node->name=strdup(new_node->name);
     g_node->scope=new_node->scope;
     g_node->info.loc_type=new_node->info.loc_type;
     g_node->info.location.global_label=new_node->info.location.global_label;
     g_node->next=global_symbol_head;
     global_symbol_head=g_node;
   }
}

/* Lookup symbol in the entire symbol table (local shadows global). */
SymbolNode* lookup_symbol(const char* name){
   SymbolNode* cur=symbol_table_head;
   while(cur){
     if(strcmp(cur->name, name)==0) return cur;
     cur=cur->next;
   }
   fprintf(stderr,"Semantic Error: Line %d: Undeclared variable '%s'\n", yylineno, name);
   error_count++;
   return NULL;
}

%}

/* Bison union: used to hold different semantic values. */
%union {
    int ival;
    char* sval;

    /* For expressions, store: reg index + is_address flag (0= int, 1= address) */
    struct {
      int reg;        
      int is_address; 
    } exprinfo;

    /* Parameter list for function declarations */
    struct ParamNode {
       char* name;
       struct ParamNode* next;
    } *paramlist;

    /* Expression list for function calls */
    struct ExprListNode {
       int reg;
       struct ExprListNode* next;
    } *exprlist;

    /* if_stmt auxiliary data */
    struct IfLabels {
      int cond_reg;     
      char* else_label; 
      char* end_label;
    } iflab;

    /* for_stmt auxiliary data */
    struct ForData {
       char* loop_start;
       char* loop_end;
       struct SymbolNode* sym_i; /* i symbol */
       int end_reg;             /* reg for 'to' expression */
    } forinfo;
}

/* Bison tokens */
%token <ival> NUMBER
%token <sval> ID STRING
%token ADD MINUS MUL DIV EQ LT LE GT GE ASSIGN NE
%token LET IN END VAR FUNCTION IF THEN ELSE FOR TO DO PRINTINT GETINT PRINTSTRING RETURN INT_TYPE STRING_TYPE VOID
%token LP RP COLON COMMA SEQ SEMICOLON

%type <exprinfo> expr term factor call_stmt
%type <ival> rel_expr
%type <paramlist> parameters parameter
%type <exprlist> expr_list
%type <iflab> if_no_else if_with_else if_cond_part
%type <forinfo> for_head for_stmt_stub

%%

/* program => let decs in statements end */
program
  : { init_registers(); }
    LET decs IN
    {
      /* Here we treat 'toyger_main' as our main function. We do some .data placeholders. */
      printf(".data\n");
      printf("\ttoyger_main_ret_addr: .word 0\n");
      printf("\ttoyger_main_t_regs: .space 40\n"); /* store $t0..t7 if needed */
      printf(".text\n.globl toyger_main\n");
      printf("toyger_main:\n");
      printf("\tsw $ra, toyger_main_ret_addr\n");
    }
    statements
    END
    {
      /* after statements, print the rest of data section for global vars and strings */
      print_data_section();
      /* toyger_main end => restore ra, return */
      printf("toyger_main_end:\n");
      printf("\tlw $ra, toyger_main_ret_addr\n");
      printf("\tjr $ra\n");
    }
  ;

/* decs => dec decs | empty */
decs
  : dec decs
  | /* empty */
  ;

/* dec => var_dec | function_dec */
dec
  : var_dec
  | function_dec
  ;

/* var_dec => var ID : type */
var_dec
  : VAR ID COLON type
    {
      SymbolInfo info;
      if(!current_function_name){
        /* global var => allocate a label in .data */
        info.loc_type = VAR_LOC_GLOBAL;
        info.location.global_label = generate_global_mips_label($2);
        insert_symbol($2, GLOBAL_SCOPE, info);
      } else {
        /* local var => use stack offset */
        info.loc_type = VAR_LOC_STACK;
        info.location.stack_offset = current_local_offset;
        insert_symbol($2, LOCAL_SCOPE, info);
        current_local_offset += 4;
      }
    }
  ;

/* type => int_type or string_type or void */
type
  : INT_TYPE
  | STRING_TYPE
  | VOID
  ;

/* function_dec => "function id (param) : type = {...} end"  */
function_dec
  : FUNCTION ID LP parameters RP COLON type SEQ
    {
      /* Start function => enter scope, create label */
      char* fname=$2;
      enter_scope(fname);
      printf("\n%s:\n", fname);
      /* create stack frame */
      printf("\taddi $sp, $sp, -%d\n", FRAME_SIZE);
      printf("\tsw $ra, %d($sp)\n", RA_OFFSET);

      /* store parameters from $a0..$a3 to local stack offsets */
      {
        struct ParamNode* p = $4;
        int param_idx=0;
        /* reverse the param list so the first declared param is loaded from $a0, etc. */
        struct ParamNode* head = p,*prev=NULL,*nx=NULL;
        while(head){
          nx=head->next;
          head->next=prev;
          prev=head;
          head=nx;
        }
        p=prev;
        while(p){
          SymbolNode* sym = lookup_symbol(p->name);
          if(sym && sym->scope==PARAM_SCOPE){
             printf("\tsw $a%d, %d($sp)\n", param_idx, sym->info.location.stack_offset);
          }
          param_idx++;
          p=p->next;
        }
        /* free param chain nodes */
        p=prev;
        while(p){
          struct ParamNode* tmp=p;
          p=p->next;
          free(tmp);
        }
      }
    }
    local_dec statements END
    {
      /* function end => restore ra, pop frame, jr ra */
      printf("\t%s_ret:\n", current_function_name);
      printf("\tlw $ra, %d($sp)\n", RA_OFFSET);
      printf("\taddi $sp, $sp, %d\n", FRAME_SIZE);
      printf("\tjr $ra\n");
      exit_scope();
      free($2);
    }
  | FUNCTION ID LP RP COLON type SEQ
    {
      /* no parameters */
      enter_scope($2);
      printf("\n%s:\n", $2);
      printf("\taddi $sp, $sp, -%d\n", FRAME_SIZE);
      printf("\tsw $ra, %d($sp)\n", RA_OFFSET);
    }
    local_dec statements END
    {
      printf("\t%s_ret:\n", current_function_name);
      printf("\tlw $ra, %d($sp)\n", RA_OFFSET);
      printf("\taddi $sp, $sp, %d\n", FRAME_SIZE);
      printf("\tjr $ra\n");
      exit_scope();
      free($2);
    }
  ;

/* local_dec => LET var_decs IN | empty */
local_dec
  : LET var_decs IN
  | /* empty */
  ;
var_decs
  : var_decs var_dec
  | /* empty */
  ;

/* parameters => param_list or param_list + comma + param */
parameters
  : parameters COMMA parameter
    {
      $3->next=$1;
      $$=$3;
    }
  | parameter
    {
      $1->next=NULL;
      $$=$1;
    }
  ;

/* parameter => ID : type => scope=PARAM. We'll store in stack offset. */
parameter
  : ID COLON type
    {
      struct ParamNode* node= (struct ParamNode*)malloc(sizeof(*node));
      if(!node) exit(EXIT_FAILURE);
      node->name=$1; 
      node->next=NULL;
      $$=node;

      SymbolInfo info;
      info.loc_type=VAR_LOC_STACK;
      info.location.stack_offset = ARG_REG_SAVE_OFFSET + current_param_index*4;
      insert_symbol(strdup($1), PARAM_SCOPE, info);

      current_param_index++;
      if(current_param_index>4){
        fprintf(stderr, "Semantic Error: Line %d: More than 4 params not supported in function '%s'\n", yylineno, current_function_name);
        error_count++;
      }
    }
  ;

/* statements => statements ; statement | statement */
statements
  : statements SEMICOLON statement
  | statement
  ;

/* statement => assignment, print, input, if, call, return, for... */
statement
  : assignment_stmt
  | print_stmt
  | input_stmt
  | if_stmt
  | call_stmt { if($1.reg!=-1) free_register($1.reg); }
  | return_stmt
  | for_stmt_stub
  ;

/* assignment => ID := expr */
assignment_stmt
  : ID ASSIGN expr
    {
      SymbolNode* sym= lookup_symbol($1);
      if(sym){
        /* If expr is string address => we simply store pointer. 
           If it's integer => store integer. */
        if($3.reg!=-1){
          if(sym->info.loc_type==VAR_LOC_GLOBAL){
            printf("\tsw $t%d, %s\n", $3.reg, sym->info.location.global_label);
          } else {
            printf("\tsw $t%d, %d($sp)\n", $3.reg, sym->info.location.stack_offset);
          }
          free_register($3.reg);
        }
      } else {
        /* if not found, just free the reg to avoid leak */
        free_register($3.reg);
      }
      free($1);
    }
  ;

/* return => return expr or just return */
return_stmt
  : RETURN expr
    {
      if(!current_function_name){
        /* global return => jump toyger_main_end */
        if($2.reg!=-1) free_register($2.reg);
        printf("\tj toyger_main_end\n");
      } else {
        /* put expr in $v0, then jump function_ret */
        if($2.reg!=-1){
          printf("\tmove $v0, $t%d\n", $2.reg);
          free_register($2.reg);
        }
        printf("\tj %s_ret\n", current_function_name);
      }
    }
  | RETURN
    {
      /* no expr => just jump out */
      if(!current_function_name){
        printf("\tj toyger_main_end\n");
      } else {
        printf("\tj %s_ret\n", current_function_name);
      }
    }
  ;

/* rel_expr => expr <op> expr, result in a new register: 1= true, 0= false */
rel_expr
  : expr EQ expr {
      int r1=$1.reg, r2=$3.reg; 
      $$= get_register();
      if(r1!=-1 && r2!=-1 && $$!=-1){
        printf("\tseq $t%d, $t%d, $t%d\n", $$, r1, r2);
      }
      free_register(r1); 
      free_register(r2);
    }
  | expr NE expr {
      int r1=$1.reg, r2=$3.reg; 
      $$= get_register();
      if(r1!=-1 && r2!=-1 && $$!=-1){
        printf("\tsne $t%d, $t%d, $t%d\n", $$, r1, r2);
      }
      free_register(r1); 
      free_register(r2);
    }
  | expr LT expr {
      int r1=$1.reg, r2=$3.reg; 
      $$= get_register();
      if(r1!=-1 && r2!=-1 && $$!=-1){
        printf("\tslt $t%d, $t%d, $t%d\n", $$, r1, r2);
      }
      free_register(r1); 
      free_register(r2);
    }
  | expr LE expr {
      int r1=$1.reg, r2=$3.reg; 
      $$= get_register();
      if(r1!=-1 && r2!=-1 && $$!=-1){
        printf("\tsle $t%d, $t%d, $t%d\n", $$, r1, r2);
      }
      free_register(r1); 
      free_register(r2);
    }
  | expr GT expr {
      int r1=$1.reg, r2=$3.reg; 
      $$= get_register();
      if(r1!=-1 && r2!=-1 && $$!=-1){
        printf("\tsgt $t%d, $t%d, $t%d\n", $$, r1, r2);
      }
      free_register(r1); 
      free_register(r2);
    }
  | expr GE expr {
      int r1=$1.reg, r2=$3.reg; 
      $$= get_register();
      if(r1!=-1 && r2!=-1 && $$!=-1){
        printf("\tsge $t%d, $t%d, $t%d\n", $$, r1, r2);
      }
      free_register(r1); 
      free_register(r2);
    }
  ;

/* expr => expr + term | expr - term | term */
expr
  : expr ADD term
    {
      if($1.reg!=-1 && $3.reg!=-1){
        printf("\tadd $t%d, $t%d, $t%d\n", $1.reg, $1.reg, $3.reg);
        $$.reg=$1.reg;
      } else {
        $$.reg=-1;
      }
      $$.is_address=0;
      free_register($3.reg);
    }
  | expr MINUS term
    {
      if($1.reg!=-1 && $3.reg!=-1){
        printf("\tsub $t%d, $t%d, $t%d\n", $1.reg, $1.reg, $3.reg);
        $$.reg=$1.reg;
      } else {
        $$.reg=-1;
      }
      $$.is_address=0;
      free_register($3.reg);
    }
  | term
    {
      $$=$1;
    }
  ;

/* term => term * factor | term / factor | factor */
term
  : term MUL factor
    {
      if($1.reg!=-1 && $3.reg!=-1){
        printf("\tmul $t%d, $t%d, $t%d\n", $1.reg, $1.reg, $3.reg);
        $$.reg=$1.reg;
      } else {
        $$.reg=-1;
      }
      $$.is_address=0;
      free_register($3.reg);
    }
  | term DIV factor
    {
      if($1.reg!=-1 && $3.reg!=-1){
        printf("\tdiv $t%d, $t%d\n", $1.reg, $3.reg);
        printf("\tmflo $t%d\n", $1.reg);
        $$.reg=$1.reg;
      } else {
        $$.reg=-1;
      }
      $$.is_address=0;
      free_register($3.reg);
    }
  | factor
    { $$=$1; }
  ;

/* factor => (expr) | NUMBER | STRING | ID | call_stmt */
factor
  : LP expr RP
    { $$=$2; }
  | NUMBER
    {
      $$.reg = get_register();
      if($$.reg!=-1) {
        printf("\tli $t%d, %d\n", $$.reg, $1);
      }
      $$.is_address=0;
    }
  | STRING
    {
      const char* lbl = add_string_literal($1);
      $$.reg = get_register();
      if($$.reg!=-1) {
        printf("\tla $t%d, %s\n", $$.reg, lbl);
      }
      $$.is_address=1; /* indicates it's an address (string) */
      free($1);
    }
  | ID
    {
      SymbolNode* sym = lookup_symbol($1);
      $$.reg = get_register();
      $$.is_address=0;
      if(sym && $$.reg!=-1){
        if(sym->info.loc_type==VAR_LOC_GLOBAL){
          printf("\tlw $t%d, %s\n", $$.reg, sym->info.location.global_label);
        } else {
          printf("\tlw $t%d, %d($sp)\n", $$.reg, sym->info.location.stack_offset);
        }
      } else if($$.reg!=-1){
        /* Not found => default 0 */
        printf("\tli $t%d, 0\n", $$.reg);
      }
      free($1);
    }
  | call_stmt
    {
      $$=$1;
      /* if function returned a string address => is_address=1, else 0.
         For simplicity we treat all returns as int => is_address=0, 
         but you can enhance as needed. */
      if($$.is_address==1){
        fprintf(stderr,"Semantic Warning: function returning string address not fully handled\n");
      }
    }
  ;

/* print_stmt => printint(expr) or printstring(expr) */
print_stmt
  : PRINTINT LP expr RP
    {
      if($3.reg!=-1){
        /* syscalls in MIPS for print int => $v0=1, $a0=val, syscall */
        printf("\tli $v0, 1\n");
        printf("\tmove $a0, $t%d\n", $3.reg);
        printf("\tsyscall\n");
        free_register($3.reg);
      }
    }
  | PRINTSTRING LP expr RP
    {
      if($3.reg!=-1){
        /* print string => $v0=4, $a0=addr, syscall */
        printf("\tli $v0, 4\n");
        printf("\tmove $a0, $t%d\n", $3.reg);
        printf("\tsyscall\n");
        free_register($3.reg);
      }
    }
  ;

/* input_stmt => ID := getint() */
input_stmt
  : ID ASSIGN GETINT LP RP
    {
      SymbolNode* sym = lookup_symbol($1);
      if(sym){
        /* read int => $v0=5, syscall => result in $v0 => store in var */
        printf("\tli $v0, 5\n");
        printf("\tsyscall\n");
        if(sym->info.loc_type==VAR_LOC_GLOBAL){
          printf("\tsw $v0, %s\n", sym->info.location.global_label);
        } else {
          printf("\tsw $v0, %d($sp)\n", sym->info.location.stack_offset);
        }
      }
      free($1);
    }
  ;

/* call_stmt => ID(expr_list) => function call with up to 4 args */
call_stmt
  : ID LP RP
    {
      /* no args */
      char* fname=$1;
      printf("\t# call %s with no args\n", fname);

      /* Save t0..t7 if they are in use, then jal. 
         For simplicity we do a partial approach. */
      for(int i=0;i<NUM_TEMP_REGS;i++){
        if(temp_reg_available[i]==1){
          printf("\tsw $t%d, toyger_main_t_regs+%d\n", i, i*4);
        }
      }
      printf("\tjal %s\n", fname);

      /* restore t0..t7 */
      for(int i=0;i<NUM_TEMP_REGS;i++){
        if(temp_reg_available[i]==1){
          printf("\tlw $t%d, toyger_main_t_regs+%d\n", i, i*4);
        }
      }
      $$.reg=get_register();
      if($$.reg!=-1) {
        printf("\tmove $t%d, $v0\n", $$.reg);
      }
      $$.is_address=0;
      free(fname);
    }
  | ID LP expr_list RP
    {
      /* function call with arguments */
      char* fname=$1;
      struct ExprListNode* current_arg=$3;
      int arg_count=0;

      /* Reverse the expr_list so the leftmost argument goes to $a0, etc. */
      struct ExprListNode* head=$3, *prev=NULL, *nx=NULL;
      while(head){
        nx=head->next;
        head->next=prev;
        prev=head;
        head=nx;
      }
      current_arg=prev;
      while(current_arg){
        if(arg_count>=4){
          fprintf(stderr,"Semantic Error: Line %d: More than 4 arguments\n", yylineno);
          error_count++;
          while(current_arg){
            free_register(current_arg->reg);
            current_arg=current_arg->next;
          }
          break;
        }
        if(current_arg->reg!=-1){
          printf("\tmove $a%d, $t%d\n", arg_count, current_arg->reg);
          temp_reg_save_needed[current_arg->reg]=1; 
        } else {
          printf("\tli $a%d, 0\n", arg_count);
        }
        arg_count++;
        current_arg=current_arg->next;
      }

      /* Save t0..t7 => toyger_main_t_regs */
      for(int i=0; i<NUM_TEMP_REGS; i++){
        if(temp_reg_available[i]==1 || temp_reg_save_needed[i]==1){
          printf("\tsw $t%d, toyger_main_t_regs+%d\n", i, i*4);
        }
      }
      printf("\tjal %s\n", fname);

      /* restore t0..t7 */
      for(int i=0; i<NUM_TEMP_REGS; i++){
        if(temp_reg_available[i]==1 || temp_reg_save_needed[i]==1){
          printf("\tlw $t%d, toyger_main_t_regs+%d\n", i, i*4);
          temp_reg_save_needed[i]=0;
        }
      }
      /* free expr list nodes */
      struct ExprListNode* c=prev;
      while(c){
        free_register(c->reg);
        struct ExprListNode* tmp=c;
        c=c->next;
        free(tmp);
      }
      $$.reg=get_register();
      if($$.reg!=-1){
        printf("\tmove $t%d, $v0\n", $$.reg);
      }
      $$.is_address=0;
      free(fname);
    }
  ;

/* expr_list => multiple or single */
expr_list
  : expr_list COMMA expr
    {
      struct ExprListNode* node=(struct ExprListNode*)malloc(sizeof(*node));
      if(!node) exit(EXIT_FAILURE);
      node->reg=$3.reg;
      node->next=$1;
      $$=node;
    }
  | expr
    {
      struct ExprListNode* node=(struct ExprListNode*)malloc(sizeof(*node));
      if(!node) exit(EXIT_FAILURE);
      node->reg=$1.reg;
      node->next=NULL;
      $$=node;
    }
  ;

/* if_stmt => if_no_else | if_with_else */
if_stmt
  : if_no_else
  | if_with_else
  ;

/* if_no_else => if_cond_part THEN statements END */
if_no_else
  : if_cond_part THEN statements END
    {
      printf("%s:\n", $1.else_label);
      if($1.cond_reg!=-1) free_register($1.cond_reg);
      free($1.else_label);
      free($1.end_label);
    }
  ;

/* if_with_else => if_cond_part THEN statements ELSE statements END */
if_with_else
  : if_cond_part THEN statements
    {
      printf("\tj %s\n", $1.end_label);
      printf("%s:\n", $1.else_label);
    }
  ELSE statements END
    {
      printf("%s:\n", $1.end_label);
      if($1.cond_reg != -1) free_register($1.cond_reg);
      free($1.else_label);
      free($1.end_label);
    }
  ;

/* if_cond_part => if (rel_expr) => beqz cond => else_label */
if_cond_part
  : IF LP rel_expr RP
    {
      int cond_reg = $3;
      char* else_label = new_label();
      char* end_label  = new_label();
      if(cond_reg != -1){
        printf("\tbeqz $t%d, %s\n", cond_reg, else_label);
      }
      $$.cond_reg = cond_reg;
      $$.else_label = else_label;
      $$.end_label  = end_label;
    }
  ;

/* for => for i := expr to expr do statements end */
for_head
  : FOR ID ASSIGN expr TO expr DO
    {
      SymbolNode* sym = lookup_symbol($2);
      /* i := expr */
      if(sym && $4.reg != -1){
        if(sym->info.loc_type == VAR_LOC_GLOBAL){
          printf("\tsw $t%d, %s\n", $4.reg, sym->info.location.global_label);
        } else {
          printf("\tsw $t%d, %d($sp)\n", $4.reg, sym->info.location.stack_offset);
        }
      }
      free_register($4.reg);

      char* loop_start = new_label();
      char* loop_end   = new_label();
      printf("%s:\n", loop_start);

      /* load i, compare with expr (end) => sle => beqz => loop_end */
      int i_reg = get_register();
      if(sym && i_reg != -1){
        if(sym->info.loc_type==VAR_LOC_GLOBAL){
          printf("\tlw $t%d, %s\n", i_reg, sym->info.location.global_label);
        } else {
          printf("\tlw $t%d, %d($sp)\n", i_reg, sym->info.location.stack_offset);
        }
      } else if(i_reg != -1){
        printf("\tli $t%d, 0\n", i_reg);
      }

      int end_reg = $6.reg;
      int cond_reg = get_register();
      if(i_reg != -1 && end_reg != -1 && cond_reg != -1){
        printf("\tsle $t%d, $t%d, $t%d\n", cond_reg, i_reg, end_reg);
        printf("\tbeqz $t%d, %s\n", cond_reg, loop_end);
      }
      free_register(cond_reg);
      free_register(i_reg);

      $$.sym_i = sym;
      $$.loop_start = loop_start;
      $$.loop_end   = loop_end;
      $$.end_reg    = end_reg;
    }
  ;

/* for_stmt_stub => for_head statements END => do i++ => j loop_start => loop_end */
for_stmt_stub
  : for_head statements END
    {
      SymbolNode* sym = $1.sym_i;
      if(sym){
        int i_reg = get_register();
        if(i_reg != -1){
          if(sym->info.loc_type==VAR_LOC_GLOBAL){
            printf("\tlw $t%d, %s\n", i_reg, sym->info.location.global_label);
          } else {
            printf("\tlw $t%d, %d($sp)\n", i_reg, sym->info.location.stack_offset);
          }
          printf("\taddi $t%d, $t%d, 1\n", i_reg, i_reg);
          if(sym->info.loc_type==VAR_LOC_GLOBAL){
            printf("\tsw $t%d, %s\n", i_reg, sym->info.location.global_label);
          } else {
            printf("\tsw $t%d, %d($sp)\n", i_reg, sym->info.location.stack_offset);
          }
        }
        free_register(i_reg);
      }
      printf("\tj %s\n", $1.loop_start);
      printf("%s:\n", $1.loop_end);

      free($1.loop_start);
      free($1.loop_end);
      if($1.end_reg != -1){
        free_register($1.end_reg);
      }
    }
  ;

%%

int main(int argc, char** argv){
   int parse_result = yyparse();
   if(parse_result==0 && error_count==0){
     fprintf(stderr, "Input Accepted - MIPS Generation Completed\n");
   } else {
     fprintf(stderr, "Compilation failed with %d error(s).\n", error_count + (parse_result!=0));
     free_symbol_table();
     free_string_literals();
     return 1;
   }
   free_symbol_table();
   free_string_literals();
   return 0;
}

int yyerror(const char *s){
    fprintf(stderr, "Syntax Error: Line %d\n", yylineno);
    error_count++;
    return 0;
}
