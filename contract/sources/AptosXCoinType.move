module AptosXCoinType::aptosx_coin {
    use std::string;
    use std::error;
    use std::signer;

    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};
    use aptos_framework::coins;
    use aptos_framework::aptos_coin::AptosCoin;


    const ENO_CAPABILITIES: u64 = 1;

    //
    // Data structures
    //

    /// Capabilities resource storing mint and burn capabilities.
    /// The resource is stored on the account that initialized coin `CoinType`.
    struct Capabilities has key {
        burn_cap: BurnCapability<AptosXCoin>,
        freeze_cap: FreezeCapability<AptosXCoin>,
        mint_cap: MintCapability<AptosXCoin>,
    }

    struct AptosXCoin {}

    public entry fun initialize(
        account: &signer,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        monitor_supply: bool,
    ) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosXCoin>(
            account,
            string::utf8(name),
            string::utf8(symbol),
            decimals,
            monitor_supply,
        );

        move_to(account, Capabilities {
            burn_cap,
            freeze_cap,
            mint_cap,
        });
    }

    public entry fun deposit(
        user: &signer,
        amount: u64,
    ) acquires Capabilities {
        let user_addr = signer::address_of(user);

        let module_owner_addr = @AptosXCoinType;
        assert!(
            exists<Capabilities>(module_owner_addr),
            error::not_found(ENO_CAPABILITIES),
        );

        // Get AptosCoin
        coin::transfer<AptosCoin>(user, module_owner_addr, amount);
        

        // Mint Aptosx
        let capabilities = borrow_global<Capabilities>(module_owner_addr);
        let coins_minted = coin::mint(amount, &capabilities.mint_cap);
        coin::deposit(user_addr, coins_minted);
    }

    public entry fun register(account: &signer) {
        coins::register<AptosXCoin>(account);
    }
}