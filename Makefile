# rev 3.0

CXXFLAGS = -Wall -Wunused-function -Wno-free-nonheap-object -finput-charset=UTF-8 -fexec-charset=UTF-8

SCANNER = flex
SCANNER_FILE = scanner.l
SCANNER_OUTPUT = scanner

PARSER = bison
PARSER_FILE = parser.y
PARSER_OUTPUT = parser

OUTPUT_DIR = build
OUTPUT_FILE = compilador

SRC_CODE_INPUT_FILE = input.teste
INT_CODE_OUTPUT_FILE = output

all: build
exec: build compile_int
runexec: build compile_int run_int
build: clean buildLex buildYacc	compile
generate: clean buildLex buildYacc
clear: clean

buildLex:
	$(SCANNER) $(SCANNER_FILE) 
	mkdir -p $(OUTPUT_DIR)
	mv lex.yy.c $(OUTPUT_DIR)/$(SCANNER_OUTPUT).c

buildYacc:
	$(PARSER) -d --yacc $(PARSER_FILE)
	mkdir -p $(OUTPUT_DIR)
	mv y.tab.c $(OUTPUT_DIR)/$(PARSER_OUTPUT).c
	mv y.tab.h $(OUTPUT_DIR)/$(PARSER_OUTPUT).h
	
compile: 
	cd $(OUTPUT_DIR) && g++ $(CXXFLAGS) $(PARSER_OUTPUT).c -o $(OUTPUT_FILE)

# Serve para, além de compilar o compilador, executar o compilador com um arquivo fonte de SRC_CODE_INPUT_FILE e compila INT_CODE_OUTPUT_FILE como código intermediário C 
# compilando também esse código intermediário em um executável
# cd $(OUTPUT_DIR) && ./$(OUTPUT_FILE) $(SRC_CODE_INPUT_FILE) -o $(INT_CODE_OUTPUT_FILE).c && gcc $(INT_CODE_OUTPUT_FILE).c -o $(INT_CODE_OUTPUT_FILE)
compile_int:
	./$(OUTPUT_DIR)/$(OUTPUT_FILE) $(SRC_CODE_INPUT_FILE) -o $(OUTPUT_DIR)/$(INT_CODE_OUTPUT_FILE).c 
	gcc $(OUTPUT_DIR)/$(INT_CODE_OUTPUT_FILE).c -o $(OUTPUT_DIR)/$(INT_CODE_OUTPUT_FILE)

run_int:
	cd $(OUTPUT_DIR) && ./$(INT_CODE_OUTPUT_FILE)

clean: 
	rm -f -r $(OUTPUT_DIR)