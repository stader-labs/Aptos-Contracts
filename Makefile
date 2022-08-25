.PHONY: build
build: 
	aptos move compile --package-dir ./ --named-addresses liquidToken=0xCAFE

.PHONY: test
test: 
	aptos move test --package-dir ./ --named-addresses liquidToken=0xCAFE