module proxy::vault;

use std::ascii::String;
use std::type_name;
use sui::balance::Balance;
use sui::coin::{Self, Coin};
use sui::dynamic_field;
use sui::table::{Self, Table};
use sui::vec_set::{Self, VecSet};

const VERSION: u64 = 1;

const ENotWhitelisted: u64     = 1001;
const EVersionMismatched: u64  = 1002;
const ENotBMOwner: u64         = 1003;
const ESlippage: u64           = 1004;

public struct AccessList has key {
    id: UID,
    allow: VecSet<address>,
}

public struct Registry has key {
    id: UID,
    records: Table<address, ID>,
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

    let registry = Registry {
        id: object::new(ctx),
        records: table::new<address, ID>(ctx),
    };
    transfer::share_object(registry);

    let version = Version {
        id: object::new(ctx),
        version: VERSION,
    };
    transfer::share_object(version);
}

public fun acl_add(acl: &mut AccessList, _: &AdminCap, bot_address: address) {
    acl.allow.insert(bot_address);
}

public fun acl_remove(acl: &mut AccessList, _: &AdminCap, bot_address: address) {
    acl.allow.remove(&bot_address);
}

public fun create_balance_manager(
    r: &mut Registry,
    version: &Version,
    ctx: &mut TxContext,
): BalanceManager {
    assert!(version.version == VERSION, EVersionMismatched);
    let balance_manager = BalanceManager {
        id: object::new(ctx),
        owner: ctx.sender(),
    };
    r.records.add(ctx.sender(), object::id(&balance_manager));
    balance_manager
}

public fun share_balance_manager(
    bm: BalanceManager
) {
    transfer::share_object(bm);
}

public fun user_deposit<T>(
    bm: &mut BalanceManager,
    budget: Coin<T>,
    version: &Version,
    ctx: &TxContext,
) {
    assert!(version.version == VERSION, EVersionMismatched);
    assert!(bm.owner == ctx.sender(), ENotBMOwner);
    do_deposit<T>(bm, budget);
}

public fun user_withdraw<T>(
    bm: &mut BalanceManager,
    amount: u64,
    version: &Version,
    ctx: &mut TxContext,
): Coin<T> {
    assert!(version.version == VERSION, EVersionMismatched);
    assert!(bm.owner == ctx.sender(), ENotBMOwner);
    do_withdraw<T>(bm, amount, ctx)
}

public fun bot_withdraw<T>(
    acl: &AccessList,
    bm: &mut BalanceManager,
    amount: u64,
    ctx: &mut TxContext,
): Coin<T> {
    assert!(acl.allow.contains(&ctx.sender()), ENotWhitelisted);
    do_withdraw<T>(bm, amount, ctx)
}

public fun bot_deposit<T>(
    acl: &AccessList,
    bm: &mut BalanceManager,
    budget: Coin<T>,
    min: u64,
    ctx: &TxContext,
) {
    assert!(acl.allow.contains(&ctx.sender()), ENotWhitelisted);
    assert!(budget.value() >= min, ESlippage);
    do_deposit<T>(bm, budget);
}

fun do_withdraw<T>(bm: &mut BalanceManager, amount: u64, ctx: &mut TxContext): Coin<T> {
    let coin_type = key<T>();
    let balance_bm = dynamic_field::borrow_mut<_, Balance<T>>(&mut bm.id, coin_type);
    let balance = if (balance_bm.value() == amount) {
        dynamic_field::remove<_, Balance<T>>(&mut bm.id, coin_type)
    } else {
        balance_bm.split(amount)
    };
    balance.into_coin(ctx)
}

fun do_deposit<T>(bm: &mut BalanceManager, budget: Coin<T>) {
    let coin_type = key<T>();
    if (dynamic_field::exists_(&bm.id, coin_type)) {
        let balance_bm = dynamic_field::borrow_mut<_, Balance<T>>(&mut bm.id, coin_type);
        coin::put<T>(balance_bm, budget);
    } else {
        let balance_t = budget.into_balance();
        dynamic_field::add<_, Balance<T>>(&mut bm.id, coin_type, balance_t);
    };
}

fun key<T>(): String {
   type_name::into_string(type_name::get_with_original_ids<T>())
}

public fun query<T>(bm: &mut BalanceManager): u64 {
    let coin_type = key<T>();
    if (dynamic_field::exists_(&bm.id, coin_type)) {
        let balance_b = dynamic_field::borrow<_, Balance<T>>(&bm.id, coin_type);
        balance_b.value()
    } else {
        0
    }
}

public fun update_version(version: &mut Version) {
    version.version == VERSION;
}
