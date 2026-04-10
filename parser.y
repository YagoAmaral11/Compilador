%{

#include <iostream>
#include <unordered_map>
#include <string>

using namespace std;

extern FILE* yyin; // yyin é o arquivo de entrada do flex; ao alterar, é possível redirecionar o fluxo
#define YYSTYPE atributos // YYSTYPE é o tipo de valor usado para cada token da árvore sintática; É diferente do valor numérico gerador por %token

// Structs
// TODO: Criar estruturas melhores para identificar os Tokens
struct atributos
{
	string label; // "Endereço" dessa variável; O nome da variável que carrega o valor dessa árvore sintática
	string traducao; // A tradução dessa árvore sintática para o código intermediário
};

struct Simbolo
{	
	string labelReal;
	// TODO: Guardar o tipo do token aqui
};

// Declarações de funções
int yylex(void);
void yyerror(string);
string gentempcode();

// Variáveis
int var_temp_qnt; // Contador de variáveis temporárias
int linha = 1; // Contador da linha do comando; Atualizado no lexer
string codigo_gerado; // Código intermediário gerado pelo compilador
unordered_map<string, Simbolo> tabelaSimbolos; // Tabela de símbolos

%}

%token TK_NUM
%token TK_ID

%start OUTPUT

%right '='
%left '+' '-'
%left '*' '/'
%left '(' ')'

%%

OUTPUT: 
	EXPRESSAO
	{
		codigo_gerado = "#include <stdio.h>\n\n"
						"int main(void) \n{\n";						

		codigo_gerado += "\t// Variaveis Temporarias\n";
		for (int i = 1; i <= var_temp_qnt; i++)
		{
			codigo_gerado += "\tint t" + to_string(i) + ";\n";
		}
		codigo_gerado += "\n";
		
		codigo_gerado += "\t// Inicio do codigo\n";
		codigo_gerado += $1.traducao;

		codigo_gerado += "\n\treturn 0;" "\n}\n";
	}
;

EXPRESSAO: 	
	TK_NUM
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
	}
	| TK_ID
	{
		// TODO: Retornar o valor da variável se ela já existir;
		// Se ela não existir, retornar erro
	}
	| ATRIBUICAO
	{
		// TODO: Retornar o valor do resultado da expressão
	}
	|'(' EXPRESSAO ')'
	{
		$$.label = $2.label;
		$$.traducao = $2.traducao;
	}
	| EXPRESSAO '+' EXPRESSAO
	{
		$$.label = gentempcode();
		$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
			" = " + $1.label + " + " + $3.label + ";\n";
	}
	| EXPRESSAO '-' EXPRESSAO
	{
		$$.label = gentempcode();
		$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
			" = " + $1.label + " - " + $3.label + ";\n";
	}
	| EXPRESSAO '*' EXPRESSAO
	{
		$$.label = gentempcode();
		$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
			" = " + $1.label + " * " + $3.label + ";\n";
	}
	| EXPRESSAO '/' EXPRESSAO
	{
		$$.label = gentempcode();
		$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
			" = " + $1.label + " / " + $3.label + ";\n";
	}	
;

ATRIBUICAO:
	TK_ID '=' EXPRESSAO
	{
		// OBS: No momento, tratar como uma declaração simples; Depois melhorar
		// TODO: Retornar uma nova variável alocada com o valor de E
		// TODO: Verificar se essa variável já foi declarada ou não;
		// Se já foi declarada, alterar seu valor		
	}
;

%%

// OBS: Esse include deve estar em acordo com os arquivos make, para que não haja erro na compilação; 
// 		Deve ser o mesmo que $(SCANNER_OUTPUT).c
#include "scanner.c" 

int yyparse();

// TODO: Trocar essa função por um controlador
string gentempcode()
{
	var_temp_qnt++; // Usado para contar quantas variáveis temporárias serão usadas no programa
	return "tmp" + to_string(var_temp_qnt); // retorna um identificador para essa variável temporária
}

// TODO: Melhorar essa detecção de erro
void yyerror(string MSG)
{
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}

// Usado para inicializar as estruturas e controladores usados no compilador;
void initialize()
{
	var_temp_qnt = 0;
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

	initialize();

	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}
