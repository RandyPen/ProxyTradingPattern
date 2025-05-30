import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Transaction } from "@mysten/sui/transactions";
import { normalizeSuiAddress } from '@mysten/sui/utils';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

const mnemonics: string = process.env.MNEMONICS!;
const keypair = Ed25519Keypair.deriveKeypair(mnemonics);
const address = keypair.getPublicKey().toSuiAddress();

const suiClient = new SuiClient({
    url: getFullnodeUrl("mainnet"),
});

const recordId = normalizeSuiAddress("");
const versionId = normalizeSuiAddress("");

const tx = new Transaction();
tx.moveCall({
    package: process.env.PACKAGE!,
    module: "vault",
    function: "acl_add",
    arguments: [
        tx.object(recordId),
        tx.object(versionId),
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