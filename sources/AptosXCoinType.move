module liquidToken::aptosx {
    use std::string;
    use std::error;
    use std::signer;

    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};
    use aptos_framework::coins;
    use aptos_framework::aptos_coin::{Self};

    const EINVALID_BALANCE: u64 = 0;
    const EACCOUNT_DOESNT_EXIST: u64 = 1;
    const ENO_CAPABILITIES: u64 = 3;


    use aptos_framework::account;
    struct StakeInfo has key, store, drop {
        amount: u64,
        staker_resource: address,
        signer_cap: account::SignerCapability
    }

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

    public entry fun stake(staker: &signer, amount: u64) acquires StakeInfo, Capabilities {
        let staker_addr = signer::address_of(staker);

        
        let staker_resource = if (!exists<StakeInfo>(staker_addr)) {
            let (resource, signer_cap) = account::create_resource_account(staker, x"01");
            let staker_resource = signer::address_of(&resource);
            coins::register<aptos_coin::AptosCoin>(&resource);
            let stake_info = StakeInfo {
                amount: 0, 
                staker_resource, 
                signer_cap
            };
            move_to<StakeInfo>(staker, stake_info);
            staker_resource
        } else {
            borrow_global<StakeInfo>(staker_addr).staker_resource
        };

        if (!coin::is_account_registered<AptosXCoin>(staker_addr)) {
            coins::register<AptosXCoin>(staker);
        };
        let stake_info = borrow_global_mut<StakeInfo>(staker_addr);
        coin::transfer<aptos_coin::AptosCoin>(staker, staker_resource, amount);
        stake_info.amount = stake_info.amount + amount;


        // Mint Aptosx
        let mod_account = @liquidToken;
        assert!(
            exists<Capabilities>(mod_account),
            error::not_found(ENO_CAPABILITIES),
        );
        let capabilities = borrow_global<Capabilities>(mod_account);
        let coins_minted = coin::mint(amount, &capabilities.mint_cap);
        coin::deposit(staker_addr, coins_minted);
    }

    public entry fun unstake(staker: &signer, amount: u64) acquires StakeInfo, Capabilities {
        let staker_addr = signer::address_of(staker);
        assert!(exists<StakeInfo>(staker_addr), EACCOUNT_DOESNT_EXIST);

        let stake_info = borrow_global_mut<StakeInfo>(staker_addr);

        // Transfer AptosCoin to user
        let resource_account = account::create_signer_with_capability(&stake_info.signer_cap);
        coin::transfer<aptos_coin::AptosCoin>(&resource_account, staker_addr, stake_info.amount);
        stake_info.amount = stake_info.amount - amount;


        // Burn aptosx
        let coin = coin::withdraw<AptosXCoin>(staker, amount);
        let mod_account = @liquidToken;
        assert!(
            exists<Capabilities>(mod_account),
            error::not_found(ENO_CAPABILITIES),
        );
        let capabilities = borrow_global<Capabilities>(mod_account);
        coin::burn<AptosXCoin>(coin, &capabilities.burn_cap);
    }

    public entry fun register(account: &signer) {
        coins::register<AptosXCoin>(account);
    }

    //
    // Tests
    //
    #[test(staker = @0xa11ce, mod_account = @0xCAFE, core = @std)]
    public entry fun test_end_to_end(
        staker: signer,
        mod_account: signer,
        core: signer,
    ) acquires Capabilities, StakeInfo {
        let staker_addr = signer::address_of(&staker);
        let mod_adr = signer::address_of(&mod_account);
        aptos_framework::account::create_account(staker_addr);

        initialize(
            &mod_account,
            b"AptosX Liquid",
            b"APTX",
            10,
            true
        );
        assert!(coin::is_coin_initialized<AptosXCoin>(), 0);


        coin::register_for_test<aptos_coin::AptosCoin>(&mod_account);

        let amount = 100;

        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(&core);
        coin::deposit(staker_addr, coin::mint(amount, &mint_cap));

        // Before deposit
        assert!(coin::balance<aptos_coin::AptosCoin>(staker_addr) == amount, 1);
        assert!(coin::balance<aptos_coin::AptosCoin>(mod_adr) == 0, 2);
        assert!(!coin::is_account_registered<AptosXCoin>(staker_addr), 3);

        stake(&staker, amount);

        // After deposit
        assert!(coin::balance<aptos_coin::AptosCoin>(staker_addr) == 0, 5);
        assert!(coin::balance<AptosXCoin>(staker_addr) == amount, 6);


        unstake(&staker, amount);

        // // After withdraw
        assert!(coin::balance<aptos_coin::AptosCoin>(staker_addr) == amount, 8);
        assert!(coin::balance<AptosXCoin>(staker_addr) == 0, coin::balance<AptosXCoin>(staker_addr) );

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}
