.PHONY: build

Mod = 0xCAFE
aptos = ./aptos

build: 
	${aptos} move compile --package-dir ./ --named-addresses liquidToken=${Mod}

.PHONY: test
test: 
	${aptos} move test --package-dir ./ --named-addresses liquidToken=${Mod}

.PHONY: publish
publish:
	${aptos} move publish --named-addresses liquidToken=${Mod}