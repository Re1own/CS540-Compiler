/* toyger.l */
/* 
   A simple lexical analyzer using Flex. 
   It recognizes keywords, identifiers, numbers, strings, and operators, 
   then passes tokens to the Bison parser (toyger.y).
*/

%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "toyger.tab.h"

extern YYSTYPE yylval;


const char *token_err_msg = "Lexical Error: Line %d\n";

char *process_string(const char *input) {
    int len = strlen(input);
    char *output = (char *)malloc(len);
    if (!output) {
        perror("Failed to allocate memory in process_string");
        exit(EXIT_FAILURE);
    }

    int i = 1; 
    int j = 0; 

    while (i < len - 1) { 
        if (input[i] == '\\') {
            if (i + 1 < len - 1) {
                char escaped_char = input[i + 1]; 
                switch (escaped_char) {
                    case 'n': output[j++] = '\n'; i += 2; break;
                    case 't': output[j++] = '\t'; i += 2; break;
                    case '\\': output[j++] = '\\'; i += 2; break;
                    case '"': output[j++] = '"'; i += 2; break;
                    default:
                        output[j++] = input[i++];
                        break;
                }
            } else {
                // Backslash at the end, copy literally
                output[j++] = input[i++];
            }
        } else {
            // Normal character
            output[j++] = input[i++];
        }
    }
    output[j] = '\0'; // Null terminate
    return output;
}
%}


space   [ \t]
number  0|[1-9][0-9]*
id      [a-zA-Z_][a-zA-Z0-9_]*
string  \"(\\.|[^"\\])*\"
comment "//"[^\n]*

%option yylineno
%option never-interactive

%%

let             { return(LET); }
in              { return(IN); }
end             { return(END); }
var             { return(VAR); }
function        { return(FUNCTION); }
printint        { return(PRINTINT); }
printstring     { return(PRINTSTRING); }
getint          { return(GETINT); }
return          { return(RETURN); }
if              { return(IF); }
then            { return(THEN); }
else            { return(ELSE); }
for             { return(FOR); }
to              { return(TO); }
do              { return(DO); }
void            { return(VOID); }
int             { return(INT_TYPE); }
string          { return(STRING_TYPE); }


"+"             { return(ADD); }
"-"             { return(MINUS); }
"*"             { return(MUL); }
"/"             { return(DIV); }
"=="            { return(EQ); }
"<"             { return(LT); }
"<="            { return(LE); }
">"             { return(GT); }
">="            { return(GE); }
":="            { return(ASSIGN); }
"<>"            { return(NE); }
"("             { return(LP); }
")"             { return(RP); }
":"             { return(COLON); }
","             { return(COMMA); }
"="             { return(SEQ); }
";"             { return(SEMICOLON); }


{id} {
    yylval.sval = strdup(yytext);
    if (!yylval.sval) exit(EXIT_FAILURE);
    return(ID);
}


{number} {
    yylval.ival = atoi(yytext);
    return(NUMBER);
}


{string} {
    yylval.sval = process_string(yytext);
    if (!yylval.sval) exit(EXIT_FAILURE);
    return(STRING);
}


{comment}       { /* do nothing */ }


[ \t\n]+        { /* skip */ }


. {
    fprintf(stderr, token_err_msg, yylineno);
}

%%
