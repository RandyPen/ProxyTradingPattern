import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Transaction } from "@mysten/sui/transactions";
import { normalizeSuiAddress } from '@mysten/sui/utils';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { bcs } from '@mysten/sui/bcs';

const mnemonics: string = process.env.MNEMONICS!;
const keypair = Ed25519Keypair.deriveKeypair(mnemonics);
const address = keypair.getPublicKey().toSuiAddress();

const client = new SuiClient({
    url: getFullnodeUrl("mainnet"),
});

const coinTypes: string[] = [
    "0x2::sui::SUI",
    "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC",
];

const balanceManagerId: string = "";

for (const CoinType of coinTypes) {
    console.log(CoinType);
    const tx = new Transaction();
    tx.moveCall({
        package: process.env.PACKAGE!,
        module: "vault",
        function: "query",
        arguments: [
            tx.object(balanceManagerId),
        ],
        typeArguments: [CoinType],
    });
    const res = await client.devInspectTransactionBlock({
        sender: normalizeSuiAddress(address),
        transactionBlock: tx,
    });
    const value = bcs.u64().parse(new Uint8Array(res?.results?.[0]?.returnValues?.[0]?.[0]!));
    console.log(value);
}