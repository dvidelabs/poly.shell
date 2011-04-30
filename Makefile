.PHONY: js clean dep cleandep test rtest

COFFEE=node_modules/coffee-script/bin/coffee

node_modules/flag:
	@npm install
	@touch node_modules/flag

dep: node_modules/flag

install:
	npm install -g

js: dep
	@mkdir -p gen-js
	@mkdir -p gen-js/lib
	@mkdir -p gen-js/test
	@mkdir -p gen-js/examples
	@${COFFEE} -c -o gen-js/lib lib/*.coffee
	@${COFFEE} -c -o gen-js/test test/*.coffee
	@#${COFFEE} -c -o gen-js/examples examples/*.coffee
	@cp index.js gen-js
	@cp -r examples/*.js gen-js/examples
	@echo "generated javascript in folder gen-js"

clean:
	@rm -rf tmp
	@rm -rf gen-js

cleandep:
	@rm -rf node_modules

test: dep
	mkdir -p tmp
	@expresso

rtest: dep
	@expresso rtest/*