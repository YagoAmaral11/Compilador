%{

#include <iostream>
#include <unordered_map>
#include <queue>
#include <string>
#include <locale>
#include <cstdlib>

using namespace std;

extern FILE* yyin; // yyin é o arquivo de entrada do flex; ao alterar, é possível redirecionar o fluxo da entrada do código fonte
#define YYSTYPE atributos // YYSTYPE é o tipo de valor usado para cada token da árvore sintática; É diferente do valor numérico gerador por %token
#define TIPO int // É um macro para diferenciar o tipo da variável; É possível usar os tokens de tipo (%token TIPO_...) pq os dois são int no fim

// Structs
// TODO: Criar estruturas melhores para identificar os Tokens
struct atributos
{
	string label; // "Endereço" dessa variável; O nome da variável que carrega o valor dessa árvore sintática
	string traducao; // A tradução dessa árvore sintática para o código intermediário
	TIPO tipo;	// Tipo do token
};

struct Simbolo
{	
	// Informações sobre o Simbolo
	string labelReal;	// O nome "verdadeiro" da variável no código intermediário;
	// TODO: Talvez seja melhor renomear essa var para somente "tipo"? já que em atributos também é somente tipo, ou fazer o contrário
	TIPO tipoDeclarado; // Tipo que foi declarado a variavel.

	// Informações sobre a declaração
	bool simboloInicializado; // Se esse símbolo já foi inicializado com algum valor; Caso contrário, não pode ser usado		
};

// Declarações de funções
int yylex(void);
void yyerror(string);
void semanticError(string MSG);
string novaVarTemp(TIPO tipo);
Simbolo* novaVar(TIPO tipo);
bool varExiste(string labelUsuario);
bool varInicializada(string labelUsuario);
string varNomeReal(string labelUsuario);
TIPO varTipo(string labelUsuario);
string tipoCodIntermediario(TIPO tipo);
bool tipoPodeSerAtribuido(TIPO tipoA, TIPO tipoB);
string tipoParaString(TIPO tipo);

// Variáveis
int var_temp_qnt; // Contador de variáveis temporárias
int var_qnt; // Contador de variáveis globais não temporárias criadas

int linha = 1; // Contador da linha do comando; Atualizado no lexer
int coluna = 0; // Contador de caracteres do comando; Atualizado no lexer

string codigo_gerado; // Código intermediário gerado pelo compilador
unordered_map<string, Simbolo*> tabelaSimbolos; // Tabela de símbolos
queue<string> ordemDeclaracaoSimbolos; // A ordem de declaração dos símbolos da tabela

queue<TIPO> tipoDosTemporarios; // O tipo de cada variável temporária; Está em ordem de declaração

// Macros
#define tmpVarPrefix "tmp"
#define varPrefix "var"
#define BOOL_TRUE 1 // Funciona pois no cod. intermediário o bool é um inteiro; Considerar 1 como true
#define BOOL_FALSE 0 // Funciona pois no cod. intermediário o bool é um inteiro; Considerar 0 como false

%}

/* TOKENS PARA OS DIFERENTES TIPOS GRAMATICAIS */
%token TK_NUM
%token TK_ID
%token TK_TIPO

%token TK_VAR

/* OBS: Cada novo tipo adicionado, deve-se criar um token desses e alterar o yylval.tipo para o token correspondente no lexer  */
/* 		É também necessário, para cada tipo novo, alterar: tipoCodIntermediario, tipoParaString e tipoPodeSerAtribuido 	*/
/* TOKEN PARA OS TIPOS DIFERENTES */
%token TIPO_INT
%token TIPO_FLOAT
%token TIPO_CHAR
%token TIPO_BOOL


%start OUTPUT

%right '='
/*Operadores relacionais*/
%left OP_DIFERENTE OP_IGUAL
%left OP_MENOR OP_MAIOR OP_MENOR_IGUAL OP_MAIOR_IGUAL

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
		int i = 0;
		while (!tipoDosTemporarios.empty())
		{			 
			TIPO tipoVar = tipoDosTemporarios.front();			
			// TODO: No futuro, verificar se esse tipo pode descrito facilmente assim no cod. intermediário
			codigo_gerado += "\t" + tipoCodIntermediario(tipoVar) + " " + tmpVarPrefix + to_string(i) + ";" + " // " + tipoParaString(tipoVar) + "\n";			

			tipoDosTemporarios.pop();
			i++;
		}						
		
		codigo_gerado += "\n\t// Variaveis Globais\n";				
		while (!ordemDeclaracaoSimbolos.empty())
		{			 
			string labelVar = ordemDeclaracaoSimbolos.front();
			Simbolo* s = tabelaSimbolos[labelVar];

			codigo_gerado += "\t// " + labelVar + ":\n";
			// TODO: No futuro, verificar se esse tipo pode descrito facilmente assim no cod. intermediário
			codigo_gerado += "\t" + tipoCodIntermediario(s->tipoDeclarado) + " " + s->labelReal + ";" + " // " + tipoParaString(s->tipoDeclarado) + " " + labelVar + "\n";

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
			semanticError("Símbolo não conhecido -> '" + $1.label + "' não é conhecido. Verifique se foi declarado.");
			YYABORT;
		}

		if (!varInicializada($1.label))
		{
			// A variável não foi inicializada ainda, erro			
			semanticError("Variável não inicializada -> '" + $1.label + "'. Não é possível usar uma variável não inicializada");
			YYABORT;
		}

		TIPO tipoId = varTipo($1.label);
		$$.label = novaVarTemp(tipoId);
		$$.tipo = tipoId;
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
		if ((($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT)) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			// Tipos de numeros iguais
			$$.label = novaVarTemp($1.tipo);
			$$.tipo = $1.tipo;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " + " + $3.label + ";\n";
		} 
		else
		{			
			semanticError("Expressao invalida -> o operador '+' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}
	}
	| EXPRESSAO '-' EXPRESSAO
	{
		if ((($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT)) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			// Tipos de numeros iguais
			$$.label = novaVarTemp($1.tipo);
			$$.tipo = $1.tipo;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " - " + $3.label + ";\n";
		} 
		else
		{			
			semanticError("Expressao invalida -> o operador '-' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}
	}
	| EXPRESSAO '*' EXPRESSAO
	{
		if ((($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT)) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			// Tipos de numeros iguais
			$$.label = novaVarTemp($1.tipo);
			$$.tipo = $1.tipo;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " * " + $3.label + ";\n";
		} 
		else
		{
			// TODO: Explicar que não pode-se realizar essa operação com os tipos de Expressão 1 e Expressão 2
			semanticError("Expressao invalida -> o operador '*' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}		
	}
	| EXPRESSAO '/' EXPRESSAO
	{
		if ((($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT)) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			// Tipos de numeros iguais
			$$.label = novaVarTemp($1.tipo);
			$$.tipo = $1.tipo;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " / " + $3.label + ";\n";
		} 
		else
		{
			// TODO: Explicar que não pode-se realizar essa operação com os tipos de Expressão 1 e Expressão 2
			semanticError("Expressao invalida -> o operador '/' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}
	}	
	|	EXPRESSAO OP_MAIOR EXPRESSAO
	{
		if(($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			$$.label = novaVarTemp(TIPO_BOOL);
			$$.tipo = TIPO_BOOL;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " > " + $3.label + ";\n";
		}
		else
		{
			semanticError("Expressao invalida -> o operador '>' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}
	}
	|	EXPRESSAO OP_MENOR EXPRESSAO
	{
		if(($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			$$.label = novaVarTemp(TIPO_BOOL);
			$$.tipo = TIPO_BOOL;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " < " + $3.label + ";\n";
		}
		else
		{
			semanticError("Expressao invalida -> o operador '<' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}
	}
	| EXPRESSAO OP_IGUAL EXPRESSAO
	{
		if(($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			$$.label = novaVarTemp(TIPO_BOOL);
			$$.tipo = TIPO_BOOL;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " == " + $3.label + ";\n";
		}
		else
		{
			semanticError("Expressao invalida -> o operador '==' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}
	}
	| EXPRESSAO OP_DIFERENTE EXPRESSAO
	{
		if(($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			$$.label = novaVarTemp(TIPO_BOOL);
			$$.tipo = TIPO_BOOL;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " != " + $3.label + ";\n";
		}
		else
		{
			semanticError("Expressao invalida -> o operador '!=' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}
	}
	|	EXPRESSAO OP_MENOR_IGUAL EXPRESSAO
	{
		if(($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			$$.label = novaVarTemp(TIPO_BOOL);
			$$.tipo = TIPO_BOOL;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " <= " + $3.label + ";\n";
		}
		else
		{
			semanticError("Expressao invalida -> o operador '<=' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}
	}
	|	EXPRESSAO OP_MAIOR_IGUAL EXPRESSAO
	{
		if(($1.tipo == TIPO_INT) && ($3.tipo == TIPO_INT) || (($1.tipo == TIPO_FLOAT) && ($3.tipo == TIPO_FLOAT)))
		{
			$$.label = novaVarTemp(TIPO_BOOL);
			$$.tipo = TIPO_BOOL;
			$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
				" = " + $1.label + " >= " + $3.label + ";\n";
		}
		else
		{
			semanticError("Expressao invalida -> o operador '>=' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}
	}
	
;

ATRIBUICAO:
	TK_ID '=' EXPRESSAO
	{		
		// Se a variável já foi declarada, apenas altera seu valor; 
		// Se a variável não era inicializada ainda, agora ela é;		
		if (!tipoPodeSerAtribuido(varTipo($1.label), $3.tipo))
		{
			semanticError("Erro de tipo -> A expressão de tipo '" + tipoParaString($3.tipo) + "' não é do tipo esperado (" + tipoParaString(varTipo($1.label)) + ").");
			YYABORT;
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + varNomeReal($1.label) + " = " + $3.label + ";" + " // " + $1.label + "\n";

		Simbolo* s = tabelaSimbolos[$1.label];
		s->simboloInicializado = true;		
	}
	|
	DECLARACAO '=' EXPRESSAO
	{
		// OBS: Declaração com inicialização; Em declaração a variável já é declarada corretamente; Aqui basta adicionar o valor da expressão se for do mesmo tipo e
		// 		adicionar uma tradução para esse nó
		if (!tipoPodeSerAtribuido(varTipo($1.label), $3.tipo))
		{
			semanticError("Erro de tipo -> Uma expressão de tipo '" + tipoParaString($3.tipo) + "' não pode ser usada para inicializar uma variável do tipo '" + tipoParaString(varTipo($1.label)) + "'.");
			YYABORT;
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + varNomeReal($1.label) + " = " + $3.label + ";" + " // " + $1.label + "\n";

		Simbolo* s = tabelaSimbolos[$1.label];
		s->simboloInicializado = true;
	}
	|
	TK_VAR TK_ID '=' EXPRESSAO
	{
		// OBS: Declaração implícita por inferência
		if (varExiste($2.label))
		{
			semanticError("Simbolo ja declarado -> '" + $2.label + "'. Nao e possivel declarar novamente, escolha outro nome.");
			YYABORT;
		}
		else
		{
			$$.label = $2.label;			

			Simbolo* s = novaVar($4.tipo);
			s->simboloInicializado = true;			

			tabelaSimbolos[$2.label] = s;						
			ordemDeclaracaoSimbolos.push($2.label);
			
			$$.traducao = $4.traducao + "\t" + varNomeReal($2.label) + " = " + $4.label + ";" + " // " + $2.label + "\n";
		}
	}
;

DECLARACAO:
	TK_TIPO TK_ID
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

			Simbolo* s = novaVar($1.tipo);

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
string novaVarTemp(TIPO tipo)
{
	string nome = tmpVarPrefix + to_string(var_temp_qnt++);

	Simbolo* s = new Simbolo;
	s->labelReal = nome;
	s->tipoDeclarado = tipo;		

	tipoDosTemporarios.push(tipo);

	return nome;
}

// Cria uma nova variável de usuário
Simbolo* novaVar(TIPO tipo)
{
	var_qnt++;
	Simbolo* s = new Simbolo;

	s->labelReal = varPrefix + to_string(var_qnt);
	s->tipoDeclarado = tipo;
	s->simboloInicializado = false;

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

// Usado para ver tipo do simbolo. 
// OBS: Não verifica se o símbolo existe ou não
TIPO varTipo(string labelUsuario)
{
	Simbolo* s = tabelaSimbolos[labelUsuario];
	return s->tipoDeclarado;
}

// Retorna, dado um tipo, qual é a string para declarar aquele tipo no código intermediário
// OBS: Não verifica se é possível declarar diretamente aquele tipo no código intermediário.
string tipoCodIntermediario(TIPO tipo)
{
	switch (tipo)
	{
		case TIPO_INT:
			return "int";
			break;
		case TIPO_BOOL:
			return "int";
			break;
		case TIPO_FLOAT:
			return "float";
			break;
		case TIPO_CHAR:
			return "char";
			break;
	}
	return "";
}

// Retorna, dado um tipo, qual é a string correspondente do nome daquele tipo.
// OBS: É diferente do tipo usado para representar esse tipo no código intermediário
// OBS²: Não verifica se o tipo passado é válido
string tipoParaString(TIPO tipo)
{
	switch (tipo)
	{
		case TIPO_INT:
			return "int";
			break;
		case TIPO_BOOL:
			return "bool";
			break;
		case TIPO_FLOAT:
			return "float";
			break;
		case TIPO_CHAR:
			return "char";
			break;
	}
	return "unknown";
}

// Retorna, dado um tipo A, se tipo B pode ser atribuído à tipo A.
// TODO: No futuro, isso deve ser alterado para funcionar com conversões implícitas; No momento apenas verifica se dois tipos são iguais
bool tipoPodeSerAtribuido(TIPO tipoA, TIPO tipoB)
{
	if (tipoA == tipoB)
	{
		return true;
	}
	return false;
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
