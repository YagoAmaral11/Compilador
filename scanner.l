%{

#include <string>
#include <cstring>

%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
LETRA [a-zA-Z_]
CARACTER ([^\'\\\n]|\\.)

DELIM {ESPACO}+
CHAR \'{CARACTER}\'
BOOL (true|false)
INT [-]?{DIGITO}+
FLOAT [-]?{DIGITO}+\.{DIGITO}+(([eE])([-])?{DIGITO}+)?
ID {LETRA}({DIGITO}|{LETRA})*
AND (&&|and)
OR (\|\||or)
NOT (!|not)

%%


"\n"		{ linha++; coluna = 0; }
{DELIM} 	{ coluna += strlen(yytext); }

{AND}        { coluna += 2; return OP_AND; }
{OR}        { coluna += 2; return OP_OR; }
{NOT}         { coluna += 1; return OP_NOT; }
"=="         { coluna += 2; return OP_IGUAL; }
"!="     { coluna += 2; return OP_DIFERENTE; }
"<="   { coluna += 2; return OP_MENOR_IGUAL; }
">="   { coluna += 2; return OP_MAIOR_IGUAL; }
"<"         { coluna ++; return OP_MENOR; }
">"         { coluna ++; return OP_MAIOR; }

[=]         { coluna++; return *yytext; }
[+-/*]		{ coluna++; return *yytext; }
[()]        { coluna++; return *yytext; }
[{}]        { coluna++; return *yytext; }
[;]         { coluna++; return *yytext; }
"int"       { coluna += strlen(yytext); yylval.tipo = TIPO_INT; return TK_TIPO; }
"float"     { coluna += strlen(yytext); yylval.tipo = TIPO_FLOAT; return TK_TIPO; }
"char"      { coluna += strlen(yytext); yylval.tipo = TIPO_CHAR; return TK_TIPO; }
"bool"      { coluna += strlen(yytext); yylval.tipo = TIPO_BOOL; return TK_TIPO; }
"var"       { coluna += strlen(yytext); return TK_VAR; }
{INT}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_INT; return TK_NUM; }
{FLOAT}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_FLOAT; return TK_NUM; }
{CHAR}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_CHAR; return TK_NUM; }
{BOOL}		{ coluna += strlen(yytext); if('t' == *yytext){ yylval.label = to_string(BOOL_TRUE); } else{ yylval.label = to_string(BOOL_FALSE); } yylval.tipo = TIPO_BOOL; return TK_NUM; }
{ID}        { coluna += strlen(yytext); yylval.label = yytext; return TK_ID; }
.			{ coluna += strlen(yytext); fprintf(stderr, "Erro Léxico: Caracteres não reconhecido '%s', em Linha: %d, Coluna: %d \n", yytext, linha, coluna); }

%%
