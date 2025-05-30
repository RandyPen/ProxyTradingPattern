import { AggregatorClient, Env } from "@cetusprotocol/aggregator-sdk"
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Transaction } from "@mysten/sui/transactions";
import { normalizeSuiAddress, normalizeSuiObjectId } from '@mysten/sui/utils';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { bcs } from '@mysten/sui/bcs';
import BN from 'bn.js';

const botMnemonics: string = process.env.BOT_MNEMONICS!;
const keypair = Ed25519Keypair.deriveKeypair(botMnemonics);
const botAddress = keypair.getPublicKey().toSuiAddress();
const feeAddress = normalizeSuiAddress("");

const suiClient = new SuiClient({
    url: getFullnodeUrl("mainnet"),
});

const accessListId = normalizeSuiObjectId("");
const balanceManagerId = normalizeSuiObjectId("");

const SUIType = "0x2::sui::SUI";
const USDCType = "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC";
const inAmount: number = 100_000_000;

try {
    const client = new AggregatorClient({
        signer: botAddress,
        client: suiClient,
        env: Env.Mainnet,
        overlayFeeRate: 0.01, 
        overlayFeeReceiver: feeAddress,
    })

    const amount = new BN(inAmount);

    const routers = await client.findRouters({
        from: USDCType,
        target: SUIType,
        amount,
        byAmountIn: true,
    })

    if (!routers) {
        process.exit(0)
    }
    
    const tx = new Transaction()
    const [coin] = tx.moveCall({
        package: process.env.PACKAGE!,
        module: "vault",
        function: "bot_withdraw",
        arguments: [
            tx.object(accessListId),
            tx.object(balanceManagerId),
            tx.pure(bcs.u64().serialize(inAmount).toBytes()),
        ],
        typeArguments: [
            USDCType,
        ],
    });
    const targetCoin = await client.routerSwap({
        routers,
        txb: tx,
        inputCoin: coin!,
        slippage: 0.01,
    });
    tx.moveCall({
        package: process.env.PACKAGE!,
        module: "vault",
        function: "bot_deposit",
        arguments: [
            tx.object(accessListId),
            tx.object(balanceManagerId),
            targetCoin,
            tx.pure(bcs.u64().serialize(0).toBytes()),
        ],
        typeArguments: [
            SUIType,
        ],
    });
    tx.setSender(botAddress);
    tx.setGasBudgetIfNotSet(100_000_000);
    const dataSentToFullnode = await tx.build({ client: suiClient });
    const dryrun_result = await suiClient.dryRunTransactionBlock({
        transactionBlock: dataSentToFullnode,
    });
    console.log(dryrun_result.balanceChanges);

    const result = await suiClient.signAndExecuteTransaction({ signer: keypair, transaction: tx });
    console.log("result", result);
} catch (error) {
    console.log(JSON.stringify(error, null, 2))
}
