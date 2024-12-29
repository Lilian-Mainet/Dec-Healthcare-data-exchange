import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure that patient can store data and grant/revoke access",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const deployer = accounts.get('deployer')!;
        const patient = accounts.get('wallet_1')!;
        const provider = accounts.get('wallet_2')!;
        const dataHash = '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        let block = chain.mineBlock([
            Tx.contractCall('health-data-exchange', 'store-data', [types.buff(dataHash)], patient.address),
            Tx.contractCall('health-data-exchange', 'grant-access', [types.principal(provider.address)], patient.address),
            Tx.contractCall('health-data-exchange', 'check-access', [types.principal(patient.address), types.principal(provider.address)], provider.address),
        ]);

        assertEquals(block.receipts.length, 3);
        assertEquals(block.height, 2);
        assertEquals(block.receipts[0].result, '(ok true)');
        assertEquals(block.receipts[1].result, '(ok true)');
        assertEquals(block.receipts[2].result, 'true');

        block = chain.mineBlock([
            Tx.contractCall('health-data-exchange', 'revoke-access', [types.principal(provider.address)], patient.address),
            Tx.contractCall('health-data-exchange', 'check-access', [types.principal(patient.address), types.principal(provider.address)], provider.address),
        ]);

        assertEquals(block.receipts.length, 2);
        assertEquals(block.height, 3);
        assertEquals(block.receipts[0].result, '(ok true)');
        assertEquals(block.receipts[1].result, 'false');
    },
});

Clarinet.test({
    name: "Ensure that patient can share data with researchers",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const patient = accounts.get('wallet_1')!;
        const dataHash = '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        let block = chain.mineBlock([
            Tx.contractCall('health-data-exchange', 'store-data', [types.buff(dataHash)], patient.address),
            Tx.contractCall('health-data-exchange', 'share-with-researchers', [], patient.address),
        ]);

        assertEquals(block.receipts.length, 2);
        assertEquals(block.height, 2);
        assertEquals(block.receipts[0].result, '(ok true)');
        assertEquals(block.receipts[1].result, '(ok true)');
    },
});

Clarinet.test({
    name: "Ensure that patient data can be retrieved",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const patient = accounts.get('wallet_1')!;
        const provider = accounts.get('wallet_2')!;
        const dataHash = '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        let block = chain.mineBlock([
            Tx.contractCall('health-data-exchange', 'store-data', [types.buff(dataHash)], patient.address),
            Tx.contractCall('health-data-exchange', 'grant-access', [types.principal(provider.address)], patient.address),
            Tx.contractCall('health-data-exchange', 'get-patient-data', [types.principal(patient.address)], provider.address),
        ]);

        assertEquals(block.receipts.length, 3);
        assertEquals(block.height, 2);
        assertEquals(block.receipts[0].result, '(ok true)');
        assertEquals(block.receipts[1].result, '(ok true)');
        assertEquals(block.receipts[2].result, `(ok ${dataHash})`);
    },
});

Clarinet.test({
    name: "Ensure that unauthorized access is prevented",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const patient = accounts.get('wallet_1')!;
        const unauthorizedProvider = accounts.get('wallet_2')!;
        const dataHash = '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        let block = chain.mineBlock([
            Tx.contractCall('health-data-exchange', 'store-data', [types.buff(dataHash)], patient.address),
            Tx.contractCall('health-data-exchange', 'get-patient-data', [types.principal(patient.address)], unauthorizedProvider.address),
        ]);

        assertEquals(block.receipts.length, 2);
        assertEquals(block.height, 2);
        assertEquals(block.receipts[0].result, '(ok true)');
        assertEquals(block.receipts[1].result, '(err u101)'); // err-not-found
    },
});