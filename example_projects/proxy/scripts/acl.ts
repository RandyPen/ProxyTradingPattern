import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Transaction } from "@mysten/sui/transactions";
import { normalizeSuiAddress } from '@mysten/sui/utils';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { bcs } from '@mysten/sui/bcs';

const mnemonics: string = process.env.MNEMONICS!;
const keypair = Ed25519Keypair.deriveKeypair(mnemonics);
const address = keypair.getPublicKey().toSuiAddress();

const suiClient = new SuiClient({
    url: getFullnodeUrl("mainnet"),
});

const adminCapId = normalizeSuiAddress("");
const accessListId = normalizeSuiAddress("");
const botAddress = normalizeSuiAddress("");

const tx = new Transaction();
tx.moveCall({
    package: process.env.PACKAGE!,
    module: "vault",
    function: "create_balance_manager",
    arguments: [
        tx.object(adminCapId),
        tx.object(accessListId),
        tx.pure(bcs.Address.serialize(botAddress).toBytes()),
    ],
});
tx.setSender(address);
tx.setGasBudgetIfNotSet(100_000_000);
const dataSentToFullnode = await tx.build({ client: suiClient });
const dryrun_result = await suiClient.dryRunTransactionBlock({
    transactionBlock: dataSentToFullnode,
});
console.log(dryrun_result.balanceChanges);

const result = await suiClient.signAndExecuteTransaction({ signer: keypair, transaction: tx });
console.log("result", result);