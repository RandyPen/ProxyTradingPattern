# Balance Manager

## Data Structure

`BalanceManager` is a data structure for users to store assets. Each user can have a unique `BalanceManager`, which can hold assets of any coins. For permission management, it records the `owner` info, allowing only the `owner` to deposit and withdraw assets.

```move
public struct BalanceManager has key {
    id: UID,
    owner: address,
}
```

## Create

To prevent a single address from creating multiple `BalanceManager` objects and causing account chaos, a global `Registry` is created first. This `Registry` stores the correspondence between each `address` and the `ID` of their `BalanceManager`.

```move
public struct Registry has key {
    id: UID,
    records: Table<address, ID>,
}
```
The corresponding `init` function is as follows:

```move
fun init(ctx: &mut TxContext) {
    let registry = Registry {
        id: object::new(ctx),
        records: table::new<address, ID>(ctx),
    };
    transfer::share_object(registry);
}
```

Function for creating `BalanceManager`:

```move
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
```

## Deposit & Withdraw

Since a single `BalanceManager` may store multiple types of `Coin`, `dynamic_field` and generic `T` are used.
When operating on `Coin<T>`, use `type_name::into_string` to read the name of the generic `T` as the Name for `dynamic_field`. Then get the reference to `Balance<T>` corresponding to the generic `T` and perform further operations.

```move
use std::{
    type_name,
    ascii::String
};
use sui::{
    coin::{Self, Coin},
    balance::Balance,
    dynamic_field
};

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
```

When users deposit or withdraw assets, permission checks are performed to ensure the `BalanceManager` belongs to them.

```move
public fun user_deposit<T>(
    bm: &mut BalanceManager,
    budget: Coin<T>,
    ctx: &TxContext,
) {
    assert!(bm.owner == ctx.sender(), ENotBMOwner);
    do_deposit<T>(bm, budget);
}

public fun user_withdraw<T>(
    bm: &mut BalanceManager,
    amount: u64,
    ctx: &mut TxContext,
): Coin<T> {
    assert!(bm.owner == ctx.sender(), ENotBMOwner);
    do_withdraw<T>(bm, amount, ctx)
}
```

## Other

### Query

To facilitate data retrieval, a `query` function interface for querying various `Balance<T>` is added.
```move
public fun query<T>(bm: &mut BalanceManager): u64 {
    let coin_type = key<T>();
    if (dynamic_field::exists_(&bm.id, coin_type)) {
        let balance_b = dynamic_field::borrow<_, Balance<T>>(&bm.id, coin_type);
        balance_b.value()
    } else {
        0
    }
}
```

### Version

For version control purposes:

```move
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

```move
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
```

For the actual contract code, you can refer to [vault.move](../example_projects/proxy/sources/vault.move).
