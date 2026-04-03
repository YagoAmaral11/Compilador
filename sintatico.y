%{

#include <iostream>
#include <string>

#define YYSTYPE atributos

using namespace std;

int var_temp_qnt;
int linha = 1;
string codigo_gerado;

int yylex(void);
void yyerror(string);
string gentempcode();

extern FILE* yyin;

struct atributos
{
	string label;
	string traducao;
};

%}

%token TK_NUM

%start S

%left '+' '-'
%left '*' '/'

%%

S: E
	{
		codigo_gerado = "#include <stdio.h>\n"
						"int main(void) {\n";						

		for (int i = 1; i <= var_temp_qnt; i++)
		{
			codigo_gerado += "\tint t" + to_string(i) + ";\n";
		}

		codigo_gerado += $1.traducao;

		codigo_gerado += "\treturn 0;" "\n}\n";
	}
;

E: 
	E '+' E
	{
		$$.label = gentempcode();
		$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
			" = " + $1.label + " + " + $3.label + ";\n";
	}
	| E '-' E
	{
		$$.label = gentempcode();
		$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
			" = " + $1.label + " - " + $3.label + ";\n";
	}
	| E '*' E
	{
		$$.label = gentempcode();
		$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
			" = " + $1.label + " * " + $3.label + ";\n";
	}
	| E '/' E
	{
		$$.label = gentempcode();
		$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
			" = " + $1.label + " / " + $3.label + ";\n";
	}
	| TK_NUM
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
	}
;

%%

#include "lex.yy.c"

int yyparse();

string gentempcode()
{
	var_temp_qnt++; // Usado para contar quantas variáveis temporárias serão usadas no programa
	return "t" + to_string(var_temp_qnt); // retorna um identificador para essa variável temporária
}

void yyerror(string MSG)
{
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}

int main(int argc, char* argv[])
{
	// programa de entrada
	if (argc > 1)
	{
		yyin = fopen(argv[1], "r");

		if (!yyin)
		{
			perror("fopen");
			return 1;
		}
	}
	else
	{
		yyin = stdin;
	}

	var_temp_qnt = 0;

	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}
