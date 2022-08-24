module aptosXCoinType::aptosx_coin {
    use std::string;
    use std::error;
    use std::signer;

    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};
    use aptos_framework::coins;
    use aptos_framework::aptos_coin::{Self};


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

        let mod_account = @aptosXCoinType;
        assert!(
            exists<Capabilities>(mod_account),
            error::not_found(ENO_CAPABILITIES),
        );

        // Get AptosCoin
        coin::transfer<aptos_coin::AptosCoin>(user, mod_account, amount);
        

        // Mint Aptosx
        let capabilities = borrow_global<Capabilities>(mod_account);
        let coins_minted = coin::mint(amount, &capabilities.mint_cap);
        coin::deposit(user_addr, coins_minted);
    }

    public entry fun register(account: &signer) {
        coins::register<AptosXCoin>(account);
    }

    //
    // Tests
    //
    #[test(source = @0xa11ce, mod_account = @0xCAFE, core = @std)]
    public entry fun test_end_to_end(
        source: signer,
        mod_account: signer,
        core: signer,
    ) acquires Capabilities {
        let source_addr = signer::address_of(&source);
        let mod_adr = signer::address_of(&mod_account);
        aptos_framework::account::create_account(source_addr);

        initialize(
            &mod_account,
            b"AptosX Liquid",
            b"APTX",
            10,
            true
        );
        assert!(coin::is_coin_initialized<AptosXCoin>(), 0);


        coin::register_for_test<AptosXCoin>(&mod_account);
        coin::register_for_test<aptos_coin::AptosCoin>(&mod_account);
        // TODO: understand why this not work
        // register<AptosXCoin>(&source); 
        coins::register<AptosXCoin>(&source);


        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(&core);
        coin::deposit(signer::address_of(&source), coin::mint(10, &mint_cap));

        // Before deposit
        assert!(coin::balance<aptos_coin::AptosCoin>(source_addr) == 10, 1);
        assert!(coin::balance<aptos_coin::AptosCoin>(mod_adr) == 0, 2);
        assert!(coin::balance<AptosXCoin>(source_addr) == 0, 3);

        deposit(&source, 10);

        // After deposit
        assert!(coin::balance<aptos_coin::AptosCoin>(mod_adr) == 10, 4);
        assert!(coin::balance<aptos_coin::AptosCoin>(source_addr) == 0, 5);
        assert!(coin::balance<AptosXCoin>(source_addr) == 10, 6);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}
