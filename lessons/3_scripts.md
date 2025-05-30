# Scripts

This section provides some example TypeScript code to demonstrate how to call the contract functions.  

First, you need to publish the contract and record the Object IDs of `Package`, `Record`, `AccessList`, `AdminCap`, etc., which will be used as input parameters for the function calls.

## Create Balance Manager

The TypeScript function used by users to create a `BalanceManager` for the first time. You can refer to [createBM.ts](../example_projects/proxy/scripts/createBM.ts).

## User Deposit

The TypeScript function used by users to deposit assets into a `BalanceManager`. You can refer to [userDeposit.ts](../example_projects/proxy/scripts/userDeposit.ts).

## ACL

The TypeScript function used by administrators to add bot whitelist addresses to the `AccessList`. You can refer to [acl.ts](../example_projects/proxy/scripts/acl.ts).

## Bot Trade

The TypeScript function used by bots on the whitelist to execute trades on behalf of users. You can refer to [botTrade.ts](../example_projects/proxy/scripts/botTrade.ts).   
The specific execution logic is usually stored on the server and triggered when conditions are met.

The `feeAddress` can be filled with the project's revenue address, which is used to receive the service fees from proxy user trades. This fee is deducted from the user's trade results as an overlay fee and is directly sent to the project's revenue address.     
`overlayFeeRate: 0.01` means a charge of `1%`; if no fee is to be charged, it can be set to `0`.    
For more parameter descriptions, you can refer to the [documentation](https://cetus-1.gitbook.io/cetus-developer-docs/developer/cetus-aggregator/features-available).

## Query

[query.ts](../example_projects/proxy/scripts/query.ts) demonstrates how to query the data of various assets in each `BalanceManager`.