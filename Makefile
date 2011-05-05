.PHONY: js clean dep cleandep test rtest doc docinit

COFFEE=node_modules/coffee-script/bin/coffee
NODE=node

apidoc_sources = $(wildcard doc/api/*.md)
apidocs = $(addprefix build/,$(apidoc_sources:.md=.html))

doc_sources = $(wildcard doc/*.md)
docs = $(addprefix build/,$(doc_sources:.md=.html))

docinit:
	@mkdir -p build/doc/api build/doc/css build/doc/js
	@cp doc/css/* build/doc/css
	@cp doc/js/* build/doc/js

build/doc/api/%.html: doc/api/%.md docinit
	$(NODE) ext/doctool/doctool.js doc/layout.html $< $@

build/doc/%.html: doc/%.md docinit
	$(NODE) ext/doctool/doctool.js doc/layout.html $< $@

build/doc/readme.html: README.md docinit
	$(NODE) ext/doctool/doctool.js doc/layout.html $< $@

doc: $(apidocs) $(docs) build/doc/readme.html
	@echo "generated html in folder build/doc"


node_modules/flag:
	@npm install
	@touch node_modules/flag

dep: node_modules/flag

install:
	npm install -g

js: dep
	@mkdir -p build/js
	@mkdir -p build/js/lib
	@mkdir -p build/js/test
	@mkdir -p build/js/rtest
	@mkdir -p build/js/examples
	@${COFFEE} -c -o build/js/lib lib/*.coffee
	@${COFFEE} -c -o build/js/test test/*.coffee
	@#${COFFEE} -c -o gen-js/examples examples/*.coffee
	@cp index.js build/js
	@cp -r examples/*.js build/js/examples
	@cp -rf node_modules build/js/node_modules
	@echo "generated javascript in folder build/js"

clean:
	@rm -rf tmp
	@rm -rf build

cleandep:
	@rm -rf node_modules

test: dep
	@mkdir -p tmp
	@expresso

rtest: dep
	@expresso rtest/*
