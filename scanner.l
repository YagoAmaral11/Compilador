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
TIPO (int|float|char|bool)
CHAR \'{CARACTER}\'
BOOL (true|false)
INT {DIGITO}+
FLOAT {DIGITO}+\.{DIGITO}+
ID {LETRA}({DIGITO}|{LETRA})*

%%

"\n"		{ linha++; coluna = 0; }
{DELIM} 	{ coluna += strlen(yytext); }

/*Operadores Relacionais*/
"=="        { coluna += 2; return yytext; }
"!="        {coluna += 2; return yytext; }
"<="        {coluna += 2; return yytext; }
">="        {coluna += 2; return yytext; }
"<"         {coluna ++; return yytext; }
">"         {coluna ++; return yytext; }

[=]         { coluna++; return *yytext; }
[+-/*]		{ coluna++; return *yytext; }
[()]        { coluna++; return *yytext; }
[;]         { coluna++; return *yytext; }
{TIPO}      { coluna += strlen(yytext); yylval.label = yytext; return TK_TIPO; }
{INT}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = "int"; return TK_NUM; }
{FLOAT}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = "float"; return TK_NUM; }
{CHAR}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = "char"; return TK_NUM; }
{BOOL}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = "bool"; return TK_NUM; }
{ID}        { coluna += strlen(yytext); yylval.label = yytext; return TK_ID; }
.			{ coluna += strlen(yytext); fprintf(stderr, "Erro Léxico: Caracteres não reconhecido '%s', em Linha: %d, Coluna: %d \n", yytext, linha, coluna); }

%%
