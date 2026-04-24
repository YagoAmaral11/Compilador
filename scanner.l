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
INT {DIGITO}+
FLOAT {DIGITO}+\.{DIGITO}+
ID {LETRA}({DIGITO}|{LETRA})*

%%

"\n"		{ linha++; coluna = 0; }
{DELIM} 	{ coluna += strlen(yytext); }
[=]         { coluna++; return *yytext; }
[+-/*]		{ coluna++; return *yytext; }
[()]        { coluna++; return *yytext; }
[;]         { coluna++; return *yytext; }
"int"       { coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_INT; return TK_TIPO; }
"float"       { coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_FLOAT; return TK_TIPO; }
"char"       { coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_CHAR; return TK_TIPO; }
"bool"       { coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_BOOL; return TK_TIPO; }
{INT}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_INT; return TK_NUM; }
{FLOAT}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_FLOAT; return TK_NUM; }
{CHAR}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_CHAR; return TK_NUM; }
{BOOL}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = TIPO_BOOL; return TK_NUM; }
{ID}        { coluna += strlen(yytext); yylval.label = yytext; return TK_ID; }
.			{ coluna += strlen(yytext); fprintf(stderr, "Erro Léxico: Caracteres não reconhecido '%s', em Linha: %d, Coluna: %d \n", yytext, linha, coluna); }

%%
