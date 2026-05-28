%{

#include <iostream>
#include <unordered_map>
#include <queue>
#include <string>
#include <locale>
#include <cstdlib>
#include <utility>
#include <vector>
#include <fstream>
#include <cstring>
#include <stdlib.h>

using namespace std;

extern FILE* yyin; // yyin é o arquivo de entrada do flex; ao alterar, é possível redirecionar o fluxo da entrada do código fonte
#define YYSTYPE atributos // YYSTYPE é o tipo de valor usado para cada token da árvore sintática; É diferente do valor numérico gerador por %token
#define TIPO int // É um macro para diferenciar o tipo da variável; É possível usar os tokens de tipo (%token TIPO_...) pq os dois são int no fim
#define str_length_suffix "_strlen" // Usado ao declarar string dinâmicas; Um inteiro de mesmo nome da variável usada para guardar a string terá esse sufixo

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
	string labelUsuario; // O nome da variável no código fonte;
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

// Usado em uma tabela para guardar informações sobre uma string, seja ela de usuário ou não
struct StringInfo
{
	bool éDinâmica;
	int tamanho;
};

// Declarações de funções
int yylex(void);
void yyerror(string);
void semanticError(string MSG);
string novaVarTemp(TIPO tipo);
Simbolo* novaVar(TIPO tipo, string labelUsuario);
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
void inicializarTabelaFormatting();
void tabelaFormattingAdd(TIPO tipo, string cFormato);
bool tipoDiretoCodIntermediario(TIPO tipo);
StringInfo* novaString();

// Variáveis
int var_temp_qnt; // Contador de variáveis temporárias
int var_qnt; // Contador de variáveis globais não temporárias criadas

int linha = 1; // Contador da linha do comando; Atualizado no lexer
int coluna = 0; // Contador de caracteres do comando; Atualizado no lexer

string codigo_gerado; // Código intermediário gerado pelo compilador
vector<unordered_map<string, Simbolo*>> tabelaSimbolos; // Tabela de símbolos
queue<Simbolo*> ordemDeclaracaoSimbolos; // Uma lista com todos os símbolos, de todos os escopos, que foram declarados pelo usuário. TODO: Renomear essa variável para melhor condizer com sua função
 
queue<TIPO> tipoDosTemporarios; // O tipo de cada variável temporária; Está em ordem de declaração

// Tabela de conversão; Verifica se o tipo da esquerda pode se converter no tipo da direita
// OBS: Não tem a diagonal principal (onde o tipo A == B) por simplicidade;
// OBS²: Tipos que não estejam na tabela infere-se que não é possível realizar nenhuma conversão, i. e., tipo A não consegue se converter no tipo B
unordered_map<pair<TIPO, TIPO>, ConversaoInfo, pair_hash> tabelaConversao; 

// Dado um operador (um char, um token de operador, etc.), verifica se é possível operar sobre o TIPO passado
// OBS: Tipos que não estejam na tabela infere-se que não é possível realizar nenhuma operação, i. e., o operador passado não pode ser usado
// OBS²: Note que essa não é uma tabela de conversões; Ela apenas verifica, para um par de variáveis de um tipo, se o operador passado pode ser usado
unordered_map<pair<int, TIPO>, bool, pair_hash> tabelaOperadores;

// Dado um TIPO (int, float, bool, char) salva qual o formato em C para ler/escrever aquele tipo no código intermediário
// ex.: "%d" para int, "%f" para float, "%c" para char... 
// OBS: as booleanas serão um problema, pois devem ser lidas como uma string (true/false) e transformadas em seu valor inteiro 1 ou 0
unordered_map<TIPO, string> tabelaFormatting;

// Usado para guardar se uma string é dinâmica ou não e se seu tamanho é conhecido em tempo de compilação
unordered_map<string, StringInfo*> tabelaStrings;

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

%token TK_INPUT TK_OUTPUT

/* TOKEN PARA OS TIPOS DIFERENTES */
/* OBS: Cada novo tipo adicionado, deve-se criar um token desses e alterar o yylval.tipo para o token correspondente no lexer  */
/* 		É também necessário, para cada tipo novo, alterar: tipoCodIntermediario, tipoDiretoCodInterrmediario, tipoParaString, inicializarTabelaConversao, inicializarTabelaDeOperadores e inicializarTabelaFormatting 	*/
%token TIPO_INT
%token TIPO_FLOAT
%token TIPO_CHAR
%token TIPO_BOOL
%token TIPO_STRING


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
	COMANDOS
	{
		// TODO: Depois separar em funções

		codigo_gerado = "#include <stdio.h>\n#include <string.h>\n#include <stdlib.h>\n"
						"\nint main(void)\n{\n";						


		codigo_gerado += "\t// Variaveis Temporarias\n";
		int i = 0;
		while (!tipoDosTemporarios.empty())
		{			 
			TIPO tipoVar = tipoDosTemporarios.front();			
			
			if (tipoDiretoCodIntermediario(tipoVar))
			{
				codigo_gerado += "\t" + tipoCodIntermediario(tipoVar) + " " + tmpVarPrefix + to_string(i) + ";" + " // " + tipoParaString(tipoVar) + "\n";			
			}
			else if (tipoVar == TIPO_STRING)
			{				
				StringInfo* sinfo = tabelaStrings[tmpVarPrefix + to_string(i)];

				if (sinfo->éDinâmica)
				{
					// Usar char*
					codigo_gerado += string("\tchar* ") + tmpVarPrefix + to_string(i) + ";" + " // " + tipoParaString(tipoVar) + "\n";			
					codigo_gerado += string("\tint ") + tmpVarPrefix + to_string(i) + str_length_suffix + ";\n";
				}
				else
				{
					// Usar char[]
					codigo_gerado += string("\tchar ") + tmpVarPrefix + to_string(i) + "[" + to_string(sinfo->tamanho) + "]" + ";" + " // " + tipoParaString(tipoVar) + "\n";	
				}
			}			
			else
			{
				semanticError("Uma variável do tipo " + tipoParaString(tipoVar) + " não pode ser declarada");
				YYABORT;
			}

			tipoDosTemporarios.pop();
			i++;
		}						
		
		codigo_gerado += "\n\t// Variaveis De Usuario\n";				
		while (!ordemDeclaracaoSimbolos.empty())
		{			 
			Simbolo* s = ordemDeclaracaoSimbolos.front();
			TIPO tipoVar = s->tipoDeclarado;
			
			if (tipoDiretoCodIntermediario(tipoVar))
			{
				codigo_gerado += "\t" + tipoCodIntermediario(s->tipoDeclarado) + " " + s->labelReal + ";" + " // " + s->labelUsuario + "\n";
			}			
			else if (tipoVar == TIPO_STRING)
			{
				StringInfo* sinfo = tabelaStrings[s->labelReal];

				if (sinfo->éDinâmica)
				{
					// Usar char*
					codigo_gerado += string("\tchar* ") + s->labelReal + ";" + " // " + s->labelUsuario + "\n";		
					codigo_gerado += "\tint " + s->labelReal + str_length_suffix + ";\n";
				}
				else
				{
					// Usar char[]
					codigo_gerado += string("\tchar ") + s->labelReal + "[" + to_string(sinfo->tamanho) + "]" + ";" + " // " + s->labelUsuario + "\n";	
				}
			}
			else
			{
				semanticError("Uma variável do tipo " + tipoParaString(tipoVar) + " não pode ser declarada");
				YYABORT;
			}

			ordemDeclaracaoSimbolos.pop();
		}
		codigo_gerado += "\n";		
		

		codigo_gerado += "\t// Codigo do Usuario\n";
		codigo_gerado += $1.traducao;

		codigo_gerado += "\n\treturn 0;" "\n}\n";
	}
;

COMANDOS:
	COMANDO
	{
		$$.traducao = $1.traducao;
	}
	|
	COMANDOS COMANDO
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
    | TK_OUTPUT EXPRESSAO ';'
	{
		TIPO tipoExp = $2.tipo;

		if (tabelaFormatting.find(tipoExp) == tabelaFormatting.end())
		{
			semanticError("Não é possível imprimir o tipo " + tipoParaString(tipoExp) + " na entrada.");
			YYABORT;
		}

		$$.traducao = $2.traducao + "\tprintf(\"" + tabelaFormatting[tipoExp] + "\\n\", " + $2.label + ");\n";    
  	}
;

BLOCO:
	'{' { empilharEscopo(); } COMANDOS '}'
	{
		desempilharEscopo();
		$$.traducao = "\n\t// Inicio do bloco\n" + $3.traducao + "\t// Fim do bloco\n\n";
	}
;

EXPRESSAO: 	
	TK_NUM
	{
		$$.label = novaVarTemp($1.tipo);
		$$.tipo = $1.tipo;
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";

		if ($1.tipo == TIPO_STRING)
		{
			// É uma string estática até então pq estamos recebendo do código fonte uma string pronta
			StringInfo* sinfo = novaString();
			sinfo->éDinâmica = false;
			sinfo->tamanho = $1.label.length() - 2 + 1; // -2 aqui pq a string recebida tem dois ", +1 por causa do \0			
			tabelaStrings[$$.label] = sinfo;

			$$.traducao = "\tstrcpy(" + $$.label + ", " + $1.label + ");\n";
		}
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

		if (tipoId == TIPO_STRING)
		{
			// Cria uma variável temporária para carregar a string guardada no ID passado pelo usuário 
			// TODO: FALTA A PARTE DO MALLOC (OU FREE SE NECESSARIO) PARA ALOCAR A STRING CASO ELA FOR DINAMICA
			StringInfo* sinfo = novaString();
			string idNomeReal = varNomeReal($1.label);
			StringInfo* sinfoId = tabelaStrings[idNomeReal];

			sinfo->éDinâmica = sinfoId->éDinâmica;

			if (!sinfoId->éDinâmica)
			{
				sinfo->tamanho = sinfoId->tamanho;	
			}		

			tabelaStrings[$$.label] = sinfo;
			$$.traducao = "\tstrcpy(" + $$.label + ", " + idNomeReal + ");\n";
		}

	}
	| TK_INPUT '(' TK_TIPO ')'
	{
		// Retorna uma variável do tipo TK_TIPO lida;
		// Consegue criar o nó de atributos da árvore sintática corretamente
		$$.label = novaVarTemp($3.tipo);
		$$.tipo = $3.tipo;

		if (tabelaFormatting.find($3.tipo) == tabelaFormatting.end())
		{
			semanticError("Não é possível ler o tipo " + tipoParaString($3.tipo) + " na entrada.");
			YYABORT;
		}

		$$.traducao = "\tscanf(\"" + tabelaFormatting[$3.tipo] + "\", &" + $$.label + ");\n";
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

		if ($1.tipo == TIPO_STRING)
		{						
			StringInfo* sinfoVar = tabelaStrings[varNomeReal($1.label)];						
			StringInfo* sinfoExp = tabelaStrings[labelExp];			

			if (sinfoExp->éDinâmica)
			{
				if (sinfoVar->éDinâmica)
				{
					string free = "";
					if (s->simboloInicializado)
					{
						free = "\tfree(" + s->labelReal + ");\n";
					}

					string tmpTamanhoExp = novaVarTemp(TIPO_INT); // O tamanho da string que estamos colocando em TK_ID; Tem que calcular em tempo de exec.										

					// Calcular tamanho da string dinâmica exp usando um loop e colocar em tmpTamanhoExp
					// calcular o tamanho que deve ser alocado, usando o tamanho * sizeof(char)
					// alocar essa quantia
					// atualizar a tradução final com a tradConversao + free + malloc e strcpy final
				}
				else
				{
					// Calcular tamanho da string dinâmica exp usando um loop e colocar em tmpTamanhoExp
					// calcular o tamanho que deve ser alocado, usando o tamanho * sizeof(char)
					// transformar a string estática TK_ID em uma dinâmica na tabela de strings
					// registrar que ocorreu essa transição e guardar o maior tamamnho estático dela
					// dar free 
					// alocar nova string
					// strcopy final
					// atualizar traducao final
				}
			}
			else
			{
				if (sinfoVar->éDinâmica)
				{
					string free = "";
					if (s->simboloInicializado)
					{
						free = "\tfree(" + s->labelReal + ");\n";
					}

					int tamanho = sinfoExp->tamanho; 

					string tmpA = novaVarTemp(TIPO_INT); // O tamanho da string que estamos colocando em TK_ID					
					string tmpB = novaVarTemp(TIPO_INT); // sizeof(char)
					string tmpC = novaVarTemp(TIPO_INT); // tamanho * sizeof(char)
					string malloc = "\t" + tmpA + " = " + to_string(tamanho) + ";\n\t" + tmpB + " = sizeof(char);\n\t" + tmpC + " = " + tmpA + " * " + tmpB + ";\n\t" + s->labelReal + " = (char*) malloc(" + tmpC + ");\n";
					$$.traducao = $3.traducao + tradConversao + free + malloc + "\tstrcpy(" + s->labelReal + ", " + labelExp +")" + ";" + " // " + $1.label + "\n\t" + s->labelReal + str_length_suffix + " = " + to_string(tamanho) + ";\n";	
				}
				else
				{
					int tamanho = sinfoVar->tamanho + sinfoExp->tamanho - 1; // Desconsiderando um dos \0
					sinfoVar->tamanho = tamanho; // Aumenta o tamanho da string estática					
					$$.traducao = $3.traducao + tradConversao + "\tstrcpy(" + s->labelReal + ", " + labelExp +")" + ";" + " // " + $1.label + "\n";					
				}
			}
		}

		s->simboloInicializado = true;		
	}
	| TK_ID '=' TK_INPUT
	{
		// Ler o input do tipo do TK_ID
		// Aqui não tem como TK_INPUT virar expressão pois é necessário inferir o tipo de TK_INPUT
		TIPO tipoExp = varTipo($1.label);
		string labelExp = novaVarTemp(tipoExp);
		
		if (tabelaFormatting.find(tipoExp) == tabelaFormatting.end())
		{
			semanticError("Não é possível ler o tipo " + tipoParaString(tipoExp) + " na entrada.");
			YYABORT;
		}

		$$.label = $1.label;
		$$.traducao = "\tscanf(\"" + tabelaFormatting[tipoExp] + "\", &" + labelExp + ");\n" + "\t" + varNomeReal($1.label) + " = " + labelExp + ";" + " // " + $1.label + "\n";
		
		Simbolo* s = obterSimbolo($1.label);
		s->simboloInicializado = true; 
	}	
	| DECLARACAO '=' EXPRESSAO
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
	| DECLARACAO '=' TK_INPUT
	{	
		// Ler o input do tipo da Declaração
		// Aqui não tem como TK_INPUT virar expressão pois é necessário inferir o tipo de TK_INPUT

		TIPO tipoExp = varTipo($1.label);
		string labelExp = novaVarTemp(tipoExp);

		if (tabelaFormatting.find(tipoExp) == tabelaFormatting.end())
		{
			semanticError("Não é possível ler o tipo " + tipoParaString(tipoExp) + " na entrada.");
			YYABORT;
		}

		$$.label = $1.label;
		$$.traducao = "\tscanf(\"" + tabelaFormatting[tipoExp] + "\", &" + labelExp + ");\n" + "\t" + varNomeReal($1.label) + " = " + labelExp + ";" + " // " + $1.label + "\n";

		Simbolo* s = obterSimbolo($1.label);
		s->simboloInicializado = true; 

	}		
	| TK_VAR TK_ID '=' EXPRESSAO
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

			Simbolo* s = novaVar($4.tipo, $2.label); // O tipo declarado é o tipo da expressão, por inferência
			s->simboloInicializado = true;			

			tabelaSimbolos.back()[$2.label] = s;						
			ordemDeclaracaoSimbolos.push(s);
			
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

			Simbolo* s = novaVar($1.tipo, $2.label);

			tabelaSimbolos.back()[$2.label] = s;
			ordemDeclaracaoSimbolos.push(s);
			
			if ($1.tipo == TIPO_STRING)
			{
				StringInfo* sinfo = novaString();
				sinfo->éDinâmica = true;				
				tabelaStrings[s->labelReal] = sinfo;				
			}
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
Simbolo* novaVar(TIPO tipo, string labelUsuario)
{
	var_qnt++;
	Simbolo* s = new Simbolo;

	s->labelReal = varPrefix + to_string(var_qnt);
	s->labelUsuario = labelUsuario;
	s->tipoDeclarado = tipo;
	s->simboloInicializado = false;

	return s;
}

// Apenas um helper para criar uma StringInfo
StringInfo* novaString()
{
	StringInfo* s = new StringInfo;
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

// Procura o símbolo de labelUsuario no escopo mais próximo; Não verifica se o símbolo realmente existe;
// Se o Símbolo não existir, é retornado NULL
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

// Retorna, dado um tipo, se consegue ser transformado facilmente em código intermediário, apenas trocando o tipo
bool tipoDiretoCodIntermediario(TIPO tipo)
{
	switch (tipo)
	{
		case TIPO_INT:
			return true;
			break;
		case TIPO_BOOL:
			return true;
			break;
		case TIPO_FLOAT:
			return true;
			break;
		case TIPO_CHAR:
			return true;
			break;
	}
	return false;
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
		case TIPO_STRING:
			return "string";
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

void inicializarTabelaFormatting()
{
	tabelaFormattingAdd(TIPO_INT, "%d");
	tabelaFormattingAdd(TIPO_FLOAT, "%f");
	tabelaFormattingAdd(TIPO_CHAR, "%c");
}

void tabelaFormattingAdd(TIPO tipo, string cFormato)
{
	tabelaFormatting[tipo] = cFormato;
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
  	inicializarTabelaFormatting();
 	empilharEscopo();		
}

int main(int argc, char* argv[])
{
	// Para aceitar todos os tipos de caractere
	std::setlocale(LC_ALL, "");

	bool useOut = false;		
	bool inEncontrado = false;
	string outFile;
	yyin = stdin;	

	// programa de entrada
	if (argc > 1)
	{	
		// Lê todos os argumentos de entrada	
		for (int i = 1; i < argc; i++)
		{			
			char* argAtual = argv[i];
			std::string argAtualStr(argv[i]);

			// Encontrou a Entrada
			if (argv[i][0] != '-' && !inEncontrado)
			{
				// TODO: Depois verificar se o arquivo tem o posfixo da linguagem fonte				
				yyin = fopen(argv[i], "r");
				inEncontrado = true;

				if (!yyin)
				{
					printf("%s", ("O arquivo " + argAtualStr + " não existe ou não é um arquivo de código fonte válido\n").c_str());
					return 1;
				}

				continue;
			}

			// Encontrou uma flag
			if (argv[i][0] == '-')
			{				
				// Comando de saída (output)				
				if (strcmp(argAtual, "-o") == 0 || strcmp(argAtual, "-out") == 0 || strcmp(argAtual, "-output") == 0)
				{
					// Verifica se há um arquivo acompanhando o -o
					// Verifica se não é o último argumento (se existe 1 depois dele) e se esse próximo argumento não é uma flag
					if (i + 1 <= argc - 1 && argv[i + 1][0] != '-')
					{						
						outFile = argv[i + 1];
						useOut = true;

						i++;
						continue;
					}
					else
					{
						printf("O argumento -output precisa de um caminho de arquivo\n");
						return 1;
					}
				}

			}
		}		
	}

	initialize();

	if (yyparse() == 0)
	{
		if (useOut)
		{			
			std::ofstream output(outFile);
			output << codigo_gerado;
			output.close();
		}
		else
		{
			cout << codigo_gerado;
		}
	}		

	return 0;
}
