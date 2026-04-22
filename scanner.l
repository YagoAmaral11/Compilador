%{

#include <string>
#include <cstring>

%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
LETRA [a-zA-z_]

TIPO (int|float|char|bool)
DELIM {ESPACO}+
INT {DIGITO}+
FLOAT {DIGITO}+\.{DIGITO}+
ID {LETRA}({DIGITO}|{LETRA})*

%%

"\n"		{ linha++; coluna = 0; }
{DELIM} 	{ coluna += strlen(yytext); }
[=]         { coluna++; return *yytext; }
[+-/*]			{ coluna++; return *yytext; }
[()]        { coluna++; return *yytext; }
[;]         { coluna++; return *yytext; }
{INT}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = "int"; return TK_NUM; }
{FLOAT}		{ coluna += strlen(yytext); yylval.label = yytext; yylval.tipo = "float"; return TK_NUM; }
{ID}        { coluna += strlen(yytext); yylval.label = yytext; return TK_ID; }
{TIPO}      { coluna += strlen(yytext); yylval.label = yytext; return TK_TIPO; }
.			{ coluna += strlen(yytext); fprintf(stderr, "Erro Léxico: Caracteres não reconhecido '%s', em Linha: %d, Coluna: %d \n", yytext, linha, coluna); }

%%
