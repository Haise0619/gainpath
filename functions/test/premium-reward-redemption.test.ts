import { expect, it } from 'vitest';
import { rewardCatalogCommand } from '../src/modules/gamification/reward-catalog-service';
import { rewardsCommand } from '../src/modules/gamification/verified-rewards-service';
import { adminAuth, auth, identity, now, org, path, seed } from './reward-journey-fixture';

const scope = { schemaVersion: 1, organizationId: org };
const item = {
  itemId: 'fixture-reward', title: 'Training bottle', description: 'Reusable bottle', category: 'Merchandise', imageUrl: '',
  pointCost: 100, stockToAdd: 2, validityDays: 10, conditions: 'Collect in person', collectionInstructions: 'Reception',
};

function fixture() {
  const store = seed();
  const itemPath = path('rewardItems', item.itemId);
  const accountPath = path('membershipAccounts', auth.uid);
  const walletPath = path('rewardBalances', auth.uid);
  const publish = (premiumOnly: boolean, baseItemRevision = 0) => rewardCatalogCommand(store, adminAuth, {
    ...scope, action: 'savePoints', ...item, premiumOnly, baseItemRevision, requestId: `publish-${baseItemRevision}`,
    stockToAdd: baseItemRevision === 0 ? item.stockToAdd : 0,
  }, () => now);
  const command = (action: string, fields: object, at = now, uid = auth.uid, organizationId = org) => rewardsCommand(
    store, { ...auth, uid }, { ...scope, organizationId, action, ...fields }, identity, () => at,
  );
  const redemption = (requestId: string, expectedItemRevision = 1) => ({
    itemId: item.itemId, expectedItemRevision, expectedPointCost: item.pointCost, requestId,
  });
  return { store, itemPath, accountPath, walletPath, publish, command, redemption };
}

it('classifies a published reward for future redemption while preserving previous vouchers', async () => {
  const f = fixture();
  await f.publish(false);
  const previous = await f.command('redeem', f.redemption('original'));
  await f.publish(true, 1);
  await expect(f.command('redeem', f.redemption('stale'))).rejects.toMatchObject({ code: 'aborted' });
  await expect(f.command('redeem', f.redemption('basic', 2))).rejects.toMatchObject({ code: 'permission-denied' });
  expect(await f.command('redeem', f.redemption('original'))).toEqual(previous);

  const account = f.store.documents.get(f.accountPath)!;
  const transaction = f.store.documents.get(path('transactions', String(account.lastTransactionId)))!;
  account.planId = 'premium';
  transaction.planId = 'premium';
  const request = f.redemption('premium', 2);
  const [first, retry] = await Promise.all([f.command('redeem', request), f.command('redeem', request)]);
  expect(first).toMatchObject({ redemption: { points: item.pointCost, status: 'issued' } });
  expect(retry).toEqual(first);
  expect(f.store.documents.get(f.itemPath)).toMatchObject({ stock: 0, premiumOnly: true, revision: 2 });
  expect(f.store.documents.get(f.walletPath)?.points).toBe(800);

  const oldVoucher = { redemptionId: previous.redemption.redemptionId };
  const afterExpiry = Number(account.expiresAtMillis);
  await expect(f.command('redeem', f.redemption('expired', 2), afterExpiry)).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(f.command('voucher', oldVoucher, afterExpiry)).resolves.toMatchObject({ redemption: { ...oldVoucher } });
  await expect(f.command('voucher', oldVoucher, now, 'other')).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(f.command('voucher', oldVoucher, now, auth.uid, 'another-org')).rejects.toMatchObject({ code: 'permission-denied' });
});

it.each(['insufficient points', 'out of stock', 'unknown membership'])('denies %s without mutating a redemption record', async condition => {
  const f = fixture();
  await f.publish(false);
  if (condition === 'insufficient points') f.store.documents.get(f.walletPath)!.points = item.pointCost - 1;
  if (condition === 'out of stock') f.store.documents.get(f.itemPath)!.stock = 0;
  if (condition === 'unknown membership') f.store.documents.get(f.accountPath)!.lastTransactionId = 'missing';
  const before = structuredClone([...f.store.documents]);
  await expect(f.command('redeem', f.redemption('denied'))).rejects.toMatchObject({
    code: condition === 'unknown membership' ? 'permission-denied' : 'failed-precondition',
  });
  expect([...f.store.documents]).toEqual(before);
});
