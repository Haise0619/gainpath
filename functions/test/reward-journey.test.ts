import {beforeEach, it, expect} from 'vitest';
import {rewardsCommand, type RewardsHistoryReader} from '../src/modules/gamification/verified-rewards-service';
import {rewardCatalogCommand} from '../src/modules/gamification/reward-catalog-service';
import {seed, org, now, DAY, auth, adminAuth, identity, path} from './reward-journey-fixture';
let store: ReturnType<typeof seed>;
const admin = (action: string, fields = {}) => rewardCatalogCommand(store, adminAuth, {schemaVersion: 1, organizationId: org, action, ...fields}, () => now);
const reader: RewardsHistoryReader = {page: async (uid, after, limit) => [...store.documents].filter(([p, d]) => p.startsWith(`orgs/${org}/rewardRedemptions/`) && d.memberId === uid).map(([p, data]) => ({id: p.split('/').at(-1)!, data})).sort((a, b) => a.id.localeCompare(b.id)).filter(r => !after || r.id > after).slice(0, limit)};
const run = (action: string, fields = {}, at = now, who = auth) => rewardsCommand(store, who, {schemaVersion: 1, organizationId: org, action, ...(action === 'redeem' ? {expectedPointCost: 100, expectedItemRevision: 1} : {}), ...fields}, identity, () => at, reader);
beforeEach(async () => {
  store = seed();
  await admin('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true});
  await admin('publish', {requestId: 'publish', itemId: 'item', draftRevision: 1, baseItemRevision: 0, pointCost: 100, valueMinor: 100, stockToAdd: 2, validityDays: 2, conditions: 'One bottle; collect in person.', collectionInstructions: 'Show this voucher at reception.'});
});
it('Basic redemption snapshots complete details and remains in owner My Rewards', async () => {
  const r = (await run('redeem', {itemId: 'item', requestId: 'one'})).redemption;
  expect(r).toMatchObject({points: 100, description: 'A reusable training bottle', conditions: 'One bottle; collect in person.', expiresAtMillis: now + 2 * DAY, expiredPointsPolicy: 'remain_spent'});
  store.documents.set(path('rewardItems', 'item'), {...store.documents.get(path('rewardItems', 'item')), conditions: 'Edited for future vouchers'});
  expect((await run('voucher', {redemptionId: r.redemptionId})).redemption.conditions).toBe(r.conditions);
  expect((await run('history', {afterId: null})).redemptions).toHaveLength(1);
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(900);
});
it('expiry is exact, refuses collection, retains spent points and stock, and performs no expiry writes', async () => {
  const r = (await run('redeem', {itemId: 'item', requestId: 'one'})).redemption;
  expect((await run('voucher', {redemptionId: r.redemptionId}, now + 2 * DAY - 1)).redemption.status).toBe('issued');
  const before = JSON.stringify([...store.documents]);
  expect((await run('voucher', {redemptionId: r.redemptionId}, now + 2 * DAY)).redemption.status).toBe('expired');
  await expect(run('fulfil', {redemptionId: r.redemptionId}, now + 2 * DAY, adminAuth)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(JSON.stringify([...store.documents])).toBe(before); expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(900);
});
it('inspect does not collect; concurrent confirmation fulfils once and survives later membership/policy retirement', async () => {
  const r = (await run('redeem', {itemId: 'item', requestId: 'one'})).redemption;
  store.documents.delete(path('membershipAccounts', 'member')); store.documents.delete(path('rewardPolicies', 'current'));
  expect((await run('inspect', {redemptionId: r.redemptionId}, now + DAY, adminAuth)).redemption.status).toBe('issued');
  const rows = await Promise.all([run('fulfil', {redemptionId: r.redemptionId}, now + DAY, adminAuth), run('fulfil', {redemptionId: r.redemptionId}, now + DAY, adminAuth)]);
  expect(rows.every(x => x.redemption.status === 'fulfilled')).toBe(true);
  expect((await run('redeem', {itemId: 'item', requestId: 'one'}, now + DAY)).redemption.status).toBe('fulfilled');
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(900);
});
it('another Member cannot inspect owner voucher; history remains owner-bound', async () => {
  const r = (await run('redeem', {itemId: 'item', requestId: 'one'})).redemption;
  await expect(run('voucher', {redemptionId: r.redemptionId}, now, {...auth, uid: 'other'})).rejects.toBeDefined();
  expect((await run('history', {afterId: null}, now, {...auth, uid: 'other'})).redemptions).toEqual([]);
});
it('all issued vouchers are paged beyond the bounded recent index with no duplicates or other owners', async () => {
  const r = (await run('redeem', {itemId: 'item', requestId: 'one'})).redemption;
  for (let i = 0; i < 53; i++) {const id = 'v' + String(i).padStart(3, '0'); store.documents.set(path('rewardRedemptions', id), {...r, redemptionId: id, requestId: id});}
  const all: string[] = []; let afterId: string | null = null;
  do {const page = await run('history', {afterId}); all.push(...page.redemptions.map((x: any) => x.redemptionId)); afterId = page.nextCursor;} while (afterId);
  expect(all).toHaveLength(54); expect(new Set(all).size).toBe(54);
});
it('price consent is checked before a new debit if Admin reprices after a Member opens the reward', async () => {
  store.documents.set(path('rewardItems', 'item'), {...store.documents.get(path('rewardItems', 'item')), pointCost: 200, valueMinor: 200});
  await expect(run('redeem', {itemId: 'item', requestId: 'price', expectedPointCost: 100})).rejects.toMatchObject({code: 'aborted'});
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1000);
  expect((await run('redeem', {itemId: 'item', requestId: 'price', expectedPointCost: 200})).redemption.points).toBe(200);
});
it('same-price changed terms require a refreshed reviewed publication before spending points', async () => {
  const reviewed = (await run('overview')).items[0];
  await admin('publish', {requestId: 'change-terms', itemId: 'item', draftRevision: 1, baseItemRevision: 1, pointCost: 100, valueMinor: 100, stockToAdd: 0, validityDays: 1, conditions: 'Updated conditions', collectionInstructions: 'New collection desk'});
  await expect(run('redeem', {itemId: 'item', requestId: 'terms', expectedPointCost: reviewed.pointCost, expectedItemRevision: 1})).rejects.toMatchObject({code: 'aborted'});
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1000);
  expect((await run('redeem', {itemId: 'item', requestId: 'terms', expectedItemRevision: 2})).redemption.expiresAtMillis).toBe(now + DAY);
});
