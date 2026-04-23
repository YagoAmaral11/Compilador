%{

#include <string>
#include <cstring>

%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
LETRA [a-zA-z_]

DELIM {ESPACO}+
NUM {DIGITO}+
ID {LETRA}({DIGITO}|{LETRA})*

%%

"\n"		{ linha++; coluna = 0; }
{DELIM} 	{ coluna += strlen(yytext); }
[=]         { coluna++; return *yytext; }
[+-/*]			{ coluna++; return *yytext; }
[()]        { coluna++; return *yytext; }
[;]         { coluna++; return *yytext; }
{NUM}		{ coluna += strlen(yytext); yylval.label = yytext; return TK_NUM; }
{ID}        { coluna += strlen(yytext); yylval.label = yytext; return TK_ID; }
.			{ coluna += strlen(yytext); fprintf(stderr, "Erro Léxico: Caracteres não reconhecido '%s', em Linha: %d, Coluna: %d \n", yytext, linha, coluna); }

%%
