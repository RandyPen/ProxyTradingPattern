module proxy::vault;


use std::{
    type_name,
    ascii::String
};
use sui::{
    coin::{Self, Coin},
    table::{Self, Table},
    balance::{Self, Balance},
    vec_set::{Self, VecSet},
    dynamic_field
};


const VERSION: u64 = 1;

const ENotWhitelisted: u64 = 1001;
const EVersionMismatched: u64 = 1002;

public struct AccessList has key {
    id: UID,
    allow: VecSet<address>,
}

public struct Record has key {
    id: UID,
    record: Table<address, ID>,
}

public struct BalanceManager has key {
    id: UID,
    owner: address,
}

public struct AdminCap has key, store {
    id: UID,
}

public struct Version has key {
    id: UID,
    version: u64,
}

fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    transfer::public_transfer(admin_cap, ctx.sender());

    let acl = AccessList {
        id: object::new(ctx),
        allow: vec_set::empty(),
    };
    transfer::share_object(acl);

    let record = Record {
        id: object::new(ctx),
        record: table::new<address, ID>(ctx),
    };
    transfer::share_object(record);

    let version = Version {
        id: object::new(ctx),
        version: VERSION,
    };
    transfer::share_object(version);
}

public fun acl_add(
    acl: &mut AccessList,
    _: &AdminCap,
    bot_address: address,
) {
    acl.allow.insert(bot_address);
}

public fun acl_remove(
    acl: &mut AccessList,
    _: &AdminCap,
    bot_address: address,
) {
    acl.allow.remove(&bot_address);
}

public fun create_balance_manager_non_entry(
    r: &mut Record,
    version: &Version,
    ctx: &mut TxContext,
): BalanceManager {
    assert!(version.version == VERSION, EVersionMismatched);
    let balance_manager = BalanceManager {
        id: object::new(ctx),
        owner: ctx.sender(),
    };
    r.record.add(ctx.sender(), object::id(&balance_manager));
    balance_manager
}

public fun create_balance_manager(
    r: &mut Record,
    version: &Version,
    ctx: &mut TxContext,
) {
    let balance_manager = create_balance_manager_non_entry(
        r,
        version,
        ctx
    );
    transfer::share_object(balance_manager);
}

public fun user_deposit<T>(
    bm: &mut BalanceManager,
    budget: Coin<T>,
    version: &Version,
    ctx: &TxContext,
) {
    assert!(version.version == VERSION, EVersionMismatched);
    assert!(bm.owner == ctx.sender());
    deposit_non_entry<T>(bm, budget);
}

entry fun user_withdraw<T>(
    bm: &mut BalanceManager,
    amount: u64,
    version: &Version,
    ctx: &mut TxContext,
) {
    assert!(version.version == VERSION, EVersionMismatched);
    assert!(bm.owner == ctx.sender());
    let coin = withdraw_non_entry<T>(bm, amount, ctx);
    transfer::public_transfer(coin, ctx.sender());
}

public fun bot_withdraw<T>(
    acl: &AccessList,
    bm: &mut BalanceManager,
    amount: u64,
    ctx: &mut TxContext,
): Coin<T> {
    assert!(acl.allow.contains(&ctx.sender()), ENotWhitelisted);
    withdraw_non_entry<T>(bm, amount, ctx)
}

public fun bot_deposit<T>(
    acl: &AccessList,
    bm: &mut BalanceManager,
    budget: Coin<T>,
    min: u64,
    ctx: &TxContext,
) {
    assert!(acl.allow.contains(&ctx.sender()), ENotWhitelisted);
    assert!(budget.value() >= min);
    deposit_non_entry<T>(bm, budget);
}

fun withdraw_non_entry<T>(
    bm: &mut BalanceManager,
    amount: u64,
    ctx: &mut TxContext,
): Coin<T> {
    let coin_type = type_name::into_string(type_name::get_with_original_ids<T>());
    let balance_bm = dynamic_field::borrow_mut<String, Balance<T>>(&mut bm.id, coin_type);
    let balance = if (balance::value<T>(balance_bm) == amount) {
        dynamic_field::remove<String, Balance<T>>(&mut bm.id, coin_type)
    } else {
        balance::split<T>(balance_bm, amount)
    };
    let coin = coin::from_balance<T>(balance, ctx);
    coin
}

fun deposit_non_entry<T>(
    bm: &mut BalanceManager,
    budget: Coin<T>,
) {
    let coin_type = type_name::into_string(type_name::get_with_original_ids<T>());
    if (dynamic_field::exists_(&bm.id, coin_type)) {
        let balance_bm = dynamic_field::borrow_mut<String, Balance<T>>(&mut bm.id, coin_type);
        coin::put<T>(balance_bm, budget);
    } else {
        let balance_t = coin::into_balance<T>(budget);
        dynamic_field::add<String, Balance<T>>(&mut bm.id, coin_type, balance_t);
    };
}

public fun query<T>(bm: &mut BalanceManager): u64 {
    let coin_type = type_name::into_string(type_name::get_with_original_ids<T>());
    if (dynamic_field::exists_(&bm.id, coin_type)) {
        let balance_b = dynamic_field::borrow<String, Balance<T>>(&bm.id, coin_type);
        balance::value<T>(balance_b)
    } else {
        0
    }
}

public fun update_version(
    version: &mut Version,
) {
    version.version == VERSION;
}

