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
Label* novaLabel(TipoComando tipoComando);
//void empilharLabel(string labelInicio, string labelFim);
Label* desempilharLabel();
Caso* novaCaso(string labelCaso, TIPO tipoValor, string valorCaso);
Caso* desempilharCaso();
void inicializarTabelaFormatting();
void tabelaFormattingAdd(TIPO tipo, string cFormato);

// Variáveis
int var_temp_qnt; // Contador de variáveis temporárias
int var_qnt; // Contador de variáveis globais não temporárias criadas

int label_qnt; // Contador de labels criadas
int label_qnt_casos; // Contador de labels de casos criados; Usado para diferenciar os labels de casos dos labels de controle de fluxo

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

deque<Label*> tabelaLabels; // Pilha de labels para controle de fluxo (while, for, etc.);
 
queue<Caso*> tabelaCasos; // Lista de casos para o switch;
// Dado um TIPO (int, float, bool, char) salva qual o formato em C para ler/escrever aquele tipo no código intermediário
// ex.: "%d" para int, "%f" para float, "%c" para char... 
// OBS: as booleanas serão um problema, pois devem ser lidas como uma string (true/false) e transformadas em seu valor inteiro 1 ou 0
unordered_map<TIPO, string> tabelaFormatting;

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

// TOKEN PARA OS DIFERENTES COMANDOS DE CONTROLE DE FLUXO; OBS: Para cada comando novo, deve-se criar um token correspondente e alterar o lexer para retornar esse token quando encontrar a palavra reservada do comando
%token TK_IF TK_ELSE TK_WHILE TK_FOR TK_SWITCH TK_CASE TK_DEFAULT TK_DO

%token TK_BREAK TK_CONTINUE TK_ESCAPE

/* OBS: Cada novo tipo adicionado, deve-se criar um token desses e alterar o yylval.tipo para o token correspondente no lexer  */
/* 		É também necessário, para cada tipo novo, alterar: tipoCodIntermediario, tipoParaString, inicializarTabelaConversao e inicializarTabelaDeOperadores 	*/
%token TK_INPUT TK_OUTPUT

/* TOKEN PARA OS TIPOS DIFERENTES */
/* OBS: Cada novo tipo adicionado, deve-se criar um token desses e alterar o yylval.tipo para o token correspondente no lexer  */
/* 		É também necessário, para cada tipo novo, alterar: tipoCodIntermediario, tipoParaString, inicializarTabelaConversao, inicializarTabelaDeOperadores e inicializarTabelaFormatting 	*/
%token TIPO_INT
%token TIPO_FLOAT
%token TIPO_CHAR
%token TIPO_BOOL
%token TIPO_VAZIO


%start OUTPUT

%nonassoc TK_NO_ELSE // Usado para marcar o final de um comando if sem else, para resolver o "dangling else problem"; O TK_NO_ELSE é não associativo, ou seja, ele não pode ser associado a nenhum else; Assim, o else mais próximo de um if sempre será associado a ele, e não a um if mais distante
%nonassoc TK_ELSE // Para resolver o "dangling else problem"; O TK_ELSE é não associativo, ou seja, ele só pode ser associado ao if mais próximo; Assim, o else mais próximo de um if sempre será associado a ele, e não a um if mais distante

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
		
		codigo_gerado += "\n\t// Variaveis De Usuario\n";				
		while (!ordemDeclaracaoSimbolos.empty())
		{			 
			Simbolo* s = ordemDeclaracaoSimbolos.front();

			// TODO: No futuro, verificar se esse tipo pode descrito facilmente assim no cod. intermediário
			codigo_gerado += "\t" + tipoCodIntermediario(s->tipoDeclarado) + " " + s->labelReal + ";" + " // " + s->labelUsuario + "\n";

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

IF :
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

		for(int i = 0; i < label_qnt_casos; i++)
		{
			Caso* caso = desempilharCaso();

			if(caso->tipoValor == TIPO_VAZIO) //Default
			{
				traducaoIF += "\tgoto " + caso->labelCaso + ";\n";
				continue;
			}

			if(caso->tipoValor != $1.tipo) 
			{ 
				semanticError("Comparação invalida -> Tipo diferente entre a expressão do switch e o valor do caso. Tipo da expressão: '" + tipoParaString($1.tipo) + "'; Tipo do caso: '" + tipoParaString(caso->tipoValor) + "'.");
				YYABORT;
			}

			string labelExp = novaVarTemp(TIPO_BOOL);
			string labelCasoValor = novaVarTemp(caso->tipoValor);

			traducaoIF += "\t" + labelCasoValor + " = " + caso->valorCaso + ";\n" + "\t" + labelExp + " = " + $1.label + " == " + labelCasoValor + ";\n" + "\tif (" + labelExp + ")\n\t\tgoto " + caso->labelCaso + ";\n";

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
