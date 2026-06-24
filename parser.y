%{

#include <iostream>
#include <unordered_map>
#include <queue>
#include <string>
#include <locale>
#include <cstdlib>
#include <utility>
#include <vector>
#include <deque>
#include <fstream>
#include <cstring>
#include <stdlib.h>

using namespace std;

extern FILE* yyin; // yyin é o arquivo de entrada do flex; ao alterar, é possível redirecionar o fluxo da entrada do código fonte
#define YYSTYPE atributos // YYSTYPE é o tipo de valor usado para cada token da árvore sintática; É diferente do valor numérico gerador por %token
#define TIPO int // É um macro para diferenciar o tipo da variável; É possível usar os tokens de tipo (%token TIPO_...) pq os dois são int no fim
#define str_length_suffix "_strlen" // Usado ao declarar string dinâmicas; Um inteiro de mesmo nome da variável usada para guardar a string terá esse sufixo
#define str_inputBuffer_len 256 // O tamanho do buffer usado para ler uma string inserida pelo usuário
#define str_inputBuffer_label "strInputBuffer" // O label do buffer

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

enum class TipoComando
{
	IF_ELSE,
	FOR,
	WHILE,
	SWITCH,
	DO
};

struct Label
{
	string labelInicio; // Label para o início do bloco de código (usado para controle de fluxo)
	string labelFim; // Label para o fim do bloco de código (usado para controle de fluxo)
	TipoComando tipoComando; // O tipo do comando de controle de fluxo (if, for, etc.) relacionado a essa label; Usado para diferenciar os tipos de comandos de controle de fluxo
};

struct Caso
{
	string labelCaso; // Label do caso
	string valorCaso; // O valor do caso, em formato de string (1, 'a', etc.); Usado para gerar o código intermediário do switch
	TIPO tipoValor; // Tipo do valor do caso (int, char, etc.)
	int numCaso; // O valor do caso (1, 2, 'a', etc.)
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
	bool transicionou; // Se era antes uma string fixa e se transformou em uma string dinâmica;
	int tamanho;
};

struct fun_param
{
	string labelUsuario;
	string labelReal;
	TIPO tipo;
};

struct fun_assinatura
{
	string labelUsuario;
	string labelReal;
	TIPO tipoRetorno;
	vector<fun_param> params;

	string traducao;
	string labelRetorno;
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
string ConversaoCodIntermediario(string labelA, TIPO tipoA, TIPO tipoB, string& labelB);
bool operadorFuncionaEmTipo(int operadorOuToken, TIPO tipo);
void inicializarTabelaDeOperadores();
void tabelaDeOperadoresAdd(int operador, TIPO tipo);
void empilharEscopo();
void desempilharEscopo();
Simbolo* obterSimbolo(string labelUsuario);
Label* novaLabel(TipoComando tipoComando);
//void empilharLabel(string labelInicio, string labelFim);
Label* desempilharLabel();
Caso* novaCaso(string labelCaso, TIPO tipoValor, string valorCaso);
Caso* desempilharCaso();
void inicializarTabelaFormatting();
void tabelaFormattingAdd(TIPO tipo, string cFormato);
bool tipoDiretoCodIntermediario(TIPO tipo);
StringInfo* novaString();
string StringDinamicaInput(string& tamanho, string& labelString);
string StringMalloc(string labelString, string labelComQntCharOuConstante);
string StringDinamicaTamanho(string labelString);
string StringAtribuição(string lString, string rString);
string DeclararVariaveisTemporarias(bool* b, TIPO* tipoErrado);
string DeclararVariaveisUsuario(bool* b, TIPO* tipoErrado);
void DeclararVariaveisLocais(const vector<fun_param>& params);

// Variáveis
int var_temp_qnt; // Contador de variáveis temporárias
int var_qnt; // Contador de variáveis globais não temporárias criadas
int func_qnt; // Contador de funções criadas

int label_qnt; // Contador de labels criadas
int label_qnt_casos; // Contador de labels de casos criados; Usado para diferenciar os labels de casos dos labels de controle de fluxo

int linha = 1; // Contador da linha do comando; Atualizado no lexer
int coluna = 0; // Contador de caracteres do comando; Atualizado no lexer

bool usandoInputBuffer = false; // Se em algum momento do código se lê uma input

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

deque<Label*> tabelaLabels; // Pilha de labels para controle de fluxo (while, for, etc.);
 
queue<Caso*> tabelaCasos; // Lista de casos para o switch;
// Dado um TIPO (int, float, bool, char) salva qual o formato em C para ler/escrever aquele tipo no código intermediário
// ex.: "%d" para int, "%f" para float, "%c" para char... 
// OBS: as booleanas serão um problema, pois devem ser lidas como uma string (true/false) e transformadas em seu valor inteiro 1 ou 0
unordered_map<TIPO, string> tabelaFormatting;

// Usado para guardar se uma string é dinâmica ou não e se seu tamanho é conhecido em tempo de compilação
unordered_map<string, StringInfo*> tabelaStrings;

// Usado para guardar a tabela de assinaturas de funções
unordered_map<string, fun_assinatura> tabelaFuncoes;
vector<fun_param> paramsAtuaisFunc; // Quais os parâmetros atuais que estão sendo lidos nessa função

string funcaoAtual = "";
TIPO tipoRetornoAtual;
bool emFuncao = false;
bool funcaoRetornouValor = false;
vector<vector<atributos>> argsStack;

// Macros
#define tmpVarPrefix "tmp"
#define varPrefix "var"
#define funcPrefix "func"
#define BOOL_TRUE 1 // Funciona pois no cod. intermediário o bool é um inteiro; Considerar 1 como true
#define BOOL_FALSE 0 // Funciona pois no cod. intermediário o bool é um inteiro; Considerar 0 como false

%}

/* TOKENS PARA OS DIFERENTES TIPOS GRAMATICAIS */
%token TK_NUM
%token TK_ID
%token TK_TIPO

%token TK_VAR

%token OP_NOT OP_AND OP_OR
%token OP_MAIS_IGUAL OP_MENOS_IGUAL OP_MULT_IGUAL OP_DIV_IGUAL

// TOKEN PARA OS DIFERENTES COMANDOS DE CONTROLE DE FLUXO; OBS: Para cada comando novo, deve-se criar um token correspondente e alterar o lexer para retornar esse token quando encontrar a palavra reservada do comando
%token TK_IF TK_ELSE TK_WHILE TK_FOR TK_SWITCH TK_CASE TK_DEFAULT TK_DO

%token TK_BREAK TK_CONTINUE TK_ESCAPE

/* OBS: Cada novo tipo adicionado, deve-se criar um token desses e alterar o yylval.tipo para o token correspondente no lexer  */
/* 		É também necessário, para cada tipo novo, alterar: tipoCodIntermediario, tipoParaString, inicializarTabelaConversao e inicializarTabelaDeOperadores 	*/
%token TK_INPUT TK_OUTPUT

/* TOKEN PARA OS TIPOS DIFERENTES */
/* OBS: Cada novo tipo adicionado, deve-se criar um token desses e alterar o yylval.tipo para o token correspondente no lexer  */
/* 		É também necessário, para cada tipo novo, alterar: tipoCodIntermediario, tipoDiretoCodInterrmediario, tipoParaString, inicializarTabelaConversao, inicializarTabelaDeOperadores e inicializarTabelaFormatting 	*/
%token TIPO_INT
%token TIPO_FLOAT
%token TIPO_CHAR
%token TIPO_BOOL
%token TIPO_VAZIO
%token TIPO_STRING


%token TK_RETURN

%start OUTPUT

%nonassoc TK_NO_ELSE // Usado para marcar o final de um comando if sem else, para resolver o "dangling else problem"; O TK_NO_ELSE é não associativo, ou seja, ele não pode ser associado a nenhum else; Assim, o else mais próximo de um if sempre será associado a ele, e não a um if mais distante
%nonassoc TK_ELSE // Para resolver o "dangling else problem"; O TK_ELSE é não associativo, ou seja, ele só pode ser associado ao if mais próximo; Assim, o else mais próximo de um if sempre será associado a ele, e não a um if mais distante

%right '=' OP_MAIS_IGUAL OP_MENOS_IGUAL OP_MULT_IGUAL OP_DIV_IGUAL

/*Operadores logicos*/
%left OP_OR
%left OP_AND

%left OP_DIFERENTE OP_IGUAL
%left OP_MENOR OP_MAIOR OP_MENOR_IGUAL OP_MAIOR_IGUAL

%left '+' '-'
%left '*' '/'

%left '(' ')'
%right OP_NOT OP_INC OP_DEC NUM_NEGATIVO




%%

OUTPUT: 
	COMANDOS
	{				
		bool abort = false;
		TIPO tipo;

		// OBS: A ordem aqui importa muito! 
		// Na declaração de usuário, novas variáveis temporárias são geradas!		
		string varUser = DeclararVariaveisUsuario(&abort, &tipo);
		if (abort)
		{
			semanticError("Uma variável do tipo " + tipoParaString(tipo) + " não pode ser declarada");
			YYABORT;
		}

		string varTemp = DeclararVariaveisTemporarias(&abort, &tipo);				
		if (abort)
		{
			semanticError("Uma variável do tipo " + tipoParaString(tipo) + " não pode ser declarada");
			YYABORT;
		}

		// Declaração das funções usadas
		string dec_funcoes_usuario;
		
		for (auto& par : tabelaFuncoes)
		{
			dec_funcoes_usuario += par.second.traducao + "\n";
		}

		// Código criado pelo usuario
		string codigoUser = "\t// Codigo do Usuario\n" + $1.traducao;

		// Código gerado final
		codigo_gerado = "#include <stdio.h>\n#include <string.h>\n#include <stdlib.h>\n\n";						
		codigo_gerado += varTemp;
		codigo_gerado += varUser;
		codigo_gerado += dec_funcoes_usuario;
		codigo_gerado += "int main(void)\n{\n" + codigoUser;

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

COMANDOS_OPCIONAIS:
	COMANDOS
	{
		$$.traducao = $1.traducao;
	}
	| /* vazio */
	{
		$$.traducao = "";
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
	| IF
	{
		$$.traducao = $1.traducao;
	}
	| FOR 
	{
		$$.traducao = $1.traducao;
	}
	| WHILE
	{
		$$.traducao = $1.traducao;
	}
	| DO_WHILE
	{
		$$.traducao = $1.traducao;
	}
	| SWITCH
	{
		$$.traducao = $1.traducao;
	}
	| BREAK
	{
		$$.traducao = $1.traducao;
	}
	| CONTINUE
	{
		$$.traducao = $1.traducao;
	}
	| ESCAPE
	{
		$$.traducao = $1.traducao;
	}
	| DECLARACAO_FUNCAO
	{
		if (tabelaSimbolos.size() > 1)
		{
			semanticError("As declarações de função só podem acontecer no escopo global");
			YYABORT;
		}
	}
	| TK_RETURN ';'
    {
        if (!emFuncao)
        {
            semanticError("Uso de return fora de função");
            YYABORT;
        }

        if (tipoRetornoAtual != TIPO_VAZIO)
        {
            semanticError("Tipo de retorno inválido -> função '" + funcaoAtual + "' deve retornar um valor");
            YYABORT;
        }

        $$.traducao = "\treturn;\n";
    }
    | TK_RETURN EXPRESSAO ';'
    {
        if (!emFuncao)
        {
            semanticError("Uso de return fora de função");
            YYABORT;
        }

        if (!tipoPodeSerAtribuido(tipoRetornoAtual, $2.tipo))
        {
            semanticError("Tipo de retorno inválido para a função '" + funcaoAtual + "' -> esperado " + tipoParaString(tipoRetornoAtual) + ", encontrado " + tipoParaString($2.tipo));
            YYABORT;
        }

        funcaoRetornouValor = true;
        $$.traducao = $2.traducao + "\treturn " + $2.label + ";\n";
    }
;

COMANDO_OPCIONAL:
	COMANDO
	{
		$$.traducao = $1.traducao;
	}
	| ';'/* vazio */
	{
		$$.traducao = "";
	}
;

BLOCO:
	'{' { empilharEscopo(); } COMANDOS_OPCIONAIS '}'
	{
		desempilharEscopo();
		$$.traducao = "\n\t// Inicio do bloco\n" + $3.traducao + "\t// Fim do bloco\n\n";
	}
;

IF:
	IF_PREFIXO COMANDO_OPCIONAL %prec TK_NO_ELSE
	{

		desempilharEscopo();

		Label* L = desempilharLabel();

		string labelExp = novaVarTemp(TIPO_BOOL);

		$$.traducao = $1.traducao + "\t" + labelExp + " = !" + $1.label + ";\n" + "\tif (" + labelExp + ")\n\t\tgoto " + L->labelFim + ";\n" + $2.traducao + L->labelFim + ":\n";

	}
	| IF_PREFIXO COMANDO_OPCIONAL ELSE
	{

		desempilharEscopo();

		desempilharLabel();

		string labelExp = novaVarTemp(TIPO_BOOL);

		$$.traducao = $1.traducao + "\t" + labelExp + " = !" + $1.label + ";\n" + "\tif (" + labelExp + ")\n\t\tgoto " + $3.label + ";\n" + $2.traducao + $3.traducao;

	}
;

IF_PREFIXO:
	TK_IF '(' EXPRESSAO ')' { empilharEscopo(); novaLabel(TipoComando::IF_ELSE);} 
	{
		if ($3.tipo != TIPO_BOOL)
		{
			semanticError("Erro de tipo -> A expressão do if deve ser do tipo booleano; Tipo '" + tipoParaString($3.tipo) + "' encontrado.");
			YYABORT;
		}

		$$.label = $3.label;
		$$.traducao = $3.traducao;

	}
;

ELSE:
	TK_ELSE { empilharEscopo(); novaLabel(TipoComando::IF_ELSE); } COMANDO_OPCIONAL 
	{
		desempilharEscopo();

		Label* L = desempilharLabel();
		
		$$.traducao = "\tgoto " + L->labelFim + ";\n" + L->labelInicio + ":\n" + $3.traducao + L->labelFim + ":\n";
		$$.label = L->labelInicio;
	}
;

FOR: 
	TK_FOR { empilharEscopo(); novaLabel(TipoComando::FOR); } '(' FOR_PARAM_1 ';' FOR_PARAM_2 ';' FOR_PARAM_3 ')' COMANDO_OPCIONAL
	{
		if( $6.tipo == TIPO_VAZIO)
		{
			$6.tipo = TIPO_BOOL; // Se a expressão do meio do for for vazia, considerar como verdadeira (equivalente a "for(;;)")
			$6.label = novaVarTemp(TIPO_BOOL);
			$6.traducao = "\t" + $6.label + " = " + to_string(BOOL_TRUE) + ";\n";
		}
		if ($6.tipo != TIPO_BOOL)
		{
			semanticError("Erro de tipo -> A expressão do for deve ser do tipo booleano; Tipo '" + tipoParaString($6.tipo) + "' encontrado.");
			YYABORT;
		}

		desempilharEscopo();

		Label* L = desempilharLabel();

		string labelExp = novaVarTemp(TIPO_BOOL);

		$$.traducao = $4.traducao + L->labelInicio + "_FOR:\n" + $6.traducao + "\t" + labelExp + " = !" + $6.label + ";\n" + "\tif (" + labelExp + ")\n\t\tgoto " + L->labelFim + ";\n" + $10.traducao + L->labelInicio + ":\n" + $8.traducao + "\tgoto " + L->labelInicio + "_FOR;\n" + L->labelFim + ":\n";

	}
;

FOR_PARAM_1:
	ATRIBUICAO
	{
		$$.label = $1.label;
		$$.traducao = $1.traducao;
	}
	| EXPRESSAO
	{
		$$.label = $1.label;
		$$.tipo = $1.tipo;
		$$.traducao = $1.traducao;
	}
	| /* vazio */
	{
		$$.label = "";
		$$.traducao = "";
	}
;

FOR_PARAM_2:
	EXPRESSAO
	{
		$$.label = $1.label;
		$$.tipo = $1.tipo;
		$$.traducao = $1.traducao;
	}
	| /* vazio */
	{
		$$.label = "";
		$$.tipo = TIPO_VAZIO; // Tipo especial para indicar ausência de expressão
		$$.traducao = "";
	}
;

FOR_PARAM_3:
	ATRIBUICAO_NAO_DECLARACATIVA
	{
		$$.label = $1.label;
		$$.traducao = $1.traducao;
	}
	| EXPRESSAO
	{
		$$.label = $1.label;
		$$.tipo = $1.tipo;
		$$.traducao = $1.traducao;
	}
	| /* vazio */
	{
		$$.label = "";
		$$.traducao = "";
	}
;

WHILE:
	TK_WHILE '(' EXPRESSAO ')' { empilharEscopo(); novaLabel(TipoComando::WHILE); } COMANDO_OPCIONAL
	{
		if ($3.tipo != TIPO_BOOL)
		{
			semanticError("Erro de tipo -> A expressão do while deve ser do tipo booleano; Tipo '" + tipoParaString($3.tipo) + "' encontrado.");
			YYABORT;
		}

		desempilharEscopo();

		Label* L = desempilharLabel();

		string labelExp = novaVarTemp(TIPO_BOOL);

		$$.traducao = L->labelInicio + ":\n" + $3.traducao + "\t" + labelExp + " = !" + $3.label + ";\n" + "\tif (" + labelExp + ")\n\t\tgoto " + L->labelFim + ";\n" + $6.traducao + "\tgoto " + L->labelInicio + ";\n" + L->labelFim + ":\n";
		
	}
;

DO_WHILE:
	TK_DO { empilharEscopo(); novaLabel(TipoComando::DO); } COMANDO_OPCIONAL TK_WHILE '(' EXPRESSAO ')' ';'
	{
		if ($6.tipo != TIPO_BOOL)
		{
			semanticError("Erro de tipo -> A expressão do do-while deve ser do tipo booleano; Tipo '" + tipoParaString($6.tipo) + "' encontrado.");
			YYABORT;
		}

		desempilharEscopo();

		Label* L = desempilharLabel();

		$$.traducao = L->labelInicio + "_DO:\n" + $3.traducao + L->labelInicio +":\n" + $6.traducao + "\tif (" + $6.label + ")\n\t\tgoto " + L->labelInicio + "_DO;\n" + L->labelFim + ":\n";
		
	}
;

SWITCH:
	SWITCH_PREFIXO '{' CASE_OPCIONAL DEFAULT '}'
	{
		desempilharEscopo();

		Label* L = desempilharLabel();

		string traducaoIF = "";

		while(!tabelaCasos.empty())
		{
			Caso* caso = desempilharCaso();

			if(caso->tipoValor == TIPO_VAZIO) //Default
			{
				traducaoIF += "\tgoto " + caso->labelCaso + ";\n";
				continue;
			}

			int operador = OP_IGUAL;
			string labelExp = novaVarTemp(TIPO_BOOL);
			string labelSwitchValor;
			string labelCasoValor = novaVarTemp(caso->tipoValor);

			if(caso->tipoValor == $1.tipo && operadorFuncionaEmTipo(operador, $1.tipo))
			{
				labelSwitchValor = $1.label;
				traducaoIF += "\t" + labelCasoValor + " = " + caso->valorCaso + ";\n";
			}
			else if(podeSerConvertidoImplicitamente(caso->tipoValor, $1.tipo) && operadorFuncionaEmTipo(operador, $1.tipo))
			{
				string labelConvertido = labelCasoValor;
				labelSwitchValor = $1.label;
				traducaoIF += "\t" + labelCasoValor + " = " + caso->valorCaso + ";\n";
				traducaoIF += "\t" + ConversaoCodIntermediario(labelConvertido, caso->tipoValor, $1.tipo, labelCasoValor);
			}
			else if(podeSerConvertidoImplicitamente($1.tipo, caso->tipoValor) && operadorFuncionaEmTipo(operador, caso->tipoValor))
			{
				traducaoIF += "\t" + ConversaoCodIntermediario($1.label, $1.tipo, caso->tipoValor, labelSwitchValor);
				traducaoIF += "\t" + labelCasoValor + " = " + caso->valorCaso + ";\n";
			}
			else
			{ 
				semanticError("Comparação invalida -> Tipo diferente entre a expressão do switch e o valor do caso. Tipo da expressão: '" + tipoParaString($1.tipo) + "'; Tipo do caso: '" + tipoParaString(caso->tipoValor) + "'.");
				YYABORT;
			}

		traducaoIF += "\t" + labelExp + " = " + labelSwitchValor + " == " + labelCasoValor + ";\n" + "\tif (" + labelExp + ")\n\t\tgoto " + caso->labelCaso + ";\n";
		}

		$$.traducao = $1.traducao + traducaoIF + $3.traducao + $4.traducao + L->labelFim + ":\n";
	}
;

SWITCH_PREFIXO:
	TK_SWITCH '(' EXPRESSAO ')' { empilharEscopo(); novaLabel(TipoComando::SWITCH); } 
	{

		$$.label = $3.label;
		$$.tipo = $3.tipo;
		$$.traducao = $3.traducao;
		label_qnt_casos = 0; // Reiniciar contador de labels de casos a cada switch

	}
;

CASE:
	TK_CASE TK_NUM ':' COMANDOS_OPCIONAIS
	{
		string labelCase = tabelaLabels.back()->labelInicio + to_string(label_qnt_casos); // Gerar um label único para o caso, baseado no contador de casos

		Caso* caso = novaCaso(labelCase, $2.tipo, $2.label);
		$$.traducao = caso->labelCaso + ":\n" + $4.traducao;

		label_qnt_casos++; // Incrementar o contador de casos para garantir unicidade dos labels dos casos
	}
	| CASE TK_CASE TK_NUM ':' COMANDOS_OPCIONAIS
	{
		string labelCase = tabelaLabels.back()->labelInicio + to_string(label_qnt_casos); // Gerar um label único para o caso, baseado no contador de casos

		Caso* caso = novaCaso(labelCase, $3.tipo, $3.label);
		$$.traducao = $1.traducao + caso->labelCaso + ":\n" + $5.traducao;

		label_qnt_casos++; // Incrementar o contador de casos para garantir unicidade dos labels dos casos
	}
;

CASE_OPCIONAL:
	CASE
	{
		$$.traducao = $1.traducao;
	}
	| /* vazio */
	{
		$$.traducao = "";
	}
;

DEFAULT:
	TK_DEFAULT ':' COMANDOS_OPCIONAIS
	{
		string labelCase = tabelaLabels.back()->labelInicio + to_string(label_qnt_casos); // Gerar um label único para o caso, baseado no contador de casos

		Caso* caso = novaCaso(labelCase, TIPO_VAZIO, ""); // O caso default não tem um valor específico, então usar um tipo especial para indicar isso

		$$.traducao = caso->labelCaso + ":\n" + $3.traducao;

		label_qnt_casos++; // Incrementar o contador de casos para garantir unicidade dos labels dos casos
	}
	| /* vazio */
	{
		$$.traducao = "";
		$$.label = "";
	}
;

BREAK:
	TK_BREAK ';'
	{
		Label* L = tabelaLabels.back();

		int i;

		for(i = tabelaLabels.size() - 1; i >= 0; i--)
		{

			if (tabelaLabels[i]->tipoComando != TipoComando::IF_ELSE)
			{
				L = tabelaLabels[i];
				break;
			}
		}

		if (tabelaLabels.empty() || (i < 0))
		{
			semanticError("Uso de break fora de um comando de controle de fluxo -> O comando 'break' só pode ser usado dentro de comandos de controle de fluxo como do_while, for, while, switch, etc.");
			YYABORT;
		}

		$$.traducao = "\tgoto " + L->labelFim + ";\n";
	}
;

CONTINUE:
	TK_CONTINUE ';'
	{
				Label* L = tabelaLabels.back();

		int i;

		for(i = tabelaLabels.size() - 1; i >= 0; i--)
		{

			if ((tabelaLabels[i]->tipoComando != TipoComando::IF_ELSE) && (tabelaLabels[i]->tipoComando != TipoComando::SWITCH))
			{
				L = tabelaLabels[i];
				break;
			}
		}

		if (tabelaLabels.empty() || (i < 0))
		{
			semanticError("Uso de continue fora de um comando de controle de fluxo -> O comando 'continue' só pode ser usado dentro de comandos de controle de fluxo como do_while, for, while, etc.");
			YYABORT;
		}

		$$.traducao = "\tgoto " + L->labelInicio + ";\n";
	}
;

ESCAPE:
	TK_ESCAPE ';'
	{
		Label* L = tabelaLabels.front();

		if (tabelaLabels.empty())
		{
			semanticError("Uso de escape fora de comando");
			YYABORT;
		}

		$$.traducao = "\tgoto " + L->labelFim + ";\n";
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
			StringInfo* sinfo = novaString();
			string idNomeReal = varNomeReal($1.label);
			StringInfo* sinfoId = tabelaStrings[idNomeReal];

			string malloc = "";

			sinfo->éDinâmica = sinfoId->éDinâmica;

			if (!sinfoId->éDinâmica)
			{
				sinfo->tamanho = sinfoId->tamanho;	
			}		
			else
			{			
				string tamStringId = StringDinamicaTamanho(idNomeReal);
				string tmp = StringMalloc($$.label, tamStringId); // aloca a string dinâmica para essa expressão
				malloc = tmp + "\t" + StringDinamicaTamanho($$.label) + " = " + tamStringId + ";\n"; // também altera a variável para guardar o tamanho dessa string dinâmica			
			}

			tabelaStrings[$$.label] = sinfo;
			$$.traducao = malloc + "\tstrcpy(" + $$.label + ", " + idNomeReal + ");\n";
		}

	}
	| TK_ID '(' { argsStack.emplace_back(); } ARGS ')'
    {
        auto it = tabelaFuncoes.find($1.label);
        if (it == tabelaFuncoes.end())
        {
            semanticError("Função não declarada -> '" + $1.label + "'");
            YYABORT;
        }

        fun_assinatura& fn = it->second;
        auto& args = argsStack.back();

        if (args.size() != fn.params.size())
        {
            semanticError("Número de argumentos inválido para a função '" + $1.label + "'");
            YYABORT;
        }

        string argsLabels = "";
        string callsTraducao = "";
        for (size_t i = 0; i < args.size(); ++i)
        {
            if (fn.params[i].tipo != args[i].tipo)
            {
                semanticError("Tipo de argumento inválido para a função '" + $1.label + "' no parâmetro " + to_string(i + 1));
                YYABORT;
            }

            callsTraducao += args[i].traducao;
            argsLabels += args[i].label;
            if (i + 1 < args.size())
                argsLabels += ", ";
        }

        if (fn.tipoRetorno == TIPO_VAZIO)
        {
            $$.label = "";
            $$.tipo = TIPO_VAZIO;
            $$.traducao = callsTraducao + "\t" + fn.labelReal + "(" + argsLabels + ");\n";
        }
        else
        {
            $$.label = novaVarTemp(fn.tipoRetorno);
            $$.tipo = fn.tipoRetorno;
            $$.traducao = callsTraducao + "\t" + $$.label + " = " + fn.labelReal + "(" + argsLabels + ");\n";
        }

        argsStack.pop_back();
    }
	| OP_INC TK_ID
	{
		// PRÉ-INCREMENTO: ++x 
		if (!operadorFuncionaEmTipo('+', $2.tipo)) { semanticError("O operador '+' não pode ser usado no tipo " + tipoParaString($2.tipo)); YYABORT; }
		if (!varExiste($2.label)) { semanticError("Símbolo não conhecido."); YYABORT; }
		if (!varInicializada($2.label)) { semanticError("Variável não inicializada."); YYABORT; }

		TIPO tipoId = varTipo($2.label);
		string nomeReal = varNomeReal($2.label);

		$$.label = novaVarTemp(tipoId);
		$$.tipo = tipoId;
		// LOGICA PRÉ: Soma primeiro, salva no temporário depois
		$$.traducao = "\t" + nomeReal + " = " + nomeReal + " + 1;\n" 
                    + "\t" + $$.label + " = " + nomeReal + ";\n";
	}
	| TK_ID OP_INC
	{
		// PÓS-INCREMENTO: x++ 
		if (!operadorFuncionaEmTipo('+', $1.tipo)) { semanticError("O operador '+' não pode ser usado no tipo " + tipoParaString($1.tipo)); YYABORT; }
		if (!varExiste($1.label)) { semanticError("Símbolo não conhecido."); YYABORT; }
		if (!varInicializada($1.label)) { semanticError("Variável não inicializada."); YYABORT; }

		TIPO tipoId = varTipo($1.label);
		string nomeReal = varNomeReal($1.label);

		$$.label = novaVarTemp(tipoId);
		$$.tipo = tipoId;
		// LOGICA PÓS: Salva no temporário primeiro, soma depois
		$$.traducao = "\t" + $$.label + " = " + nomeReal + ";\n" 
                    + "\t" + nomeReal + " = " + nomeReal + " + 1;\n";
	}
	| OP_DEC TK_ID 
	{
		// PRÉ-DECREMENTO: --x 
		if (!operadorFuncionaEmTipo('-', $2.tipo)) { semanticError("O operador '-' não pode ser usado no tipo " + tipoParaString($2.tipo)); YYABORT; }
		if (!varExiste($2.label)) { semanticError("Símbolo não conhecido."); YYABORT; }
		if (!varInicializada($2.label)) { semanticError("Variável não inicializada."); YYABORT; }

		TIPO tipoId = varTipo($2.label);
		string nomeReal = varNomeReal($2.label);

		$$.label = novaVarTemp(tipoId);
		$$.tipo = tipoId;
		// LOGICA PRÉ: Subtrai primeiro, salva no temporário depois
		$$.traducao = "\t" + nomeReal + " = " + nomeReal + " - 1;\n" 
                    + "\t" + $$.label + " = " + nomeReal + ";\n";
	}
	| TK_ID OP_DEC
	{
		// PÓS-DECREMENTO: x-- 
		if (!operadorFuncionaEmTipo('-', $1.tipo)) { semanticError("O operador '-' não pode ser usado no tipo " + tipoParaString($1.tipo)); YYABORT; }
		if (!varExiste($1.label)) { semanticError("Símbolo não conhecido."); YYABORT; }
		if (!varInicializada($1.label)) { semanticError("Variável não inicializada."); YYABORT; }

		TIPO tipoId = varTipo($1.label);
		string nomeReal = varNomeReal($1.label);

		$$.label = novaVarTemp(tipoId);
		$$.tipo = tipoId;
		// LOGICA PÓS: Salva no temporário primeiro, subtrai depois
		$$.traducao = "\t" + $$.label + " = " + nomeReal + ";\n" 
                    + "\t" + nomeReal + " = " + nomeReal + " - 1;\n";
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

		if ($3.tipo == TIPO_STRING)
		{
			// É uma nova string dinâmica
			StringInfo* sinfo = novaString();
			sinfo->éDinâmica = true;
			tabelaStrings[$$.label] = sinfo;
			
			string labelFinal;
			string labelTamanho;
			string trad = StringDinamicaInput(labelTamanho, labelFinal);
			$$.traducao = trad + StringMalloc($$.label, labelTamanho) + "\tstrcpy(" + $$.label + ", " + labelFinal + ");\n\t" + StringDinamicaTamanho($$.label) + " = " + labelTamanho + ";\n";			
		}
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
			tradConversao = ConversaoCodIntermediario($4.label, $4.tipo, novoTipo, novaLabel);
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
			tradConversão = ConversaoCodIntermediario($3.label, $3.tipo, $1.tipo, labelDir) + "\t";
		}
		else if (podeSerConvertidoImplicitamente($1.tipo, $3.tipo) && operadorFuncionaEmTipo(operador, $3.tipo))
		{
			// Expressão 1 pode ser convertida no tipo de Expressão 2
			tipoFinal = $3.tipo;
			tradConversão = ConversaoCodIntermediario($1.label, $1.tipo, $3.tipo, labelEsq) + "\t";
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

		if (tipoFinal == TIPO_STRING)
		{			
			StringInfo* sinfo = novaString();
			sinfo->éDinâmica = true;

			StringInfo* sinfoA = tabelaStrings[labelEsq];
			StringInfo* sinfoB = tabelaStrings[labelDir];			

			string tamanhoALabel = novaVarTemp(TIPO_INT);
			string tamanhoBLabel = novaVarTemp(TIPO_INT);
			string tamanhoSemiFinalLabel = novaVarTemp(TIPO_INT);
			string tamanhoFinalLabel = novaVarTemp(TIPO_INT);

			string tamanhoAtrad; 
			string tamanhoBtrad;

			string concatLabel = novaVarTemp(TIPO_STRING);

			if (sinfoA->éDinâmica)
			{
				tamanhoAtrad = "\t" + tamanhoALabel + " = " + StringDinamicaTamanho(labelEsq) + ";\n";
			}
			else
			{
				tamanhoAtrad = "\t" + tamanhoALabel + " = " + to_string(sinfoA->tamanho) + ";\n" ;
			}

			if (sinfoB->éDinâmica)
			{
				tamanhoBtrad = "\t" + tamanhoBLabel + " = " + StringDinamicaTamanho(labelDir) + ";\n";
			}
			else
			{
				tamanhoBtrad = "\t" + tamanhoBLabel + " = " + to_string(sinfoB->tamanho) + ";\n" ;
			}
			

			string somaTamanhos = novaVarTemp(TIPO_INT);
			string somaTamanhosLess = novaVarTemp(TIPO_INT);

			string alloc;
			string finalCpy;
			string finalLength;

			StringInfo* concatsinfo = novaString();

			if (sinfoA->éDinâmica == false && sinfoB->éDinâmica == false)
			{
				sinfo->éDinâmica = false;
				sinfo->tamanho = sinfoA->tamanho + sinfoB->tamanho - 1;
				alloc = "";
				
				concatsinfo->éDinâmica = false;
				concatsinfo->tamanho = sinfo->tamanho;								

				finalLength = "";
			}
			else
			{
				sinfo->éDinâmica = true;
				concatsinfo->éDinâmica = true;

				alloc = StringMalloc(concatLabel, somaTamanhosLess) + StringMalloc($$.label, somaTamanhosLess);

				finalLength = "\t" + StringDinamicaTamanho($$.label) + " = " + somaTamanhosLess + ";\n" ;
			}

			finalCpy = 	  	"\tstrcpy(" + concatLabel + ", " + labelEsq + ");\n"
							+ "\t" + "strcat(" + concatLabel + ", " + labelDir + ");\n"
							+ "\t" + "strcpy(" + $$.label + ", " + concatLabel + ");\n";

			tabelaStrings[$$.label] = sinfo;
			tabelaStrings[concatLabel] = concatsinfo;

			$$.traducao =   $1.traducao + $3.traducao + "\t" + tradConversão 
							+ tamanhoAtrad
							+ tamanhoBtrad							
							+ "\t" + somaTamanhos + " = " + tamanhoALabel + " + " + tamanhoBLabel + ";\n"
							+ "\t" + somaTamanhosLess + " = " + somaTamanhos + " - 1;\n"
							+ alloc
							+ finalCpy
							+ finalLength
							;
		}
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
			tradConversão = ConversaoCodIntermediario($3.label, $3.tipo, $1.tipo, labelDir) + "\t";
		}
		else if (podeSerConvertidoImplicitamente($1.tipo, $3.tipo) && operadorFuncionaEmTipo(operador, $3.tipo))
		{
			// Expressão 1 pode ser convertida no tipo de Expressão 2
			tipoFinal = $3.tipo;
			tradConversão = ConversaoCodIntermediario($1.label, $1.tipo, $3.tipo, labelEsq) + "\t";
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
			tradConversão = ConversaoCodIntermediario($3.label, $3.tipo, $1.tipo, labelDir) + "\t";
		}
		else if (podeSerConvertidoImplicitamente($1.tipo, $3.tipo) && operadorFuncionaEmTipo(operador, $3.tipo))
		{
			// Expressão 1 pode ser convertida no tipo de Expressão 2
			tipoFinal = $3.tipo;
			tradConversão = ConversaoCodIntermediario($1.label, $1.tipo, $3.tipo, labelEsq) + "\t";
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
			tradConversão = ConversaoCodIntermediario($3.label, $3.tipo, $1.tipo, labelDir) + "\t";
		}
		else if (podeSerConvertidoImplicitamente($1.tipo, $3.tipo) && operadorFuncionaEmTipo(operador, $3.tipo))
		{
			// Expressão 1 pode ser convertida no tipo de Expressão 2
			tipoFinal = $3.tipo;
			tradConversão = ConversaoCodIntermediario($1.label, $1.tipo, $3.tipo, labelEsq) + "\t";
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
			tradConversao = ConversaoCodIntermediario($2.label, $2.tipo, TIPO_BOOL, labelExp) + "\t";
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
	| '-' EXPRESSAO %prec NUM_NEGATIVO
	{
		if(!operadorFuncionaEmTipo('-', $2.tipo))
		{
			semanticError("Expressao invalida -> o operador unario '-' nao pode ser aplicado ao tipo " + tipoParaString($2.tipo));
            YYABORT; 
		}
		$$.label = novaVarTemp($2.tipo);
		$$.tipo = $2.tipo;
		$$.traducao = $2.traducao + "\t" + $$.label + " = -" + $2.label + ";\n";
	}
;

ATRIBUICAO:
	ATRIBUICAO_NAO_DECLARACATIVA
	|
	ATRIBUICAO_DECLARACATIVA
;

ATRIBUICAO_NAO_DECLARACATIVA:
	TK_ID '=' EXPRESSAO
	{		
		// Se a variável já foi declarada, apenas altera seu valor; 
		// Se a variável não era inicializada ainda, agora ela é;		
		string labelExp = $3.label;
		string tradConversao = "";

		if (varExiste($1.label) == false)
		{
			semanticError("A variável " + $1.label + " é desconhecida");
			YYABORT;
		}

		if (!tipoPodeSerAtribuido(varTipo($1.label), $3.tipo))
		{
			semanticError("Erro de tipo -> A expressão de tipo '" + tipoParaString($3.tipo) + "' não é do tipo esperado (" + tipoParaString(varTipo($1.label)) + ").");
			YYABORT;
		}
		if (varTipo($1.label) != $3.tipo)
		{
			// Deve ser feita uma conversão implícita, a expressão pode ser atribuída à essa variável, caso contrário a condicional de cima daria erro
			tradConversao = ConversaoCodIntermediario($3.label, $3.tipo, varTipo($1.label), labelExp) + "\t";
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + tradConversao + varNomeReal($1.label) + " = " + labelExp + ";" + " // " + $1.label + "\n";
		Simbolo* s = obterSimbolo($1.label);

		if (varTipo($1.label) == TIPO_STRING)
		{
			$$.traducao = $3.traducao + tradConversao + StringAtribuição($1.label, labelExp);
		}		

		s->simboloInicializado = true;		
	}
	| TK_ID '=' TK_INPUT
	{
		// Ler o input do tipo do TK_ID
		// Aqui não tem como TK_INPUT virar expressão pois é necessário inferir o tipo de TK_INPUT

		if (varExiste($1.label) == false)
		{
			semanticError("A variável " + $1.label + " é desconhecida");
			YYABORT;
		}

		TIPO tipoExp = varTipo($1.label);		
		$$.label = $1.label;				

		if (tipoExp == TIPO_STRING)
		{
			string labelExp;
			string labelExpTamanho;
			string trad = StringDinamicaInput(labelExpTamanho, labelExp);
			$$.traducao = trad + StringAtribuição($1.label, labelExp);
		}
		else if (tabelaFormatting.find(tipoExp) == tabelaFormatting.end())
		{
			semanticError("Não é possível ler o tipo " + tipoParaString(tipoExp) + " na entrada.");
			YYABORT;
		}		
		else
		{
			string labelExp = novaVarTemp(tipoExp);
			$$.traducao = "\tscanf(\"" + tabelaFormatting[tipoExp] + "\", &" + labelExp + ");\n" + "\t" + varNomeReal($1.label) + " = " + labelExp + ";" + " // " + $1.label + "\n";
		}		
		
		Simbolo* s = obterSimbolo($1.label);
		s->simboloInicializado = true; 		
	}
	| TK_ID OP_MAIS_IGUAL EXPRESSAO
	{
		if (!varExiste($1.label)) { semanticError("A variável " + $1.label + " é desconhecida"); YYABORT; }
		if (!varInicializada($1.label)) { semanticError("Variável não inicializada."); YYABORT; }

		TIPO tipoId = varTipo($1.label);
		string nomeReal = varNomeReal($1.label);
		string labelExp = $3.label;
		string tradConversao = "";

		// Verifica compatibilidade usando a operação base do composto
		if (!operadorFuncionaEmTipo('+', tipoId)) { semanticError("O operador '+=' não suporta o tipo " + tipoParaString(tipoId)); YYABORT; }
		if (!tipoPodeSerAtribuido(tipoId, $3.tipo)) { semanticError("Erro de tipo na atribuição composta."); YYABORT; }

		if (tipoId != $3.tipo)
		{
			tradConversao = ConversaoCodIntermediario($3.label, $3.tipo, tipoId, labelExp) + "\t";
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + tradConversao + nomeReal + " = " + nomeReal + " + " + labelExp + "; // " + $1.label + "\n";
	}
	| TK_ID OP_MENOS_IGUAL EXPRESSAO
	{
		if (!varExiste($1.label)) { semanticError("A variável " + $1.label + " é desconhecida"); YYABORT; }
		if (!varInicializada($1.label)) { semanticError("Variável não inicializada."); YYABORT; }

		TIPO tipoId = varTipo($1.label);
		string nomeReal = varNomeReal($1.label);
		string labelExp = $3.label;
		string tradConversao = "";

		if (!operadorFuncionaEmTipo('-', tipoId)) { semanticError("O operador '-=' não suporta o tipo " + tipoParaString(tipoId)); YYABORT; }
		if (!tipoPodeSerAtribuido(tipoId, $3.tipo)) { semanticError("Erro de tipo na atribuição composta."); YYABORT; }

		if (tipoId != $3.tipo)
		{
			tradConversao = ConversaoCodIntermediario($3.label, $3.tipo, tipoId, labelExp) + "\t";
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + tradConversao + nomeReal + " = " + nomeReal + " - " + labelExp + "; // " + $1.label + "\n";
	}
	| TK_ID OP_MULT_IGUAL EXPRESSAO
	{
		if (!varExiste($1.label)) { semanticError("A variável " + $1.label + " é desconhecida"); YYABORT; }
		if (!varInicializada($1.label)) { semanticError("Variável não inicializada."); YYABORT; }

		TIPO tipoId = varTipo($1.label);
		string nomeReal = varNomeReal($1.label);
		string labelExp = $3.label;
		string tradConversao = "";

		if (!operadorFuncionaEmTipo('*', tipoId)) { semanticError("O operador '*=' não suporta o tipo " + tipoParaString(tipoId)); YYABORT; }
		if (!tipoPodeSerAtribuido(tipoId, $3.tipo)) { semanticError("Erro de tipo na atribuição composta."); YYABORT; }

		if (tipoId != $3.tipo)
		{
			tradConversao = ConversaoCodIntermediario($3.label, $3.tipo, tipoId, labelExp) + "\t";
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + tradConversao + nomeReal + " = " + nomeReal + " * " + labelExp + "; // " + $1.label + "\n";
	}
	| TK_ID OP_DIV_IGUAL EXPRESSAO
	{
		if (!varExiste($1.label)) { semanticError("A variável " + $1.label + " é desconhecida"); YYABORT; }
		if (!varInicializada($1.label)) { semanticError("Variável não inicializada."); YYABORT; }

		TIPO tipoId = varTipo($1.label);
		string nomeReal = varNomeReal($1.label);
		string labelExp = $3.label;
		string tradConversao = "";

		if (!operadorFuncionaEmTipo('/', tipoId)) { semanticError("O operador '/=' não suporta o tipo " + tipoParaString(tipoId)); YYABORT; }
		if (!tipoPodeSerAtribuido(tipoId, $3.tipo)) { semanticError("Erro de tipo na atribuição composta."); YYABORT; }

		if (tipoId != $3.tipo)
		{
			tradConversao = ConversaoCodIntermediario($3.label, $3.tipo, tipoId, labelExp) + "\t";
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + tradConversao + nomeReal + " = " + nomeReal + " / " + labelExp + "; // " + $1.label + "\n";
	}	
;

ATRIBUICAO_DECLARACATIVA:		
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
			tradConversao = ConversaoCodIntermediario($3.label, $3.tipo, varTipo($1.label), labelExp) + "\t";
		}

		$$.label = $1.label;
		$$.traducao = $3.traducao + "\t" + tradConversao + varNomeReal($1.label) + " = " + labelExp + ";" + " // " + $1.label + "\n";

		Simbolo* s = obterSimbolo($1.label);

		if ($1.tipo == TIPO_STRING)
		{
			StringInfo* sinfoVar = tabelaStrings[s->labelReal];
			StringInfo* sinfoExp = tabelaStrings[labelExp];
			
			if (sinfoExp->éDinâmica == false)
			{
				sinfoVar->éDinâmica = false;
				sinfoVar->tamanho = sinfoExp->tamanho;
			}

			$$.traducao = $3.traducao + tradConversao + StringAtribuição($1.label, labelExp);
		}

		s->simboloInicializado = true;
	}
	| DECLARACAO '=' TK_INPUT
	{	
		// Ler o input do tipo da Declaração
		// Aqui não tem como TK_INPUT virar expressão pois é necessário inferir o tipo de TK_INPUT

		TIPO tipoExp = varTipo($1.label);		
		$$.label = $1.label;

		if (tipoExp == TIPO_STRING)
		{
			string labelExp;
			string labelExpTamanho;
			string trad = StringDinamicaInput(labelExpTamanho, labelExp);
			$$.traducao = trad + StringAtribuição($$.label, labelExp);
		}
		else if (tabelaFormatting.find(tipoExp) == tabelaFormatting.end())
		{
			semanticError("Não é possível ler o tipo " + tipoParaString(tipoExp) + " na entrada.");
			YYABORT;
		}
		else 
		{
			string labelExp = novaVarTemp(tipoExp);
			$$.traducao = "\tscanf(\"" + tabelaFormatting[tipoExp] + "\", &" + labelExp + ");\n" + "\t" + varNomeReal($1.label) + " = " + labelExp + ";" + " // " + $1.label + "\n";
		}				

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

			tabelaSimbolos.back()[$2.label] = s;						
			ordemDeclaracaoSimbolos.push(s);
			
			$$.traducao = $4.traducao + "\t" + varNomeReal($2.label) + " = " + $4.label + ";" + " // " + $2.label + "\n";

			if ($4.tipo == TIPO_STRING)
			{
				StringInfo* sinfo = tabelaStrings[$4.label];
				StringInfo* sinfoVar = novaString();

				sinfoVar->éDinâmica = sinfo->éDinâmica;				

				if (!sinfo->éDinâmica)
				{
					sinfoVar->tamanho = sinfo->tamanho;
				}			

				tabelaStrings[s->labelReal] = sinfoVar;
				$$.traducao = $4.traducao + StringAtribuição($2.label, $4.label);				
			}

			s->simboloInicializado = true;			
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

DECLARACAO_FUNCAO:
	TK_TIPO TK_ID '(' { paramsAtuaisFunc.clear(); funcaoAtual = $2.label; tipoRetornoAtual = $1.tipo; emFuncao = true; funcaoRetornouValor = false; } PARAMS_FUNCAO ')' '{' { empilharEscopo(); DeclararVariaveisLocais(paramsAtuaisFunc); } COMANDOS_OPCIONAIS '}'
	{
		desempilharEscopo();
		
		if ($1.tipo != TIPO_VAZIO && !funcaoRetornouValor)
		{
			semanticError("Função '" + $2.label + "' deve retornar um valor do tipo " + tipoParaString($1.tipo));
			YYABORT;
		}
		
		fun_assinatura* ass = new fun_assinatura;
		ass->labelUsuario = $2.label;
		ass->labelReal = funcPrefix + to_string(func_qnt++);
		ass->tipoRetorno = $1.tipo;		
		ass->params = paramsAtuaisFunc;
		paramsAtuaisFunc.clear(); // no fim da declaração da função, limpa a lista novamente dos parâmetros

		string header = tipoCodIntermediario($1.tipo) + " " + ass->labelReal + "(";
		for (int i = 0; i < ass->params.size(); i++)
		{
			header += tipoCodIntermediario(ass->params[i].tipo) + " " + ass->params[i].labelReal;

			if (i + 1 < ass->params.size())
				header += ", ";
		}
		header += ") // " + ass->labelUsuario + "\n{\n";

		ass->traducao = header + $9.traducao + "\n}\n";

		ass->labelRetorno = "";
		if ($1.tipo != TIPO_VAZIO)
		{
			ass->labelRetorno = novaVarTemp($1.tipo);
		}		

		tabelaFuncoes[$2.label] = *ass;
		
        funcaoAtual = "";
        tipoRetornoAtual = TIPO_VAZIO;
        emFuncao = false;
        funcaoRetornouValor = false;

		$$.traducao = "";
	}
;

PARAMS_FUNCAO:
	TK_TIPO TK_ID
	{
		// Evita que o tipo do parametro seja "void"
		if ($1.tipo == TIPO_VAZIO)
		{
			semanticError("Um parâmetro não pode ser do tipo " + tipoParaString($1.tipo));
			YYABORT;
		}

		fun_param param;
		param.tipo = $1.tipo;
		param.labelUsuario = $2.label;
		param.labelReal = novaVarTemp($1.tipo);		

		paramsAtuaisFunc.push_back(param);
	}
	| PARAMS_FUNCAO ',' TK_TIPO TK_ID
	{
		// Evita que o tipo do parametro seja "void"
		if ($1.tipo == TIPO_VAZIO)
		{
			semanticError("Um parâmetro não pode ser do tipo " + tipoParaString($1.tipo));
			YYABORT;
		}

		fun_param param;
		param.tipo = $3.tipo;
		param.labelUsuario = $4.label;		
		param.labelReal = novaVarTemp($3.tipo);

		paramsAtuaisFunc.push_back(param);
	}
	| /* vazio, fazendo os parametros serem opcionais */
;

ARGS:
    /* vazio */
    {
    }
    | EXPRESSAO
    {
        argsStack.back().push_back($1);
    }
    | ARGS ',' EXPRESSAO
    {
        argsStack.back().push_back($3);
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
	s->éDinâmica = false;
	s->transicionou = false;
	s->tamanho = 0;
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

Label* novaLabel(TipoComando tipo)
{
	Label* label = new Label();

	if(tipo == TipoComando::IF_ELSE)
	{
	label->labelInicio = "label_Else_" + to_string(label_qnt);
	label->labelFim = "label_Fim_" + to_string(label_qnt);
	} else if(tipo == TipoComando::SWITCH)
	{
	label->labelInicio = "label_Inicio_Case_" + to_string(label_qnt) + "_";
	label->labelFim = "label_Fim_" + to_string(label_qnt);
	}else
	{
		label->labelInicio = "label_Inicio_" + to_string(label_qnt);
		label->labelFim = "label_Fim_" + to_string(label_qnt);
	}
		
	label->tipoComando = tipo;
	label_qnt++;
	tabelaLabels.push_back(label);
	return label;
}

Label* desempilharLabel()
{
	Label* label = tabelaLabels.back();
	tabelaLabels.pop_back();
	return label;
}

Caso* novaCaso(string label, TIPO tipoValor, string valorCaso)
{
	Caso* caso = new Caso();
	caso->labelCaso = label;
	caso->tipoValor = tipoValor;
	caso->valorCaso = valorCaso;
	caso->numCaso = label_qnt_casos; // Atribuir o número do caso com base no contador de casos, garantindo unicidade

	tabelaCasos.push(caso);

	return caso;
}

Caso* desempilharCaso()
{
	Caso* caso = tabelaCasos.front();
	tabelaCasos.pop();
	return caso;
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
		case TIPO_VAZIO:
			return "void";
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
		case TIPO_VAZIO:
			return "void";
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
	tipoAtual = {TIPO_CHAR, TIPO_STRING};
	conversaoInfoAtual.tipo = TipoDeConversao::Implicita;
	tabelaConversao[tipoAtual] = conversaoInfoAtual;
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

	// STRING
	tabelaDeOperadoresAdd('+', TIPO_STRING);
}

void inicializarTabelaFormatting()
{
	tabelaFormattingAdd(TIPO_INT, "%d");
	tabelaFormattingAdd(TIPO_FLOAT, "%f");
	tabelaFormattingAdd(TIPO_CHAR, "%c");
	tabelaFormattingAdd(TIPO_STRING, "%s");
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
		tradConversao = ConversaoCodIntermediario(exp2.label, exp2.tipo, exp1.tipo, labelConvertido);
		return 1;
	}
	else if (podeSerConvertidoImplicitamente(exp1.tipo, exp2.tipo) && operadorFuncionaEmTipo(operador, exp2.tipo))
	{
		// Expressão 1 pode ser convertida no tipo de Expressão 2		
		tradConversao = ConversaoCodIntermediario(exp1.label, exp1.tipo, exp2.tipo, labelConvertido);
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

// Realiza a conversão de uma variável de labelA com tipoA para o tipoB, guardando o resultado em labelB
// Para tipos nativos, realiza uma conversão simples no código intermediário (por meio de cast no C) com label 'labelA' para uma do tipo 'B',
// retornando o código intermediário dessa conversão e o label da variável temporário que guarda a variável convertida 'labelB'
// Para tipos complexos, realiza uma série de procedimentos
// OBS: Na maioria dos casos, não verifica se a conversão pode ou não ser feita, apenas faz um casting no código intermediário; Para verificar, use 
// podeSerConvertidoExplicitamente ou podeSerConvertidoImplicitamente
string ConversaoCodIntermediario(string labelA, TIPO tipoA, TIPO tipoB, string& labelB)
{
	string s; 
	labelB = novaVarTemp(tipoB);

	if (tipoA == TIPO_CHAR && tipoB == TIPO_STRING)
	{
		StringInfo* sinfo = novaString();
		sinfo->éDinâmica = true;
		tabelaStrings[labelB] = sinfo;

		string malloc = StringMalloc(labelB, to_string(2)); // char e \0
		s = malloc 
			+ "\t" + labelB + "[" + to_string(0) + "] = " + labelA + ";\n" 
			+ "\t" + labelB + "[" + to_string(1) + "] = \'\\0\';\n"
			+ "\t" + StringDinamicaTamanho(labelB) + " = 2;\n" 
			; 
	}
	else
	{
		s = labelB + " = " + "(" + tipoCodIntermediario(tipoB) + ")" + " " + labelA + ";\n";
	}	

	return s;
}

// Retorna um código intermediário inline para ler uma string dinâmica enviada pelo usuário, salvando ela em uma variável (labelString) e salvando um label para o seu tamanho
// Recebe como entrada uma referência de uma string tamanho, que se transformará no label da variável com o tamanho final da string
// Recebe por referência também a string com a label da string dinâmica que receberá 
string StringDinamicaInput(string& tamanho, string& labelString)
{
	usandoInputBuffer = true; // Marca o input buffer como usado
	// OBS: O buffer não é preciso alocar pois ele já é alocado no final, caso usandoInputBuffer = true

	tamanho = novaVarTemp(TIPO_INT); // O label da var temp que guarda o tamanho total da string 
	string indexLabel = novaVarTemp(TIPO_INT); // O label da var temp que guarda qual o índice do buffer que está sendo lido no momento
	string bufferLabel = string(str_inputBuffer_label); // O label do buffer para a entrada de strings
	string charSizeLabel = novaVarTemp(TIPO_INT); // O label da variável que carregará sizeof(char)
	string charLidoLabel = novaVarTemp(TIPO_CHAR); // O label da var temp que guarda qual caractere foi lido da entrada
	string bufferTamanho = novaVarTemp(TIPO_INT); // O tamanho real do buffer para chars (-2 pois começa em 0 e \0 tem que aparecer no final do buffer pro código funcionar)

	string stringAtual = novaVarTemp(TIPO_STRING); // (O label da) A string que está sendo "construída" atualmente

	StringInfo* stringAtualInfo = novaString();
	stringAtualInfo->éDinâmica = true;
	tabelaStrings[stringAtual] = stringAtualInfo;

	string stringTemp = novaVarTemp(TIPO_STRING); // (O label de) Uma string temporária usada na concatenação das strings

	StringInfo* stringTempInfo = novaString();
	stringTempInfo->éDinâmica = true;
	tabelaStrings[stringTemp] = stringTempInfo;

	labelString = novaVarTemp(TIPO_STRING); // (O label da) A string temporária final com a string lida pelo usuário

	StringInfo* stringFinalInfo = novaString();
	stringFinalInfo->éDinâmica = true;
	tabelaStrings[labelString] = stringFinalInfo;

	int labelWhileIndex = label_qnt; label_qnt++; // Um identificador único para os labels do while
	int labelIfIndex = label_qnt; label_qnt++;	// Um identificador único para os labels do if

	string whileExpLabel = novaVarTemp(TIPO_BOOL);
	string ifExpLabel = novaVarTemp(TIPO_BOOL);
	string ifExpNotLabel = novaVarTemp(TIPO_BOOL);

	string indexPlusLabel = novaVarTemp(TIPO_INT); 

	string tamanhoPlus = novaVarTemp(TIPO_INT);
	string stringTmpTamanho = novaVarTemp(TIPO_INT);

	string trad;

	trad = 	"\t"   + charSizeLabel + " = sizeof(char);\n" 
			+ "\t" + bufferTamanho + " = " + to_string(str_inputBuffer_len) + " - 2;\n"
			+ "\t" + stringAtual + " = (char*) malloc(" + charSizeLabel + ");\n"
			+ "\t" + tamanho + " = 0;\n"
			+ "\t" + indexLabel + " = 0;\n"
			+ "\t" + "strcpy(" + stringAtual + ", \"\");\n"
			+ "\t" + "scanf(\"%c\", &" + charLidoLabel + ");\n"
				   + "strscanner_ini_" + to_string(labelWhileIndex) + ":\n"  
			+ "\t" + whileExpLabel + " = " + charLidoLabel + " == \'\\n\';\n"
			+ "\t" + "if (" + whileExpLabel + ")\n" + 
			+ "\t" + "\t" + "goto strscanner_fim_" + to_string(labelWhileIndex) + ";\n"
			+ "\t" + tamanho + " = " + tamanho + " + 1;\n"
			+ "\t" + bufferLabel + "[" + indexLabel + "] = " + charLidoLabel + ";\n" 
			+ "\t" + ifExpLabel + " = " + indexLabel + " == " + bufferTamanho + ";\n"
			+ "\t" + ifExpNotLabel + " = !" + ifExpLabel + ";\n"
			+ "\t" + "if (" + ifExpNotLabel + ")\n" +
			+ "\t" + "\t" + "goto strscanner_if_fim_" + to_string(labelIfIndex) + ";\n"
			+ "\t" + indexPlusLabel + " = " + indexLabel + " + 1;\n"
			+ "\t" + bufferLabel + "[" + indexPlusLabel + "] = \'\\0\';\n"
			+ "\t" + tamanhoPlus + " = " + tamanho + " + 1;\n"
			+ "\t" + stringTmpTamanho + " = " + tamanhoPlus + " * " + charSizeLabel + ";\n"
			+ "\t" + stringTemp + " = (char*) malloc(" +  stringTmpTamanho + ");\n"
			+ "\t" + "strcpy(" + stringTemp + ", " + stringAtual + ");\n"
			+ "\t" + "strcat(" + stringTemp + ", " + bufferLabel + ");\n"
			+ "\t" + "free(" + stringAtual + ");\n"
			+ "\t" + stringAtual + " = (char*) malloc(" + stringTmpTamanho + ");\n"
			+ "\t" + "strcpy(" + stringAtual + ", " + stringTemp + ");\n"
			+ "\t" + "free(" + stringTemp + ");\n"
			+ "\t" + indexLabel + " = -1;\n"			
				   + "strscanner_if_fim_" + to_string(labelIfIndex) + ":\n"
			+ "\t" + indexLabel + " = " + indexLabel + " + 1;\n"
			+ "\t" + "scanf(\"%c\", &" + charLidoLabel + ");\n"
			+ "\t" + "goto strscanner_ini_" + to_string(labelWhileIndex) + ";\n"
			       + "strscanner_fim_" + to_string(labelWhileIndex) + ":\n"  
			+ "\t" + tamanhoPlus + " = " + tamanho + " + 1;\n"
			+ "\t" + bufferLabel + "[" + indexLabel + "] = \'\\0\';\n" 
			+ "\t" + stringTmpTamanho + " = " + tamanhoPlus + " * " + charSizeLabel + ";\n"
			+ "\t" + stringTemp + " = (char*) malloc(" +  stringTmpTamanho + ");\n"
			+ "\t" + "strcpy(" + stringTemp + ", " + stringAtual + ");\n"
			+ "\t" + "strcat(" + stringTemp + ", " + bufferLabel + ");\n"
			+ "\t" + "free(" + stringAtual + ");\n"
			+ "\t" + stringAtual + " = (char*) malloc(" + stringTmpTamanho + ");\n"
			+ "\t" + "strcpy(" + stringAtual + ", " + stringTemp + ");\n"
			+ "\t" + "free(" + stringTemp + ");\n"
			+ "\t" + labelString + " = (char*) malloc(" + stringTmpTamanho + ");\n"
			+ "\t" + "strcpy(" + labelString + ", " + stringAtual + ");\n"
			+ "\t" + StringDinamicaTamanho(labelString) + " = " + tamanhoPlus + ";\n"
			+ "\t" + tamanho + " = " + tamanhoPlus + ";\n";
	
	// while V
		// Fazer a EXP do if V
		// Fazer o IF V
			// Colocar o \0 no buffer V
			// Fazer a concatenação do buffer na string atual V
			// Zerar o índice V
		// Colocar o label de fim do IF V
		// Aumentar o índice V
		// Scanear o lido V
	// fim do while V
	// Fazer a concatenação final do buffer V
	// Criar uma nova string temporária dinâmica V
	// Copiar o lido nessa string temporária dinâmica V
	// Salvar o tamanho dessa string temporária dinâmica (tamanhoPlus -> mesmo tamanho da string final) V

	return trad;
}

// Retorna o código intermediário usado para alocar uma string dinâmica em labelString 
// Recebe uma labelString que será a label que receberá a string alocada e
// Recebe labelComQntCharOuConstante, que é uma string de um int constante (ex.: to_string(5)) ou uma label que contém a quantia de caracteres (\0 deve estar incluído) que será alocada
string StringMalloc(string labelString, string labelComQntCharOuConstante)
{	
	string tmpA = novaVarTemp(TIPO_INT); // O tamanho da string 				
	string tmpB = novaVarTemp(TIPO_INT); // sizeof(char)
	string tmpC = novaVarTemp(TIPO_INT); // tamanho * sizeof(char)
	string malloc = "\t" + tmpA + " = " + labelComQntCharOuConstante + ";\n\t" + tmpB + " = sizeof(char);\n\t" + tmpC + " = " + tmpA + " * " + tmpB + ";\n\t" + labelString + " = (char*) malloc(" + tmpC + ");\n";
	return malloc;
}

// Retorna a label da variável que guarda 
string StringDinamicaTamanho(string labelString)
{
	return labelString + str_length_suffix;
}

// Serve para atribuir uma string à outra, mesmo que elas não sejam do mesmo tipo (Dinâmica ou estática);
// lString -> label de usuário string da esquerda
// rString -> label real da string da direita
// Retorna a tradução para a atribuiçao de lString = rString
string StringAtribuição(string lString, string rString)
{
	string retorno = "";

	string lString_labelReal = varNomeReal(lString); // O label real do ID que será atribuido um valor
	string labelExp = rString; // O label real da expressão que será atribuida no ID

	StringInfo* sinfoVar = tabelaStrings[lString_labelReal];						
	StringInfo* sinfoExp = tabelaStrings[labelExp];			

	Simbolo* s = obterSimbolo(lString); // O Símbolo 

	if (sinfoExp->éDinâmica)
	{
		if (sinfoVar->éDinâmica)
		{
			// STRING LEFT DINAMICA, STRING RIGHT DINAMICA
			string free = "";
			if (s->simboloInicializado)
			{
				free = "\tfree(" + s->labelReal + ");\n";
			}

			// Calcular tamanho da string dinâmica exp (labelExp) e colocar em tmpTamanhoExp				
			string tamanhoLabel = novaVarTemp(TIPO_INT);
			string tamanhoTrad = "\t" + tamanhoLabel + " = " + StringDinamicaTamanho(labelExp) + ";\n";
			// calcula o tamanho que deve ser alocado, usando o tamanho * sizeof(char)
			// alocar essa quantia
			string malloc = StringMalloc(s->labelReal, tamanhoLabel);
			// atualiza a tradução final
			retorno = 	free + tamanhoTrad + malloc 
						+ "\tstrcpy(" + s->labelReal + ", " + labelExp + ")" + ";" + " // " + lString + "\n\t" 
						+ StringDinamicaTamanho(s->labelReal) + " = " + tamanhoLabel + ";\n"; // altera a variável que guarda o tamanho dessa string (LEFT)
		}
		else
		{
			// STRING LEFT ESTATICA, STRING RIGHT DINAMICA

			// Calcular tamanho da string right dinâmica 
			string tamanhoLabel = novaVarTemp(TIPO_INT);
			string tamanhoTrad = "\t" + tamanhoLabel + " = " + StringDinamicaTamanho(labelExp) + ";\n";

			// dar free 
			string free = "\tfree(" + s->labelReal + ");\n";

			// calcular o tamanho que deve ser alocado, usando o tamanho * sizeof(char)					
			// alocar nova string
			string malloc = StringMalloc(s->labelReal, tamanhoLabel);

			// transformar a string estática TK_ID em uma dinâmica na tabela de strings
			sinfoVar->éDinâmica = true;
			// registrar que ocorreu essa transição e guardar o maior tamamnho estático dela
			// OBS: O maior tamanho de string estática fica salvo em sinfoVar->tamanho
			sinfoVar->transicionou = true; 					
											
			// traducao final
			retorno = 	free + tamanhoTrad + malloc 
						+ "\tstrcpy(" + s->labelReal + ", " + labelExp + "); // " + lString + "\n\t"
						+ StringDinamicaTamanho(s->labelReal) + " = " + tamanhoLabel + ";\n"; // altera a variável que guarda o tamanho dessa string (LEFT)
		}
	}
	else
	{
		if (sinfoVar->éDinâmica)
		{
			// STRING LEFT DINAMICA, STRING RIGHT ESTATICA
			string free = "";
			if (s->simboloInicializado)
			{
				free = "\tfree(" + s->labelReal + ");\n";
			}

			string malloc = StringMalloc(s->labelReal, to_string(sinfoExp->tamanho));
			retorno =   free + malloc 
						+ "\tstrcpy(" + s->labelReal + ", " + labelExp +")" + ";" + " // " + lString + "\n\t" 
						+ StringDinamicaTamanho(s->labelReal) + " = " + to_string(sinfoExp->tamanho) + ";\n";	
		}
		else
		{
			// STRING LEFT ESTATICA, STRING RIGHT ESTATICA
			int tamanho = 0; 

			// Determina o tamanho da string da esquerda (ID) baseado em qual string pode suportar mais chars
			if (sinfoVar->tamanho > sinfoExp->tamanho)
			{
				tamanho = sinfoVar->tamanho;
			}
			else
			{
				tamanho = sinfoExp->tamanho;
			}

			sinfoVar->tamanho = tamanho; 
			retorno = "\tstrcpy(" + s->labelReal + ", " + labelExp +")" + ";" + " // " + lString + "\n";					
		}
	}

	return retorno;
}

string DeclararVariaveisTemporarias(bool* b, TIPO* tipoErrado)
{
	string varTemp = "\t// Variaveis Temporarias\n";

	int i = 0;
	while (!tipoDosTemporarios.empty())
	{			 
		TIPO tipoVar = tipoDosTemporarios.front();			
		
		if (tipoDiretoCodIntermediario(tipoVar))
		{
			varTemp += "\t" + tipoCodIntermediario(tipoVar) + " " + tmpVarPrefix + to_string(i) + ";" + " // " + tipoParaString(tipoVar) + "\n";			
		}
		else if (tipoVar == TIPO_STRING)
		{				
			StringInfo* sinfo = tabelaStrings[tmpVarPrefix + to_string(i)];

			if (sinfo->éDinâmica)
			{
				// Usar char*
				varTemp += string("\tchar* ") + tmpVarPrefix + to_string(i) + ";" + " // " + tipoParaString(tipoVar) + "\n";			
				varTemp += string("\tint ") + tmpVarPrefix + to_string(i) + str_length_suffix + ";\n";

				// OBS: AS variáveis string temporárias podem se transicionar?
				if (sinfo->transicionou)
				{						
					varTemp += StringMalloc(tmpVarPrefix + to_string(i), to_string(sinfo->tamanho));
				}
			}
			else
			{
				// Usar char[]
				varTemp += string("\tchar ") + tmpVarPrefix + to_string(i) + "[" + to_string(sinfo->tamanho) + "]" + ";" + " // " + tipoParaString(tipoVar) + "\n";	
			}
		}			
		else
		{
			*b = true;
			*tipoErrado = tipoVar;
			return varTemp;
		}

		tipoDosTemporarios.pop();
		i++;
	}	

	if (usandoInputBuffer)
		varTemp += "\tchar " str_inputBuffer_label "[" + to_string(str_inputBuffer_len) + "];\n";

	return varTemp;					
}

string DeclararVariaveisUsuario(bool* b, TIPO* tipoErrado)
{
	string codigo_gerado = "\n\t// Variaveis De Usuario\n";		

	while (!ordemDeclaracaoSimbolos.empty())
	{			 
		Simbolo* s = ordemDeclaracaoSimbolos.front();
		TIPO tipoVar = s->tipoDeclarado;
		
		if (tipoDiretoCodIntermediario(tipoVar))
		{
			codigo_gerado += "\t" + tipoCodIntermediario(s->tipoDeclarado) + " " + s->labelReal + ";" + " // " + tipoParaString(s->tipoDeclarado) + " " + s->labelUsuario + "\n";
		}			
		else if (tipoVar == TIPO_STRING)
		{
			StringInfo* sinfo = tabelaStrings[s->labelReal];

			if (sinfo->éDinâmica)
			{
				// Usar char*
				codigo_gerado += string("\tchar* ") + s->labelReal + ";" + " // " + tipoParaString(s->tipoDeclarado) + " " + s->labelUsuario + "\n";		
				codigo_gerado += "\tint " + s->labelReal + str_length_suffix + ";\n";

				if (sinfo->transicionou)
				{						
					codigo_gerado += StringMalloc(s->labelReal, to_string(sinfo->tamanho));										
				}
			}
			else
			{
				// Usar char[]
				codigo_gerado += string("\tchar ") + s->labelReal + "[" + to_string(sinfo->tamanho) + "]" + ";" + " // " + tipoParaString(s->tipoDeclarado) + " " + s->labelUsuario + "\n";	
			}
		}
		else
		{
			*b = true;
			*tipoErrado = tipoVar;
			return codigo_gerado;
		}

		ordemDeclaracaoSimbolos.pop();
	}
	codigo_gerado += "\n";		

	return codigo_gerado;
}

// Usado nas funções para declarar corretamente as variáveis locais dentro do bloco da função
void DeclararVariaveisLocais(const vector<fun_param>& params)
{
	for (auto& p : params)
	{
		Simbolo* s = new Simbolo;

		s->labelReal = p.labelReal;
		s->labelUsuario = p.labelUsuario;
		s->tipoDeclarado = p.tipo;
		s->simboloInicializado = true; // Uma variável local passada por param. sempre é inicializada

		tabelaSimbolos.back()[p.labelUsuario] = s;		
			
		if (p.tipo == TIPO_STRING)
		{
			StringInfo* sinfo = novaString();
			sinfo->éDinâmica = true;				
			tabelaStrings[s->labelReal] = sinfo;				
		}
	}
}

// Usado para inicializar as estruturas e controladores usados no compilador;
void initialize()
{
	var_temp_qnt = 0;
	var_qnt = 0;
	func_qnt = 0;
	usandoInputBuffer = false;

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
