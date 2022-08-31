module aptosx::token_mint {
    use std::string;
    use std::error;
    use std::signer;
    use std::simple_map;
    use std::option;

    use aptos_framework::aptos_coin::{Self};
    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};

    const EINVALID_BALANCE: u64 = 0;
    const EACCOUNT_DOESNT_EXIST: u64 = 1;
    const ENO_CAPABILITIES: u64 = 2;
    const ENOT_APTOSX_ADDRESS: u64 = 3;


    const STAKE_VAULT_SEED: vector<u8> = b"aptosx::token_mint::stake_vault";
    use aptos_framework::account;

    // every user stake have this resource
    struct UserStakeInfo has key {
        amount: u64,
    }

    // One stake vault for all user, used for recieve Aptoscoin
    struct StakeVault has key {
        resource_addr: address,
        signer_cap: account::SignerCapability
    }

    struct ValidatorSet has key {
        validators: simple_map::SimpleMap<address, bool>,
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
        decimals: u8,
    ) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosXCoin>(
            account,
            string::utf8(b"AptosX Liquid Token"),
            string::utf8(b"APTX"),
            decimals,
            true,
        );

        move_to(account, ValidatorSet {
            validators: simple_map::create<address, bool>(),
        });


        move_to(account, Capabilities {
            burn_cap,
            freeze_cap,
            mint_cap,
        });

        // Create stake_vault resource
        let (stake_vault, signer_cap) = account::create_resource_account(account, STAKE_VAULT_SEED);
        let resource_addr = signer::address_of(&stake_vault);
        coin::register<aptos_coin::AptosCoin>(&stake_vault);
        let stake_info = StakeVault {
            resource_addr, 
            signer_cap
        };
        move_to<StakeVault>(account, stake_info);
    }

    public fun is_aptosx_address(addr: address): bool {
        addr == @aptosx
    }

    public entry fun add_validator(account: &signer, validator_address: address) acquires ValidatorSet {
        assert!(
            is_aptosx_address(signer::address_of(account)),
            error::permission_denied(ENOT_APTOSX_ADDRESS),
        );

        let validator_set = borrow_global_mut<ValidatorSet>(@aptosx);
        simple_map::add(&mut validator_set.validators, validator_address, true);
    }

        public entry fun remove_validator(account: &signer, validator_address: address) acquires ValidatorSet {
        assert!(
            is_aptosx_address(signer::address_of(account)),
            error::permission_denied(ENOT_APTOSX_ADDRESS),
        );
        let validator_set = borrow_global_mut<ValidatorSet>(@aptosx);

        simple_map::remove(&mut validator_set.validators, &validator_address );
    }

    public entry fun deposit(staker: &signer, amount: u64) acquires UserStakeInfo, Capabilities, StakeVault {
        let staker_addr = signer::address_of(staker);

        
        if (!exists<UserStakeInfo>(staker_addr)) {
            let stake_info = UserStakeInfo {
                amount: 0, 
            };
            move_to<UserStakeInfo>(staker, stake_info);
        };

        let resource_addr = borrow_global<StakeVault>(@aptosx).resource_addr;

        if (!coin::is_account_registered<AptosXCoin>(staker_addr)) {
            coin::register<AptosXCoin>(staker);
        };

        // Transfer AptosCoin to vault
        let stake_info = borrow_global_mut<UserStakeInfo>(staker_addr);
        coin::transfer<aptos_coin::AptosCoin>(staker, resource_addr, amount);
        stake_info.amount = stake_info.amount + amount;


        // Mint Aptosx
        let mod_account = @aptosx;
        assert!(
            exists<Capabilities>(mod_account),
            error::not_found(ENO_CAPABILITIES),
        );
        let capabilities = borrow_global<Capabilities>(mod_account);
        let coins_minted = coin::mint(amount, &capabilities.mint_cap);
        coin::deposit(staker_addr, coins_minted);
    }

    public entry fun withdraw(staker: &signer, amount: u64) acquires UserStakeInfo, Capabilities, StakeVault {
        let staker_addr = signer::address_of(staker);
        assert!(exists<UserStakeInfo>(staker_addr), EACCOUNT_DOESNT_EXIST);

        let stake_info = borrow_global_mut<UserStakeInfo>(staker_addr);
        assert!(stake_info.amount >= amount, EINVALID_BALANCE);
        
        stake_info.amount = stake_info.amount - amount;

        // Transfer AptosCoin to user from vault
        let vault = borrow_global<StakeVault>(@aptosx);
        let resource_account = account::create_signer_with_capability(&vault.signer_cap);
        coin::transfer<aptos_coin::AptosCoin>(&resource_account, staker_addr, amount);

        // Burn aptosx
        let coin = coin::withdraw<AptosXCoin>(staker, amount);
        let mod_account = @aptosx;
        assert!(
            exists<Capabilities>(mod_account),
            error::not_found(ENO_CAPABILITIES),
        );
        let capabilities = borrow_global<Capabilities>(mod_account);
        coin::burn<AptosXCoin>(coin, &capabilities.burn_cap);
    }

    //
    // Tests
    //
    #[test(staker = @0xa11ce, mod_account = @0xCAFE, core = @std)]
    public entry fun end_to_end_deposit(
        staker: signer,
        mod_account: signer,
        core: signer,
    ) acquires Capabilities, UserStakeInfo, StakeVault {
        let staker_addr = signer::address_of(&staker);
        account::create_account_for_test(staker_addr);

        initialize(
            &mod_account,
            10
        );
        assert!(coin::is_coin_initialized<AptosXCoin>(), 0);


        coin::register<aptos_coin::AptosCoin>(&staker);

        let amount = 100;
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(&core);
        coin::deposit(staker_addr, coin::mint(amount, &mint_cap));

        // Before deposit
        assert!(coin::balance<aptos_coin::AptosCoin>(staker_addr) == amount, 1);
        assert!(coin::is_account_registered<AptosXCoin>(staker_addr) == false, 3);

        deposit(&staker, amount);

        // After deposit
        assert!(coin::balance<aptos_coin::AptosCoin>(staker_addr) == 0, 5);
        assert!(coin::balance<AptosXCoin>(staker_addr) == amount, 6);
        assert!(coin::supply<AptosXCoin>() == option::some((amount as u128)), 7);


        withdraw(&staker, amount);

        // // After withdraw
        assert!(coin::balance<aptos_coin::AptosCoin>(staker_addr) == amount, 8);
        assert!(coin::balance<AptosXCoin>(staker_addr) == 0, 9);
        assert!(coin::supply<AptosXCoin>() == option::some(0), 10);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(staker = @0xa11ce, mod_account = @0xCAFE, validator_1 = @0x1001, validator_2 = @0x1002, validator_3 = @0x1003)]
    public entry fun validators(
        mod_account: signer,
        validator_1: address,
        validator_2: address,
        ) acquires ValidatorSet {
        initialize(
            &mod_account,
            10
        );

        add_validator(&mod_account, validator_1);
        add_validator(&mod_account, validator_2);
        remove_validator(&mod_account, validator_2);
    }


    #[test(mod_account = @0xCAFE, validator_1 = @0x1001)]
    #[expected_failure]
    public entry fun remove_validator_not_exist(
        mod_account: signer,
        validator_1: address,
        ) acquires ValidatorSet {
        initialize(
            &mod_account,
            10
        );

        remove_validator(&mod_account, validator_1);
    }


    #[test(mod_account = @0xCAFE, validator_1 = @0x1001)]
    #[expected_failure]
    public entry fun remove_validator_twice(
        mod_account: signer,
        validator_1: address,
        ) acquires ValidatorSet {
        initialize(
            &mod_account,
            10
        );
        add_validator(&mod_account, validator_1);
        remove_validator(&mod_account, validator_1);
        remove_validator(&mod_account, validator_1);
    }

}