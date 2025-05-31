# Access Control List

The next step is to allow trading bots to operate on users' `BalanceManager`. This requires careful attention to permission management. Given the nature of PTB (Programmable Transaction Block), the proxy trading address can potentially withdraw users' assets at intermediate stages. Therefore, we must restrict this capability to only those addresses we trust, ensuring that only these trusted addresses can deposit, withdraw assets, and conduct trades on behalf of users.

## Data Structure

Define the `AccessList` data structure for recording permitted trading addresses and the `AdminCap` for operating on `AccessList`. Since the whitelist addresses are usually few, using `VecSet` for recording is more convenient.

```move
use sui::{
    vec_set::{Self, VecSet}
};

const ENotWhitelisted: u64 = 1001;

public struct AccessList has key {
    id: UID,
    allow: VecSet<address>,
}

public struct AdminCap has key, store {
    id: UID,
}
```

## Init

Initialize the `AdminCap` and `AccessList` data structures. The `AdminCap` will be sent to the contract deployer when deploying the contract, serving as the administrator's authority, the `AccessList` will be shared as a `share_object`.

```move
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
}
```

## Permission Editing

Allow editing of the `AccessList` using the `AdminCap`.

```move
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
```

## Bot Operation Functions

Provide `bot_withdraw` and `bot_deposit` functions to be called by bots, which include the permission check `acl.allow.contains(&ctx.sender())`.

```move
const ESlippage: u64           = 1004;

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
```

In the `bot_deposit` function, there is also a `min` parameter, which can be used to check for slippage in the returned trade results.

For the actual contract code, you can refer to [vault.move](../example_projects/proxy/sources/vault.move).
