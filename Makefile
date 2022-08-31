.PHONY: build

Mod = 0x833781e93f9b2abf507a113d517290aed99befe1d450cbb15b73c65337292222
aptos = ~/bin/aptos

build: 
	${aptos} move compile --package-dir ./ --named-addresses aptosx=${Mod}

.PHONY: test
test: 
	${aptos} move test --package-dir ./ --named-addresses aptosx=0xCAFE

.PHONY: publish
publish:
	${aptos} move publish --named-addresses aptosx=${Mod}