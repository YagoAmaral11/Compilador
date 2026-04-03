CXXFLAGS = -Wno-free-nonheap-object

SCANNER = flex
SCANNER_FILE = lexico.l
SCANNER_OUTPUT = testeLex

PARSER = bison
PARSER_FILE = sintatico.y
PARSER_OUTPUT = testeYacc

OUTPUT_DIR = build
OUTPUT_FILE = compilador

all: build

compile: build

clean: 
	rm -r $(OUTPUT_DIR)

build: buildLex buildYacc
	cd $(OUTPUT_DIR) && g++ $(CXXFLAGS) $(PARSER_OUTPUT).c -o $(OUTPUT_FILE)

buildLex:
	$(SCANNER) $(SCANNER_FILE) 
	mv lex.yy.c $(OUTPUT_DIR)/$(SCANNER_OUTPUT).c

buildYacc:
	$(PARSER) -d --yacc $(PARSER_FILE) 
	mv y.tab.c $(OUTPUT_DIR)/$(PARSER_OUTPUT).c
	mv y.tab.h $(OUTPUT_DIR)/$(PARSER_OUTPUT).h