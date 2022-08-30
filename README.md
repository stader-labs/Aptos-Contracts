# aptos-liquid-token

# How to build:

    * make build

# How to test:

    * make test

# Current flow:

1. Stader initialize aptosXCoin
2. User stake Aptoscoin => stader mint AptosX
3. User unstake => user burn AptosX, stader transfer back AptosCoins

# Devnet deployment:

1. Generate an account
2. Setup aptos-cli to newly generate account
3. Change `Mod` variable in Makefile to public address of new account
4. `make publish`

## Devnet module:

https://explorer.devnet.aptos.dev/account/0x833781e93f9b2abf507a113d517290aed99befe1d450cbb15b73c65337292222
