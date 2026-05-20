%{

#include <iostream>
#include <unordered_map>
#include <queue>
#include <string>
#include <locale>
#include <cstdlib>
#include <utility>
#include <vector>

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

// Usado para definir qual tipo de conversão um tipo pode ter
enum class TipoDeConversao
{
	Nenhuma,
	Explicita,
	Implicita
};

// Usado na tabela de conversões para ditar informações sobre as conversões
struct ConversaoInfo
{
	TipoDeConversao tipo;	
};

// Usado na tabela de conversão para gerar uma hash para um pair<T1,T2>, para que seja possível
// usar pair<TIPO, TIPO> como chave
struct pair_hash 
{
    template <class T1, class T2>
    std::size_t operator()(const std::pair<T1, T2>& p) const 
	{
        auto h1 = std::hash<T1>{}(p.first);
        auto h2 = std::hash<T2>{}(p.second);
        // Combinação simples dos hashes
        return h1 ^ (h2 << 1);
    }
};

// Declarações de funções
int yylex(void);
void yyerror(string);
void semanticError(string MSG);
string novaVarTemp(TIPO tipo);
Simbolo* novaVar(TIPO tipo);
bool varExiste(string labelUsuario);
bool varExisteNoEscopoAtual(string labelUsuario);
bool varInicializada(string labelUsuario);
string varNomeReal(string labelUsuario);
TIPO varTipo(string labelUsuario);
string tipoCodIntermediario(TIPO tipo);
bool tipoPodeSerAtribuido(TIPO tipoA, TIPO tipoB);
string tipoParaString(TIPO tipo);
bool expressaoTiposIguais(atributos exp1, atributos exp2);
void inicializarTabelaConversao();
bool podeSerConvertidoExplicitamente(TIPO a, TIPO b);
bool podeSerConvertidoImplicitamente(TIPO a, TIPO b);
bool operadorRelacionalDireto(YYSTYPE exp1, YYSTYPE exp2, int operador, string operadorCodInt, string& codIntFinal, string& labelFinal);
int conversaoImpicitaOperadorBinario(YYSTYPE exp1, YYSTYPE exp2, int operador, string operadorCodIntermediario, string& labelConvertido, string& tradConversao);
string ConversaoCodIntermediario(string labelA, TIPO tipoB, string& labelB);
bool operadorFuncionaEmTipo(int operadorOuToken, TIPO tipo);
void inicializarTabelaDeOperadores();
void tabelaDeOperadoresAdd(int operador, TIPO tipo);
void empilharEscopo();
void desempilharEscopo();
Simbolo* obterSimbolo(string labelUsuario);

// Variáveis
int var_temp_qnt; // Contador de variáveis temporárias
int var_qnt; // Contador de variáveis globais não temporárias criadas

int linha = 1; // Contador da linha do comando; Atualizado no lexer
int coluna = 0; // Contador de caracteres do comando; Atualizado no lexer

string codigo_gerado; // Código intermediário gerado pelo compilador
vector<unordered_map<string, Simbolo*>> tabelaSimbolos; // Tabela de símbolos
queue<string> ordemDeclaracaoSimbolos; // A ordem de declaração dos símbolos da tabela; TODO: Essa estrutura ainda precisa existir? Remover depois
 
queue<TIPO> tipoDosTemporarios; // O tipo de cada variável temporária; Está em ordem de declaração

// Tabela de conversão; Verifica se o tipo da esquerda pode se converter no tipo da direita
// OBS: Não tem a diagonal principal (onde o tipo A == B) por simplicidade;
// OBS²: Tipos que não estejam na tabela infere-se que não é possível realizar nenhuma conversão, i. e., tipo A não consegue se converter no tipo B
unordered_map<pair<TIPO, TIPO>, ConversaoInfo, pair_hash> tabelaConversao; 

// Dado um operador (um char, um token de operador, etc.), verifica se é possível operar sobre o TIPO passado
// OBS: Tipos que não estejam na tabela infere-se que não é possível realizar nenhuma operação, i. e., o operador passado não pode ser usado
// OBS²: Note que essa não é uma tabela de conversões; Ela apenas verifica, para um par de variáveis de um tipo, se o operador passado pode ser usado
unordered_map<pair<int, TIPO>, bool, pair_hash> tabelaOperadores;

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

%token OP_NOT OP_AND OP_OR



/* OBS: Cada novo tipo adicionado, deve-se criar um token desses e alterar o yylval.tipo para o token correspondente no lexer  */
/* 		É também necessário, para cada tipo novo, alterar: tipoCodIntermediario, tipoParaString, inicializarTabelaConversao e inicializarTabelaDeOperadores 	*/
/* TOKEN PARA OS TIPOS DIFERENTES */
%token TIPO_INT
%token TIPO_FLOAT
%token TIPO_CHAR
%token TIPO_BOOL


%start OUTPUT

%right '='

/*Operadores logicos*/
%left OP_OR
%left OP_AND

%left OP_DIFERENTE OP_IGUAL
%left OP_MENOR OP_MAIOR OP_MENOR_IGUAL OP_MAIOR_IGUAL

%left '+' '-'
%left '*' '/'
%left OP_NOT
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
			Simbolo* s = obterSimbolo(labelVar);

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
	| BLOCO
	{
		$$.traducao = $1.traducao;
	}
;

BLOCO:
	'{' { empilharEscopo(); } PROGRAMA_MINIMO '}'
	{
		desempilharEscopo();
		$$.traducao =  $3.traducao;
	}

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
	| 
	'(' TK_TIPO ')' EXPRESSAO
	{
		// Conversão Explícita
		TIPO tipoExpressao = $4.tipo;		
		TIPO novoTipo = $2.tipo;
		string novaLabel;
		string tradConversao;		

		if (podeSerConvertidoExplicitamente(tipoExpressao, novoTipo))
		{
			tradConversao = ConversaoCodIntermediario($4.label, novoTipo, novaLabel);
		}
		else
		{
			semanticError("Expressão inválida -> O tipo '" + tipoParaString($4.tipo) + "' não pode ser convertido para o tipo '" + tipoParaString(novoTipo) + "'");
			YYABORT;
		}

		$$.label = novaLabel;
		$$.tipo = novoTipo;
		$$.traducao = $4.traducao + "\t" + tradConversao;
	}
	| EXPRESSAO '+' EXPRESSAO
	{				
		TIPO tipoFinal;
		string tradConversão = "";
		string labelEsq;
		string labelDir;
		string operadorCodInt = "+";
		int operador = '+';

		if (expressaoTiposIguais($1, $3) && operadorFuncionaEmTipo(operador, $1.tipo))
		{
			tipoFinal = $1.tipo;
			labelEsq = $1.label;
			labelDir = $3.label;
		} 
		else if (operadorFuncionaEmTipo(operador, $1.tipo) && podeSerConvertidoImplicitamente($3.tipo, $1.tipo))
		{
			// Expressão 2 pode ser convertida no tipo de Expressão 1
			tipoFinal = $1.tipo;
			labelEsq = $1.label;
			tradConversão = ConversaoCodIntermediario($3.label, $1.tipo, labelDir) + "\t";
		}
		else if (podeSerConvertidoImplicitamente($1.tipo, $3.tipo) && operadorFuncionaEmTipo(operador, $3.tipo))
		{
			// Expressão 1 pode ser convertida no tipo de Expressão 2
			tipoFinal = $3.tipo;
			tradConversão = ConversaoCodIntermediario($1.label, $3.tipo, labelEsq) + "\t";
			labelDir = $3.label;
		}	
		else
		{				
			// Quando não é possível realizar nenhuma conversão implícita, os tipos não sou iguais ou não é possível operar sobre esse tipo
			semanticError("Expressao invalida -> o operador '" + operadorCodInt + "' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}		

		$$.label = novaVarTemp(tipoFinal);
		$$.tipo = tipoFinal;
		$$.traducao = $1.traducao + $3.traducao + "\t" + tradConversão + $$.label + " = " + labelEsq + " " + operadorCodInt + " " + labelDir + ";\n";

	}
	| EXPRESSAO '-' EXPRESSAO
	{
		TIPO tipoFinal;
		string tradConversão = "";
		string labelEsq;
		string labelDir;
		string operadorCodInt = "-";
		int operador = '-';

		if (expressaoTiposIguais($1, $3) && operadorFuncionaEmTipo(operador, $1.tipo))
		{
			tipoFinal = $1.tipo;
			labelEsq = $1.label;
			labelDir = $3.label;
		} 
		else if (operadorFuncionaEmTipo(operador, $1.tipo) && podeSerConvertidoImplicitamente($3.tipo, $1.tipo))
		{
			// Expressão 2 pode ser convertida no tipo de Expressão 1
			tipoFinal = $1.tipo;
			labelEsq = $1.label;
			tradConversão = ConversaoCodIntermediario($3.label, $1.tipo, labelDir) + "\t";
		}
		else if (podeSerConvertidoImplicitamente($1.tipo, $3.tipo) && operadorFuncionaEmTipo(operador, $3.tipo))
		{
			// Expressão 1 pode ser convertida no tipo de Expressão 2
			tipoFinal = $3.tipo;
			tradConversão = ConversaoCodIntermediario($1.label, $3.tipo, labelEsq) + "\t";
			labelDir = $3.label;
		}	
		else
		{				
			// Quando não é possível realizar nenhuma conversão implícita, os tipos não sou iguais ou não é possível operar sobre esse tipo
			semanticError("Expressao invalida -> o operador '" + operadorCodInt + "' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}		

		$$.label = novaVarTemp(tipoFinal);
		$$.tipo = tipoFinal;
		$$.traducao = $1.traducao + $3.traducao + "\t" + tradConversão + $$.label + " = " + labelEsq + " " + operadorCodInt + " " + labelDir + ";\n";
		
	}
	| EXPRESSAO '*' EXPRESSAO
	{
		TIPO tipoFinal;
		string tradConversão = "";
		string labelEsq;
		string labelDir;
		string operadorCodInt = "*";
		int operador = '*';

		if (expressaoTiposIguais($1, $3) && operadorFuncionaEmTipo(operador, $1.tipo))
		{
			tipoFinal = $1.tipo;
			labelEsq = $1.label;
			labelDir = $3.label;
		} 
		else if (operadorFuncionaEmTipo(operador, $1.tipo) && podeSerConvertidoImplicitamente($3.tipo, $1.tipo))
		{
			// Expressão 2 pode ser convertida no tipo de Expressão 1
			tipoFinal = $1.tipo;
			labelEsq = $1.label;
			tradConversão = ConversaoCodIntermediario($3.label, $1.tipo, labelDir) + "\t";
		}
		else if (podeSerConvertidoImplicitamente($1.tipo, $3.tipo) && operadorFuncionaEmTipo(operador, $3.tipo))
		{
			// Expressão 1 pode ser convertida no tipo de Expressão 2
			tipoFinal = $3.tipo;
			tradConversão = ConversaoCodIntermediario($1.label, $3.tipo, labelEsq) + "\t";
			labelDir = $3.label;
		}	
		else
		{				
			// Quando não é possível realizar nenhuma conversão implícita, os tipos não sou iguais ou não é possível operar sobre esse tipo
			semanticError("Expressao invalida -> o operador '" + operadorCodInt + "' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}		

		$$.label = novaVarTemp(tipoFinal);
		$$.tipo = tipoFinal;
		$$.traducao = $1.traducao + $3.traducao + "\t" + tradConversão + $$.label + " = " + labelEsq + " " + operadorCodInt + " " + labelDir + ";\n";
		
	}
	| EXPRESSAO '/' EXPRESSAO
	{
		TIPO tipoFinal;
		string tradConversão = "";
		string labelEsq;
		string labelDir;
		string operadorCodInt = "/";
		int operador = '/';

		if (expressaoTiposIguais($1, $3) && operadorFuncionaEmTipo(operador, $1.tipo))
		{
			tipoFinal = $1.tipo;
			labelEsq = $1.label;
			labelDir = $3.label;
		} 
		else if (operadorFuncionaEmTipo(operador, $1.tipo) && podeSerConvertidoImplicitamente($3.tipo, $1.tipo))
		{
			// Expressão 2 pode ser convertida no tipo de Expressão 1
			tipoFinal = $1.tipo;
			labelEsq = $1.label;
			tradConversão = ConversaoCodIntermediario($3.label, $1.tipo, labelDir) + "\t";
		}
		else if (podeSerConvertidoImplicitamente($1.tipo, $3.tipo) && operadorFuncionaEmTipo(operador, $3.tipo))
		{
			// Expressão 1 pode ser convertida no tipo de Expressão 2
			tipoFinal = $3.tipo;
			tradConversão = ConversaoCodIntermediario($1.label, $3.tipo, labelEsq) + "\t";
			labelDir = $3.label;
		}	
		else
		{				
			// Quando não é possível realizar nenhuma conversão implícita, os tipos não sou iguais ou não é possível operar sobre esse tipo
			semanticError("Expressao invalida -> o operador '" + operadorCodInt + "' não pode ser aplicado entre os tipos " + tipoParaString($1.tipo) + " e " + tipoParaString($3.tipo));
			YYABORT;
		}		

		$$.label = novaVarTemp(tipoFinal);
		$$.tipo = tipoFinal;
		$$.traducao = $1.traducao + $3.traducao + "\t" + tradConversão + $$.label + " = " + labelEsq + " " + operadorCodInt + " " + labelDir + ";\n";
		
	}		
    | EXPRESSAO OP_MAIOR EXPRESSAO
	{
		string codIntFinal = "";
		string labelFinal = "";

		if (!operadorRelacionalDireto($1, $3, OP_MAIOR, ">", codIntFinal, labelFinal))
		{
			YYABORT;
		}

		$$.label = labelFinal;
		$$.traducao = codIntFinal;
		$$.tipo = TIPO_BOOL;
	}
	| EXPRESSAO OP_MENOR EXPRESSAO
	{
		string codIntFinal = "";
		string labelFinal = "";

		if (!operadorRelacionalDireto($1, $3, OP_MENOR, "<", codIntFinal, labelFinal))
		{
			YYABORT;
		}

		$$.label = labelFinal;
		$$.traducao = codIntFinal;
		$$.tipo = TIPO_BOOL;
	}
	| EXPRESSAO OP_IGUAL EXPRESSAO
	{
		string codIntFinal = "";
		string labelFinal = "";

		if (!operadorRelacionalDireto($1, $3, OP_IGUAL, "==", codIntFinal, labelFinal))
		{
			YYABORT;
		}

		$$.label = labelFinal;
		$$.traducao = codIntFinal;
		$$.tipo = TIPO_BOOL;
	}
	| EXPRESSAO OP_DIFERENTE EXPRESSAO
	{
		string labelEsq = $1.label;
		string labelDir = $3.label;
		string tradConversao = "";
		string labelConvertido = "";	

		int resultadoConversao = conversaoImpicitaOperadorBinario($1, $3, OP_DIFERENTE, "!=", labelConvertido, tradConversao);

		if (resultadoConversao == 0)
		{
			// Ninguém foi convertido, só aplicar o operador no código intermediário		
		}
		else if (resultadoConversao == 1)
		{
			// exp2 foi convertido
			labelDir = labelConvertido;
		}
		else if (resultadoConversao == 2)
		{
			// exp1 foi convertido
			labelEsq = labelConvertido;
		}
		else if (resultadoConversao == -1)
		{
			// Erro; Operador não pode e não foi realizada nenhuma conversão
			YYABORT;
		}		

		if (resultadoConversao > 0)
		{
			tradConversao = tradConversao + "\t";
		}

		string labelExp = novaVarTemp(TIPO_BOOL);	
		$$.label = novaVarTemp(TIPO_BOOL);
		$$.tipo = TIPO_BOOL;		

		$$.traducao = $1.traducao + $3.traducao + "\t" + tradConversao + labelExp +
				" = " + labelEsq + " == " + labelDir + ";\n" + "\t" + $$.label + " = " + "!" + labelExp + ";\n";
	}
	| EXPRESSAO OP_MENOR_IGUAL EXPRESSAO
	{
		string codIntFinal = "";
		string labelFinal = "";

		if (!operadorRelacionalDireto($1, $3, OP_MENOR_IGUAL, "<=", codIntFinal, labelFinal))
		{
			YYABORT;
		}

		$$.label = labelFinal;
		$$.traducao = codIntFinal;
		$$.tipo = TIPO_BOOL;
	}
	| EXPRESSAO OP_MAIOR_IGUAL EXPRESSAO
	{
		string codIntFinal = "";
		string labelFinal = "";

		if (!operadorRelacionalDireto($1, $3, OP_MAIOR_IGUAL, ">=", codIntFinal, labelFinal))
		{
			YYABORT;
		}

		$$.label = labelFinal;
		$$.traducao = codIntFinal;
		$$.tipo = TIPO_BOOL;
	}
	| OP_NOT EXPRESSAO
	{
		string labelExp = "";
		string tradConversao = "";

		if (operadorFuncionaEmTipo(OP_NOT, $2.tipo))
		{
			// Expressão já é booleana; Só negar
			labelExp = $2.label;
		}
		else if (podeSerConvertidoImplicitamente($2.tipo, TIPO_BOOL))
		{
			// Expressão pode virar uma booleana;
			tradConversao = ConversaoCodIntermediario($2.label, TIPO_BOOL, labelExp) + "\t";
		}
		else
		{
			semanticError("Expressao invalida -> o operador '!' não pode ser aplicado ao tipo " + tipoParaString($2.tipo));
			YYABORT;
		}

		$$.label = novaVarTemp(TIPO_BOOL);
		$$.tipo = TIPO_BOOL;
		$$.traducao = $2.traducao + "\t" + tradConversao + $$.label + " = !" + labelExp + ";\n";				
	}
	| EXPRESSAO OP_AND EXPRESSAO
	{
		string codIntFinal = "";
		string labelFinal = "";

		if (!operadorRelacionalDireto($1, $3, OP_AND, "&&", codIntFinal, labelFinal))
		{
			YYABORT;
		}

		$$.label = labelFinal;
		$$.traducao = codIntFinal;
		$$.tipo = TIPO_BOOL;
	}
	| EXPRESSAO OP_OR EXPRESSAO
	{		
		string codIntFinal = "";
		string labelFinal = "";

		if (!operadorRelacionalDireto($1, $3, OP_OR, "||", codIntFinal, labelFinal))
		{
			YYABORT;
		}

		$$.label = labelFinal;
		$$.traducao = codIntFinal;
		$$.tipo = TIPO_BOOL;
	}
;

ATRIBUICAO:
	TK_ID '=' EXPRESSAO
	{		
		// Se a variável já foi declarada, apenas altera seu valor; 
		// Se a variável não era inicializada ainda, agora ela é;		
		string labelExp = $3.label;
		string tradConversao = "";

		if (!tipoPodeSerAtribuido(varTipo($1.label), $3.tipo))
		{
			semanticError("Erro de tipo -> A expressão de tipo '" + tipoParaString($3.tipo) + "' não é do tipo esperado (" + tipoParaString(varTipo($1.label)) + ").");
			YYABORT;
		}
		if (varTipo($1.label) != $3.tipo)
		{
			// Deve ser feita uma conversão implícita, a expressão pode ser atribuída à essa variável, caso contrário a condicional de cima daria erro
			tradConversao = ConversaoCodIntermediario($3.label, varTipo($1.label), labelExp) + "\t";
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + tradConversao + varNomeReal($1.label) + " = " + labelExp + ";" + " // " + $1.label + "\n";

		Simbolo* s = obterSimbolo($1.label);
		s->simboloInicializado = true;		
	}
	|
	DECLARACAO '=' EXPRESSAO
	{
		// OBS: Declaração com inicialização; Em declaração a variável já é declarada corretamente; Aqui basta adicionar o valor da expressão se for do mesmo tipo e
		// 		adicionar uma tradução para esse nó
		string labelExp = $3.label;
		string tradConversao = "";

		if (!tipoPodeSerAtribuido(varTipo($1.label), $3.tipo))
		{
			semanticError("Erro de tipo -> Uma expressão de tipo '" + tipoParaString($3.tipo) + "' não pode ser atribuída em uma variável do tipo '" + tipoParaString(varTipo($1.label)) + "'.");
			YYABORT;
		}
		if (varTipo($1.label) != $3.tipo)
		{
			// Deve ser feita uma conversão implícita, a expressão pode ser atribuída à essa variável, caso contrário a condicional de cima daria erro
			tradConversao = ConversaoCodIntermediario($3.label, varTipo($1.label), labelExp) + "\t";
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + tradConversao + varNomeReal($1.label) + " = " + labelExp + ";" + " // " + $1.label + "\n";

		Simbolo* s = obterSimbolo($1.label);
		s->simboloInicializado = true;
	}
	|
	TK_VAR TK_ID '=' EXPRESSAO
	{
		// OBS: Declaração implícita por inferência
		if (varExisteNoEscopoAtual($2.label))
		{
			semanticError("Simbolo ja declarado -> '" + $2.label + "'. Nao e possivel declarar novamente, escolha outro nome.");
			YYABORT;
		}
		else
		{
			$$.label = $2.label;			

			Simbolo* s = novaVar($4.tipo);
			s->simboloInicializado = true;			

			tabelaSimbolos.back()[$2.label] = s;						
			ordemDeclaracaoSimbolos.push($2.label);
			
			$$.traducao = $4.traducao + "\t" + varNomeReal($2.label) + " = " + $4.label + ";" + " // " + $2.label + "\n";
		}
	}
;

DECLARACAO:
	TK_TIPO TK_ID
	{
		if (varExisteNoEscopoAtual($2.label))
		{
			semanticError("Simbolo ja declarado -> '" + $2.label + "'. Nao e possivel declarar novamente, escolha outro nome.");
			YYABORT;
		}
		else
		{
			$$.label = $2.label;
			$$.traducao = "";

			Simbolo* s = novaVar($1.tipo);

			tabelaSimbolos.back()[$2.label] = s;
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


void empilharEscopo()
{
	tabelaSimbolos.push_back(unordered_map<string, Simbolo*>());
}

void desempilharEscopo()
{
	tabelaSimbolos.pop_back();
}

Simbolo* obterSimbolo(string labelUsuario)
{
	for(auto it = tabelaSimbolos.rbegin(); it != tabelaSimbolos.rend(); ++it)
	{
		if (it->find(labelUsuario) != it->end())
		{
			return it->at(labelUsuario);
		}
	}
	return NULL;
}

// Usado para verificar se existe uma variável de nome labelUsuario no escopo atual(bloco atual, função atual, etc.)
bool varExisteNoEscopoAtual(string labelUsuario)
{
	return tabelaSimbolos.back().find(labelUsuario) != tabelaSimbolos.back().end();
}

// Usado para verificar se existe uma variável de nome labelUsuario
bool varExiste(string labelUsuario){
	return obterSimbolo(labelUsuario) != NULL;
}

// Usado para verificar se uma variável que EXISTA já foi inicializada
// OBS: Não verifica se a variável realmente existe
bool varInicializada(string labelUsuario)
{
	Simbolo* s = obterSimbolo(labelUsuario);
	return s ? s-> simboloInicializado : false;
}

// Usado para retornar o nome real de uma variável que EXISTA na tabela de símbolos
// OBS: Não verifica se o símbolo existe ou não
string varNomeReal(string labelUsuario)
{
	Simbolo* s = obterSimbolo(labelUsuario);
	return s ? s->labelReal : "";
}

// Usado para ver tipo do simbolo. 
// OBS: Não verifica se o símbolo existe ou não
TIPO varTipo(string labelUsuario)
{
	Simbolo* s = obterSimbolo(labelUsuario);
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

// Retorna, dada duas expressões, se os tipos são iguais
bool expressaoTiposIguais(YYSTYPE exp1, YYSTYPE exp2)
{
	return exp1.tipo == exp2.tipo;
}

// Retorna, dado um tipo A, se tipo B pode ser atribuído à tipo A.
bool tipoPodeSerAtribuido(TIPO tipoA, TIPO tipoB)
{
	if (tipoA == tipoB)
	{
		return true;
	}
	if (podeSerConvertidoImplicitamente(tipoB, tipoA))
	{
		return true;
	}
	return false;
}

// Retorna se o operador/token 'operadorOuToken' pode ser usado em uma expressão do tipo 'tipo'
bool operadorFuncionaEmTipo(int operadorOuToken, TIPO tipo)
{
	pair<int, TIPO> op { operadorOuToken, tipo };
	if (tabelaOperadores.find(op) != tabelaOperadores.end())
	{
		return tabelaOperadores[op];
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

// Função para criar a tabela de conversão
void inicializarTabelaConversao()
{
	pair<TIPO, TIPO> tipoAtual;
	ConversaoInfo conversaoInfoAtual {TipoDeConversao::Nenhuma};		

	// CONVERSÕES DE INT
	tipoAtual = {TIPO_INT, TIPO_FLOAT};
	conversaoInfoAtual.tipo = TipoDeConversao::Implicita;
	tabelaConversao[tipoAtual] = conversaoInfoAtual;

	// CONVERSÕES DE FLOAT
	tipoAtual = {TIPO_FLOAT, TIPO_INT};
	conversaoInfoAtual.tipo = TipoDeConversao::Explicita;
	tabelaConversao[tipoAtual] = conversaoInfoAtual;

	// CONVERSÕES DE BOOL

	// CONVERSÕES DE CHAR
}

void inicializarTabelaDeOperadores()
{	
	// INT
	tabelaDeOperadoresAdd('+', TIPO_INT);
	tabelaDeOperadoresAdd('-', TIPO_INT);
	tabelaDeOperadoresAdd('*', TIPO_INT);
	tabelaDeOperadoresAdd('/', TIPO_INT);
	tabelaDeOperadoresAdd(OP_MAIOR, TIPO_INT);
	tabelaDeOperadoresAdd(OP_MENOR, TIPO_INT);
	tabelaDeOperadoresAdd(OP_IGUAL, TIPO_INT);
	tabelaDeOperadoresAdd(OP_DIFERENTE, TIPO_INT);
	tabelaDeOperadoresAdd(OP_MAIOR_IGUAL, TIPO_INT);
	tabelaDeOperadoresAdd(OP_MENOR_IGUAL, TIPO_INT);

	// FLOAT	
	tabelaDeOperadoresAdd('+', TIPO_FLOAT);
	tabelaDeOperadoresAdd('-', TIPO_FLOAT);
	tabelaDeOperadoresAdd('*', TIPO_FLOAT);
	tabelaDeOperadoresAdd('/', TIPO_FLOAT);
	tabelaDeOperadoresAdd(OP_MAIOR, TIPO_FLOAT);
	tabelaDeOperadoresAdd(OP_MENOR, TIPO_FLOAT);
	tabelaDeOperadoresAdd(OP_IGUAL, TIPO_FLOAT);
	tabelaDeOperadoresAdd(OP_DIFERENTE, TIPO_FLOAT);
	tabelaDeOperadoresAdd(OP_MAIOR_IGUAL, TIPO_FLOAT);
	tabelaDeOperadoresAdd(OP_MENOR_IGUAL, TIPO_FLOAT);
	
	// BOOL
	tabelaDeOperadoresAdd(OP_AND, TIPO_BOOL);
	tabelaDeOperadoresAdd(OP_OR, TIPO_BOOL);
	tabelaDeOperadoresAdd(OP_NOT, TIPO_BOOL);	
	tabelaDeOperadoresAdd(OP_IGUAL, TIPO_BOOL);
	tabelaDeOperadoresAdd(OP_DIFERENTE, TIPO_BOOL);

	// CHAR
	tabelaDeOperadoresAdd(OP_IGUAL, TIPO_CHAR);
	tabelaDeOperadoresAdd(OP_DIFERENTE, TIPO_CHAR);

}

// Usado para adicionar uma linha na tabela de operadores
void tabelaDeOperadoresAdd(int operador, TIPO tipo)
{
	pair<int, TIPO> op { operador, tipo };
	tabelaOperadores[op] = true;
}

// Verifica se um tipo A pode ser convertido em um tipo B explicitamente
bool podeSerConvertidoExplicitamente(TIPO a, TIPO b)
{
	pair<TIPO, TIPO> conv(a, b);

	if (tabelaConversao.find(conv) != tabelaConversao.end())
	{
		ConversaoInfo info = tabelaConversao[conv];

		if (info.tipo == TipoDeConversao::Implicita || info.tipo == TipoDeConversao::Explicita)
		{
			return true;
		}
	}

	return false;
}

// Verifica se um tipo A pode ser convertido em um tipo B implicitamente
bool podeSerConvertidoImplicitamente(TIPO a, TIPO b)
{
	pair<TIPO, TIPO> conv(a, b);

	if (tabelaConversao.find(conv) != tabelaConversao.end())
	{
		ConversaoInfo info = tabelaConversao[conv];

		if (info.tipo == TipoDeConversao::Implicita)
		{
			return true;
		}
	}

	return false;
}

// Para operadores binários, verifica para duas expressões, se elas são de tipos iguais e o operador passado pode operar sobre elas, se sim retorna 0
// OU tenta converter implicitamente um lado para o tipo do outro que o operador passado pode operar, se sim retorna (1 para o tipo da direita convertido, 2 para o tipo da esquerda convertido)
// OU printa um erro semântico quando o operador passado não pode ser aplicado para essa expressão, se sim retorna -1
// operador = tipo do operador, ex.: OP_AND, OP_NOT, '*', '+'
// operadorCodIntermediario = a string usada para representar o operador no código intermediário, ex.: "&&", "!", "*", "+"
// labelConvertido = uma string, passada por referência, do novo label que deve ser usado para a expressão que foi implicitamente convertida no tipo da outra
// tradConversao = a tradução referente à conversão implícita de das expressões (sem nenhum \t no final). Se não ocorrer nenhuma, é igual à "" (string vazia)
int conversaoImpicitaOperadorBinario(YYSTYPE exp1, YYSTYPE exp2, int operador, string operadorCodIntermediario, string& labelConvertido, string& tradConversao)
{
	if (expressaoTiposIguais(exp1, exp2) && operadorFuncionaEmTipo(operador, exp1.tipo))
	{
		return 0;
	}
	else if (operadorFuncionaEmTipo(operador, exp1.tipo) && podeSerConvertidoImplicitamente(exp2.tipo, exp1.tipo))
	{
		// Expressão 2 pode ser convertida no tipo de Expressão 1				
		tradConversao = ConversaoCodIntermediario(exp2.label, exp1.tipo, labelConvertido);
		return 1;
	}
	else if (podeSerConvertidoImplicitamente(exp1.tipo, exp2.tipo) && operadorFuncionaEmTipo(operador, exp2.tipo))
	{
		// Expressão 1 pode ser convertida no tipo de Expressão 2		
		tradConversao = ConversaoCodIntermediario(exp1.label, exp2.tipo, labelConvertido);
		return 2;
	}	
	else
	{				
		// Quando não é possível realizar nenhuma conversão implícita, os tipos não sou iguais ou não é possível operar sobre esse tipo
		semanticError("Expressao invalida -> o operador '" + operadorCodIntermediario + "' não pode ser aplicado entre os tipos " + tipoParaString(exp1.tipo) + " e " + tipoParaString(exp2.tipo));
		return -1;
	}		
}

// Para os operadores relacionais, que funcionam e tem sintaxe idêntica ao C, podendo ser traduzidos diretamente para o código intermediário
// retorna verdadeiro se a semântica está correta
bool operadorRelacionalDireto(YYSTYPE exp1, YYSTYPE exp2, int operador, string operadorCodInt, string& codIntFinal, string& labelFinal)
{	
	string labelEsq = exp1.label;
	string labelDir = exp2.label;
	string tradConversao = "";
	string labelConvertido = "";	
	int resultadoConversao = conversaoImpicitaOperadorBinario(exp1, exp2, operador, operadorCodInt, labelConvertido, tradConversao);

	if (resultadoConversao == 0)
	{
		// Ninguém foi convertido, só aplicar o operador no código intermediário		
	}
	else if (resultadoConversao == 1)
	{
		// exp2 foi convertido
		labelDir = labelConvertido;
	}
	else if (resultadoConversao == 2)
	{
		// exp1 foi convertido
		labelEsq = labelConvertido;
	}
	else if (resultadoConversao == -1)
	{
		return false;
	}

	labelFinal = novaVarTemp(TIPO_BOOL);

	if (resultadoConversao > 0)
	{
		tradConversao = tradConversao + "\t";
	}

	codIntFinal = exp1.traducao + exp2.traducao + "\t" + tradConversao + labelFinal + " = " + labelEsq + " " + operadorCodInt + " " + labelDir + ";\n";
	return true;
}

// Realiza uma conversão simples no código intermediário (por meio de cast no C) com label 'labelA' para uma do tipo 'B',
// retornando o código intermediário dessa conversão e o label da variável temporário que guarda a variável convertida 'labelB'
// OBS: Não verifica se a conversão pode ou não ser feita, apenas faz um casting no código intermediário; Para verificar, use 
// podeSerConvertidoExplicitamente ou podeSerConvertidoImplicitamente
string ConversaoCodIntermediario(string labelA, TIPO tipoB, string& labelB)
{
	string s; 
	labelB = novaVarTemp(tipoB);
	s = labelB + " = " + "(" + tipoCodIntermediario(tipoB) + ")" + " " + labelA + ";\n";
	return s;
}

// Usado para inicializar as estruturas e controladores usados no compilador;
void initialize()
{
	var_temp_qnt = 0;
	var_qnt = 0;

	inicializarTabelaConversao();
	inicializarTabelaDeOperadores();

	empilharEscopo();
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
