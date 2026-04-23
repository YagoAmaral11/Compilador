%{

#include <iostream>
#include <unordered_map>
#include <queue>
#include <string>
#include <locale>
#include <cstdlib>

using namespace std;

extern FILE* yyin; // yyin é o arquivo de entrada do flex; ao alterar, é possível redirecionar o fluxo
#define YYSTYPE atributos // YYSTYPE é o tipo de valor usado para cada token da árvore sintática; É diferente do valor numérico gerador por %token

// Structs
// TODO: Criar estruturas melhores para identificar os Tokens
struct atributos
{
	string label; // "Endereço" dessa variável; O nome da variável que carrega o valor dessa árvore sintática
	string traducao; // A tradução dessa árvore sintática para o código intermediário
	string tipo;	// Tipo do token
};

struct Simbolo
{	
	// Informações sobre o Simbolo
	string labelReal;	
	// TODO: Guardar o tipo do token aqui	

	// Informações sobre a declaração
	bool simboloInicializado; // Se esse símbolo já foi inicializado com algum valor; Caso contrário, não pode ser usado
	string tipoDeclarado; // Tipo que foi declarado a variavel.
	string labelValorDeclaracao; // O label da variável temporária usada para guardar o valor de declaração dessa variável
	string valorDeclaracaoTraducao; // A tradução da expressão que foi usada para declarar esse símbolo
};

// Declarações de funções
int yylex(void);
void yyerror(string);
void semanticError(string MSG);
string novaVarTemp(string tipo);
Simbolo* novaVar(string tipo);
bool varExiste(string labelUsuario);
bool varInicializada(string labelUsuario);
string varNomeReal(string labelUsuario);
string varTipo(string labelUsuario);

// Variáveis
int var_temp_qnt; // Contador de variáveis temporárias
int var_qnt; // Contador de variáveis globais não temporárias criadas

int linha = 1; // Contador da linha do comando; Atualizado no lexer
int coluna = 0; // Contador de caracteres do comando; Atualizado no lexer

string codigo_gerado; // Código intermediário gerado pelo compilador
unordered_map<string, Simbolo*> tabelaSimbolos; // Tabela de símbolos
queue<string> ordemDeclaracaoSimbolos; // A ordem de declaração dos símbolos da tabela

unordered_map<string, Simbolo*> tabelaTemporarios; // Tabela de símbolos
queue<string> ordemDeclaracaoTemporarios; // A ordem de declaração dos símbolos da tabela

// Macros
#define tmpVarPrefix "tmp"
#define varPrefix "var"

%}

%token TK_NUM
%token TK_ID
%token TK_TIPO

%start OUTPUT

%right '='
%left '+' '-'
%left '*' '/'
%left '(' ')'

%%

OUTPUT: 
	PROGRAMA_MINIMO
	{
		// TODO: Depois separar em funções

		codigo_gerado = "#include <stdio.h>\n\n"
						"int main(void) \n{\n";						


		codigo_gerado += "\t// Variaveis Temporarias\n";
		while (!ordemDeclaracaoTemporarios.empty())
		{			 
			string labelVar = ordemDeclaracaoTemporarios.front();
			Simbolo* s = tabelaTemporarios[labelVar];

			codigo_gerado += "\t" + s->tipoDeclarado + " " + s->labelReal + ";\n";

			ordemDeclaracaoTemporarios.pop();
		}
				
		
		codigo_gerado += "\n\t// Variaveis Globais\n";				
		while (!ordemDeclaracaoSimbolos.empty())
		{			 
			string labelVar = ordemDeclaracaoSimbolos.front();
			Simbolo* s = tabelaSimbolos[labelVar];

			codigo_gerado += "\t// " + labelVar + ":\n";
			if(!s->valorDeclaracaoTraducao.empty())
			{
				codigo_gerado += s->valorDeclaracaoTraducao;
				codigo_gerado += "\t" + s->tipoDeclarado + " " + s->labelReal + " = " + s->labelValorDeclaracao + ";" + " // " + labelVar + "\n";
			} else 
			{
				codigo_gerado += "\t" + s->tipoDeclarado + " " + s->labelReal + ";" + " // " + labelVar + "\n";
			}

			codigo_gerado += "\n"; // Espaçamento entre variáveis

			ordemDeclaracaoSimbolos.pop();
		}
		codigo_gerado += "\n";		
		

		codigo_gerado += "\t// Inicio do codigo\n";
		codigo_gerado += $1.traducao;

		codigo_gerado += "\n\treturn 0;" "\n}\n";
	}
;

PROGRAMA_MINIMO:
	COMANDO
	{
		$$.traducao = $1.traducao;
	}
	|
	PROGRAMA_MINIMO COMANDO
	{
		$$.traducao = $1.traducao + $2.traducao;
	}
;

COMANDO:
	EXPRESSAO ';'	
	{
		$$.traducao = $1.traducao;
	}
	| ATRIBUICAO ';'
	{
		$$.traducao = $1.traducao;
	}
	| DECLARACAO ';'
	{
		$$.traducao = $1.traducao;
	}
;

EXPRESSAO: 	
	TK_NUM
	{
		$$.label = novaVarTemp($1.tipo);
		$$.tipo = $1.tipo;
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
	}
	| TK_ID
	{
		if (!varExiste($1.label))
		{
			// A variável não foi declarada ainda, erro
			// yyerror("Símbolo não conhecido -> '" + $1.label + "'' não é conhecido. Verifique se foi declarado.");
			semanticError("Símbolo não conhecido -> '" + $1.label + "' não é conhecido. Verifique se foi declarado.");
			YYABORT;
		}

		if (!varInicializada($1.label))
		{
			// A variável não foi inicializada ainda, erro
			// yyerror("Variável não inicializada -> '" + $1.label + "''. Não é possível usar uma variável não inicializada");
			semanticError("Variável não inicializada -> '" + $1.label + "'. Não é possível usar uma variável não inicializada");
			YYABORT;
		}

		$$.label = novaVarTemp($1.tipo);
		$$.tipo = varTipo($1.label);
		$$.traducao = "\t" + $$.label + " = " + varNomeReal($1.label) + ";" + " // " + $1.label + "\n";
	}
	|	
	'(' EXPRESSAO ')'
	{
		$$.label = $2.label;
		$$.tipo = $2.tipo;
		$$.traducao = $2.traducao;
	}
	| EXPRESSAO '+' EXPRESSAO
	{
		if (((string($1.tipo) == "int") && (string($3.tipo) == "int")) || ((string($1.tipo) == "float") && (string($3.tipo) == "float")))
		{
			// Tipos de numeros iguais
			$$.label = novaVarTemp($1.tipo);
			$$.tipo = $1.tipo;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " + " + $3.label + ";\n";
		}
	}
	| EXPRESSAO '-' EXPRESSAO
	{
		if (((string($1.tipo) == "int") && (string($3.tipo) == "int")) || ((string($1.tipo) == "float") && (string($3.tipo) == "float")))
		{
			// Tipos de numeros iguais
			$$.label = novaVarTemp($1.tipo);
			$$.tipo = $1.tipo;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " - " + $3.label + ";\n";
		}
	}
	| EXPRESSAO '*' EXPRESSAO
	{
		if (((string($1.tipo) == "int") && (string($3.tipo) == "int")) || ((string($1.tipo) == "float") && (string($3.tipo) == "float")))
		{
			// Tipos de numeros iguais
			$$.label = novaVarTemp($1.tipo);
			$$.tipo = $1.tipo;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " * " + $3.label + ";\n";
		}			
	}
	| EXPRESSAO '/' EXPRESSAO
	{
		if (((string($1.tipo) == "int") && (string($3.tipo) == "int")) || ((string($1.tipo) == "float") && (string($3.tipo) == "float")))
		{
			// Tipos de numeros iguais
			$$.label = novaVarTemp($1.tipo);
			$$.tipo = $1.tipo;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " / " + $3.label + ";\n";
		}
	}		
;

ATRIBUICAO:
	TK_ID '=' EXPRESSAO
	{		
		if (varExiste($1.label))
		{
			// Se a variável já foi declarada, apenas altera seu valor; 
			// Se a variável não era inicializada ainda, agora ela é;
			$$.label = $1.label;
			$$.traducao = $3.traducao + "\t" + varNomeReal($1.label) + " = " + $3.label + ";" + " // " + $1.label + "\n";

			Simbolo* s = tabelaSimbolos[$1.label];
			s->simboloInicializado = true;
			s->tipoDeclarado = $3.tipo;
		}
		else
		{
			// TODO: Isso é uma declaração implícita; Mas só funciona ainda pq não existe tipos na LP. Depois que existir, melhorar esse código para inferir o tipo da variável

			$$.label = $1.label;
			$$.traducao = ""; // Não tem tradução; A tradução da expressão usada para gerar essa atribuição é guardada no simbolo para depois ser criada junto com a declaração
			
			Simbolo* s = novaVar($3.tipo);			
			s->valorDeclaracaoTraducao = $3.traducao;
			s->labelValorDeclaracao = $3.label;			
			s->simboloInicializado = true;

			tabelaSimbolos[$1.label] = s;						
			ordemDeclaracaoSimbolos.push($1.label);
		}
	}
;

DECLARACAO:
	TK_TIPO TK_ID // TODO: TEMINAR ESSA PORRA, MUITA COISA MANÉ
	{
		if (varExiste($2.label))
		{
			semanticError("Simbolo ja declarado -> '" + $1.label + "'. Nao e possivel declarar novamente, escolha outro nome.");
			YYABORT;
		}
		else
		{
			$$.label = $2.label;
			$$.traducao = "";

			Simbolo* s = novaVar($2.label);

			tabelaSimbolos[$2.label] = s;
			ordemDeclaracaoSimbolos.push($2.label);
		}
	}
;
%%

// OBS: Esse include deve estar em acordo com os arquivos make, para que não haja erro na compilação; 
// 		Deve ser o mesmo que $(SCANNER_OUTPUT).c
#include "scanner.c" 

int yyparse();

// Cria um novo identificador para uma variável temporária
string novaVarTemp(string tipo)
{
	string nome = tmpVarPrefix + to_string(var_temp_qnt++);

	Simbolo* s = new Simbolo;
	s->labelReal = nome;
	s->tipoDeclarado = tipo;

	tabelaTemporarios[nome] = s;
	ordemDeclaracaoTemporarios.push(nome);

	return nome;
}

// TODO: Depois passar o tipo dessa variável.
Simbolo* novaVar(string tipo)
{
	var_qnt++;
	Simbolo* s = new Simbolo;
	s->labelReal = varPrefix + to_string(var_qnt);
	s->tipoDeclarado = tipo;
	return s;
}

// Usado para verificar se existe uma variável de nome labelUsuario
bool varExiste(string labelUsuario)
{
	if (tabelaSimbolos.find(labelUsuario) != tabelaSimbolos.end())
	{
		return true;
	}
	return false;
}

// Usado para verificar se uma variável que EXISTA já foi inicializada
// OBS: Não verifica se a variável realmente existe
bool varInicializada(string labelUsuario)
{
	Simbolo* s = tabelaSimbolos[labelUsuario];
	return s-> simboloInicializado;
}

// Usado para retornar o nome real de uma variável que EXISTA na tabela de símbolos
// OBS: Não verifica se o símbolo existe ou não
string varNomeReal(string labelUsuario)
{
	Simbolo* s = tabelaSimbolos[labelUsuario];
	return s->labelReal;
}

//Usado para ver tipo do simbolo. OBS: Não verifica se o símbolo existe ou não
string varTipo(string labelUsuario)
{
	Simbolo* s = tabelaSimbolos[labelUsuario];
	return s->tipoDeclarado;
}

// Usado pelo bison para mostrar erros sintáticos
void yyerror(string MSG)
{
	cerr << "Erro: \"" << MSG << "\", em Linha: " << linha << " Coluna: " << coluna << endl;			
}

// Usado pelo compilador para tratar erros semânticos
// Depois de chamar ele, deve-se executar YYABORT na action
void semanticError(string MSG)
{
	fprintf(stderr, "Erro: \"%s\", em Linha: %d, Coluna: %d\n", MSG.c_str(), linha, coluna);
}

// Usado para inicializar as estruturas e controladores usados no compilador;
void initialize()
{
	var_temp_qnt = 0;
	var_qnt = 0;
}

int main(int argc, char* argv[])
{
	// Para aceitar todos os tipos de caractere
	std::setlocale(LC_ALL, "");

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
