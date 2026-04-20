CXXFLAGS = -Wall -Wunused-function -Wno-free-nonheap-object -finput-charset=UTF-8 -fexec-charset=UTF-8

SCANNER = flex
SCANNER_FILE = scanner.l
SCANNER_OUTPUT = scanner

PARSER = bison
PARSER_FILE = parser.y
PARSER_OUTPUT = parser

OUTPUT_DIR = build
OUTPUT_FILE = compilador

all: build
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

clean: 
	rm -f -r $(OUTPUT_DIR)