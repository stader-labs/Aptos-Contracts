.PHONY: build

Mod = 0xCAFE
aptos = ~/bin/aptos

build: 
	${aptos} move compile --package-dir ./ --named-addresses liquid_token=${Mod}

.PHONY: test
test: 
	${aptos} move test --package-dir ./ --named-addresses liquid_token=0xCAFE

.PHONY: publish
publish:
	${aptos} move publish --named-addresses liquid_token=${Mod}