import {beforeEach, it, expect} from 'vitest';
import {rewardCatalogCommand} from '../src/modules/gamification/reward-catalog-service';
import {seed, org, now, adminAuth, auth, path} from './reward-journey-fixture';
let store: ReturnType<typeof seed>;
const run = (action: string, fields = {}, who = adminAuth) => rewardCatalogCommand(store, who, {schemaVersion: 1, organizationId: org, action, ...fields}, () => now);
const publish = (extra = {}) => run('publish', {requestId: 'publish', itemId: 'item', draftRevision: 1, baseItemRevision: 0, pointCost: 100, valueMinor: 100, stockToAdd: 2, validityDays: 2, conditions: 'Collect in person', collectionInstructions: 'Reception', ...extra});
beforeEach(() => {store = seed();});
it('no policy or rate is invented before explicit Admin setup; setup enables no earning sources or bonus', async () => {
  expect((await run('overview')).policy).toBeNull(); await expect(publish()).rejects.toBeDefined();
  await run('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true});
  expect(store.documents.get(path('rewardPolicies', 'current'))).toMatchObject({sources: [], enabled: true});
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1000);
});
it('publisher requires canonical Admin, exact saved draft revision, valid uniform conversion and explicit values', async () => {
  await expect(run('configure', {requestId: 'setup', pointsPerUnit: 1, unitValueMinor: 100, enabled: true}, auth)).rejects.toMatchObject({code: 'permission-denied'});
  await run('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true});
  await expect(publish({draftRevision: 2})).rejects.toBeDefined(); await expect(publish({pointCost: 101})).rejects.toBeDefined(); await expect(publish({validityDays: 0})).rejects.toBeDefined();
  await publish(); expect(store.documents.get(path('rewardItems', 'item'))).toMatchObject({stock: 2, premiumOnly: false, rewardDetailsVersion: 1});
});
it('publishing/restocking retries are idempotent and add to current stock instead of resetting concurrent debits', async () => {
  await run('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true});
  await Promise.all([publish(), publish()]); expect(store.documents.get(path('rewardItems', 'item'))?.stock).toBe(2);
  store.documents.set(path('rewardItems', 'item'), {...store.documents.get(path('rewardItems', 'item')), stock: 1});
  await publish({requestId: 'restock', baseItemRevision: 1, stockToAdd: 3}); expect(store.documents.get(path('rewardItems', 'item'))?.stock).toBe(4);
  await expect(publish({stockToAdd: 5})).rejects.toMatchObject({code: 'already-exists'});
});
it('retirement preserves issued-history data and rate changes require retiring active catalog', async () => {
  await run('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true}); await publish();
  await expect(run('configure', {requestId: 'change', pointsPerUnit: 200, unitValueMinor: 100, enabled: true})).rejects.toBeDefined();
  await run('retire', {requestId: 'retire', itemId: 'item', baseItemRevision: 1});
  expect(store.documents.get(path('rewardItems', 'item'))?.active).toBe(false);
  await run('configure', {requestId: 'change', pointsPerUnit: 200, unitValueMinor: 100, enabled: true});
});
it('shop disable/re-enable preserves conversion and item prices without touching balances', async () => {
  await run('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true}); await publish();
  const item = store.documents.get(path('rewardItems', 'item'))!, balance = store.documents.get(path('rewardBalances', 'member'))!;
  await run('configure', {requestId: 'pause', pointsPerUnit: 100, unitValueMinor: 100, enabled: false});
  expect(store.documents.get(path('rewardPolicies', 'current'))?.exchangeRate).toMatchObject({version: item.exchangeRateVersion});
  await run('configure', {requestId: 'resume', pointsPerUnit: 100, unitValueMinor: 100, enabled: true});
  expect(store.documents.get(path('rewardItems', 'item'))).toEqual(item); expect(store.documents.get(path('rewardBalances', 'member'))).toEqual(balance);
});
it('foreign/inactive canonical Admin or unreviewed earning rules cannot be configured', async () => {
  store.documents.set('users/admin', {organizationId: 'gainpath', role: 'member'});
  await expect(run('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true})).rejects.toMatchObject({code: 'permission-denied'});
  store.documents.set('users/admin', {organizationId: 'gainpath'});
  await run('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true});
  const p = store.documents.get(path('rewardPolicies', 'current'))!;
  store.documents.set(path('rewardPolicies', 'current'), {...p, sources: [{sourceId: 'held', producerVersion: 'v1', basePoints: 1, maxEventAgeMillis: 1000, dailyEvents: 1, dailyAwardPoints: 1}]});
  await expect(run('configure', {requestId: 'change', pointsPerUnit: 100, unitValueMinor: 100, enabled: true})).rejects.toMatchObject({code: 'failed-precondition'});
});
it('unsafe details, unknown earning inputs and reused request IDs cannot publish stock', async () => {
  await run('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true});
  await expect(publish({pointsToAward: 999})).rejects.toBeDefined(); await expect(publish({conditions: ''})).rejects.toBeDefined();
  store.documents.set(path('rewardCatalog', 'item'), {...store.documents.get(path('rewardCatalog', 'item')), imageUrl: 'http://invalid'});
  await expect(publish()).rejects.toBeDefined(); expect(store.documents.has(path('rewardItems', 'item'))).toBe(false);
});
