import {beforeEach, it, expect} from 'vitest';
import {rewardCatalogCommand} from '../src/modules/gamification/reward-catalog-service';
import {seed, org, now, adminAuth, path} from './reward-journey-fixture';
let store: ReturnType<typeof seed>;
const run = (action: string, fields = {}) => rewardCatalogCommand(store, adminAuth, {schemaVersion: 1, organizationId: org, action, ...fields}, () => now);
const input = {requestId: 'create', itemId: 'new', baseItemRevision: 0, title: 'Training towel', description: 'Soft towel', category: 'Merchandise', imageUrl: '', pointCost: 100, valueMinor: 100, stockToAdd: 10, validityDays: 10, conditions: 'Collect in person', collectionInstructions: 'Reception'};
beforeEach(async () => {store = seed(); await run('configure', {requestId: 'setup', pointsPerUnit: 100, unitValueMinor: 100, enabled: true});});
it('creates information and redeemable inventory in one transaction without a draft', async () => {
  await run('save', input);
  expect(store.documents.get(path('rewardItems', 'new'))).toMatchObject({title: 'Training towel', description: 'Soft towel', active: true, stock: 10, revision: 1});
  expect(store.documents.has(path('rewardCatalog', 'new'))).toBe(false);
  expect((await run('overview')).items!.find(i => i.itemId === 'new')).toMatchObject({category: 'Merchandise', title: 'Training towel'});
});
it('retries create/edit idempotently, preserves concurrent stock debits and rejects stale metadata', async () => {
  await Promise.all([run('save', input), run('save', input)]);
  store.documents.set(path('rewardItems', 'new'), {...store.documents.get(path('rewardItems', 'new')), stock: 8});
  await run('save', {...input, requestId: 'edit', baseItemRevision: 1, title: 'Updated towel', stockToAdd: 2});
  expect(store.documents.get(path('rewardItems', 'new'))).toMatchObject({title: 'Updated towel', stock: 10, revision: 2});
  await expect(run('save', {...input, requestId: 'stale', baseItemRevision: 1})).rejects.toMatchObject({code: 'aborted'});
});
it('invalid information or conversion cannot leave a partial reward or operation', async () => {
  const before = JSON.stringify([...store.documents]);
  for (const change of [{title: ''}, {imageUrl: 'http://bad'}, {category: 'invalid'}, {pointCost: 101}, {conditions: ''}]) await expect(run('save', {...input, ...change})).rejects.toBeDefined();
  expect(JSON.stringify([...store.documents])).toBe(before);
});
it('Member and stale canonical authority cannot bypass direct-save validation', async () => {
  await expect(rewardCatalogCommand(store, {...adminAuth, uid: 'member'}, {schemaVersion: 1, organizationId: org, action: 'save', ...input}, () => now)).rejects.toMatchObject({code: 'permission-denied'});
  store.documents.set('users/admin', {organizationId: 'other'});
  await expect(run('save', input)).rejects.toMatchObject({code: 'permission-denied'});
  expect(store.documents.has(path('rewardItems', 'new'))).toBe(false);
});
it('remove and restore are one-step changes that preserve voucher history and existing stock', async () => {
  await run('save', input);
  store.documents.set(path('rewardRedemptions', 'existing'), {sentinel: 'preserve'});
  await run('retire', {requestId: 'remove', itemId: 'new', baseItemRevision: 1});
  await run('save', {...input, requestId: 'restore', baseItemRevision: 2, stockToAdd: 0});
  expect(store.documents.get(path('rewardItems', 'new'))).toMatchObject({active: true, stock: 10, revision: 3});
  expect(store.documents.get(path('rewardRedemptions', 'existing'))).toEqual({sentinel: 'preserve'});
});
