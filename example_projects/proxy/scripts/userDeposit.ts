import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Transaction, coinWithBalance } from "@mysten/sui/transactions";
import { normalizeSuiObjectId } from '@mysten/sui/utils';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

const mnemonics: string = process.env.MNEMONICS!;
const keypair = Ed25519Keypair.deriveKeypair(mnemonics);
const address = keypair.getPublicKey().toSuiAddress();

const suiClient = new SuiClient({
    url: getFullnodeUrl("mainnet"),
});

const balanceManagerId = normalizeSuiObjectId("");
const versionId = normalizeSuiObjectId("");
const depositAmount: number = 1_000_000_000;
const coinType = "0x2::sui::SUI";

const tx = new Transaction();
tx.moveCall({
    package: process.env.PACKAGE!,
    module: "vault",
    function: "user_deposit",
    arguments: [
        tx.object(balanceManagerId),
        coinWithBalance({ type: coinType, balance: depositAmount }),
        tx.object(versionId),
    ],
    typeArguments: [
        coinType
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