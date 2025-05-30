# Balance Manager

## Data Structure

`BalanceManager` is a data structure for users to store assets. Each user can have a unique `BalanceManager`, which can hold assets of any coins. For permission management, it records the `owner` info, allowing only the `owner` to deposit and withdraw assets.

```rust
public struct BalanceManager has key {
    id: UID,
    owner: address,
}
```

## Create

To prevent a single address from creating multiple `BalanceManager` objects and causing account chaos, a global `Record` is created first. This `Record` stores the correspondence between each `address` and the `ID` of their `BalanceManager`.

```rust
public struct Record has key {
    id: UID,
    record: Table<address, ID>,
}
```
The corresponding `init` function is as follows:

```rust
fun init(ctx: &mut TxContext) {
    let record = Record {
        id: object::new(ctx),
        record: table::new<address, ID>(ctx),
    };
    transfer::share_object(record);
}
```

Function for creating `BalanceManager`:

```rust
public fun create_balance_manager_non_entry(
    r: &mut Record,
    ctx: &mut TxContext,
): BalanceManager {
    let balance_manager = BalanceManager {
        id: object::new(ctx),
        owner: ctx.sender(),
    };
    r.record.add(ctx.sender(), object::id(&balance_manager));
    balance_manager
}

public fun create_balance_manager(
    r: &mut Record,
    ctx: &mut TxContext,
) {
    let balance_manager = create_balance_manager_non_entry(
        r,
        ctx
    );
    transfer::share_object(balance_manager);
}
```

## Deposit & Withdraw

Since a single `BalanceManager` may store multiple types of `Coin`, `dynamic_field` and generic `T` are used.
When operating on `Coin<T>`, use `type_name::into_string` to read the name of the generic `T` as the Name for `dynamic_field`. Then get the reference to `Balance<T>` corresponding to the generic `T` and perform further operations.

```rust
use std::{
    type_name,
    ascii::String
};
use sui::{
    coin::{Self, Coin},
    balance::{Self, Balance},
    dynamic_field
};

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
```

When users deposit or withdraw assets, permission checks are performed to ensure the `BalanceManager` belongs to them.

```rust
public fun user_deposit<T>(
    bm: &mut BalanceManager,
    budget: Coin<T>,
    ctx: &TxContext,
) {
    assert!(bm.owner == ctx.sender());
    deposit_non_entry<T>(bm, budget);
}

#[allow(lint(self_transfer))]
public fun user_withdraw<T>(
    bm: &mut BalanceManager,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert!(bm.owner == ctx.sender());
    let coin = withdraw_non_entry<T>(bm, amount, ctx);
    transfer::public_transfer(coin, ctx.sender());
}
```

## Other

### Query

To facilitate data retrieval, a `query` function interface for querying various `Balance<T>` is added.
```rust
public fun query<T>(bm: &mut BalanceManager): u64 {
    let coin_type = type_name::into_string(type_name::get_with_original_ids<T>());
    if (dynamic_field::exists_(&bm.id, coin_type)) {
        let balance_b = dynamic_field::borrow<String, Balance<T>>(&bm.id, coin_type);
        balance::value<T>(balance_b)
    } else {
        0
    }
}
```

### Version

For version control purposes:

```rust
const VERSION: u64 = 1;

const EVersionMismatched: u64 = 1002;

fun init(ctx: &mut TxContext) {
    let version = Version {
        id: object::new(ctx),
        version: VERSION,
    };
    transfer::share_object(version);
}
```

Add version checks to the functions:

```rust
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
```

For the actual contract code, you can refer to [vault.move](../example_projects/proxy/sources/vault.move).
