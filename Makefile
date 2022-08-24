.PHONY: build
build: 
	aptos move compile --package-dir ./ --named-addresses aptosXCoinType=0xCAFE
test: 
	aptos move test --package-dir ./ --named-addresses aptosXCoinType=0xCAFE