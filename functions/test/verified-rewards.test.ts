import { beforeEach, expect, it } from 'vitest';
import { rewardsCommand } from '../src/modules/gamification/verified-rewards-service';
import { MemoryStore } from './memory-store';
import { InputValidationError } from '../src/platform/validation';

const org = 'gainpath', uid = 'member', now = 1800000000000, day = 86400000;
const auth = { uid, token: { email_verified: true, auth_time: now / 1000 } };
const identity = async () => ({ exists: true, disabled: false, emailVerified: true });
let store: MemoryStore;
const path = (collection: string, id: string) => `orgs/${org}/${collection}/${id}`;
const command = (action: string, fields = {}, who = auth, at = now) => rewardsCommand(store, who,
  { schemaVersion: 1, organizationId: org, action, ...fields }, identity, () => at);
function member(id: string, role = 'member') {
  store.documents.set(`users/${id}`, { organizationId: org });
  store.documents.set(path('members', id), { organizationId: org, userId: id, role, status: 'active', branchIds: [] });
}
function payment(id = 'paid', planId = 'premium', start = now - day, end = now + 29 * day) {
  const p = { schemaVersion: 1, organizationId: org, memberId: uid, transactionId: id, kind: 'MembershipPurchase', planId,
    environment: 'sandbox', provider: 'billplz', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed', currency: 'MYR',
    billId: 'bill', collectionId: 'collection', amountMinor: 8900, durationDays: 30, planName: 'Configured', benefits: [],
    clearedAtMillis: start, expiresAtMillis: end };
  store.documents.set(path('transactions', id), p);
  store.documents.set(path('membershipAccounts', uid), { organizationId: org, memberId: uid, planId, lastTransactionId: id, expiresAtMillis: end });
}
function event(id = 'event', time = now - 1000) {
  store.documents.set(path('rewardEvents', id), { schemaVersion: 1, organizationId: org, memberId: uid, eventId: id,
    rewardPolicyVersion: 'synthetic-policy-v1',
    sourceId: 'test_only', producerVersion: 'synthetic-v1', verification: 'trusted', occurredAtMillis: time, recordedAtMillis: now,
    membershipTransactionId: 'paid' });
}
beforeEach(() => {
  store = new MemoryStore();
  store.documents.set(`orgs/${org}`, { status: 'active' }); member(uid); member('admin', 'admin');
  store.documents.set(path('rewardPolicies', 'current'), { schemaVersion: 1, version: 'synthetic-policy-v1', enabled: true,
    organizationId: org, effectiveFromMillis: now - 60 * day, effectiveUntilMillis: now + day, timezone: 'Asia/Kuala_Lumpur',
    unknownHistoricalTier: 'base_only', exchangeRate: { version: 'synthetic-rate', currency: 'MYR', pointsPerUnit: 5, unitValueMinor: 100 },
    itemIds: ['item'], sources: [{ sourceId: 'test_only', producerVersion: 'synthetic-v1', basePoints: 5,
      maxEventAgeMillis: 60 * day, dailyEvents: 2, dailyAwardPoints: 20 }] });
  store.documents.set(path('rewardItems', 'item'), { schemaVersion: 1, organizationId: org, itemId: 'item', title: 'Synthetic item',
    active: true, pointCost: 5, valueMinor: 100, stock: 1, premiumOnly: false, exchangeRateVersion: 'synthetic-rate' });
  event();
});
it('missing policy returns empty unavailable state without inventing or migrating a balance', async () => {
  store.documents.delete(path('rewardPolicies', 'current'));
  expect(await command('overview')).toMatchObject({ available: false, balance: null, items: [], redemptions: [] });
  await expect(command('award', { eventId: 'event' })).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(store.documents.has(path('rewardBalances', uid))).toBe(false);
});
it('Free can earn configured base points once even under duplicate concurrent awards', async () => {
  const results = await Promise.all([command('award', { eventId: 'event' }), command('award', { eventId: 'event' })]);
  expect(results.map(r => r.award)).toEqual([expect.objectContaining({ points: 5, premiumBonus: false }), expect.objectContaining({ points: 5 })]);
  expect(store.documents.get(path('rewardBalances', uid))?.points).toBe(5);
});
it('floors Premium multiplier using the immutable historical grant even after current expiry', async () => {
  payment('paid', 'premium', now - 40 * day, now - 10 * day); event('event', now - 20 * day);
  expect(await command('award', { eventId: 'event' })).toMatchObject({ award: { points: 7, premiumBonus: true, membershipTransactionId: 'paid' } });
  expect((await command('overview')).balance).toBe(7);
});
it.each(['missing', 'future_purchase', 'before_interval', 'at_expiry', 'wrong_owner', 'pending', 'reconciliation', 'wrong_environment', 'invalid_duration'])('does not retroactively grant Premium bonus for %s historical evidence', async mode => {
  payment();
  const p = store.documents.get(path('transactions', 'paid'))!;
  if (mode === 'missing') store.documents.delete(path('transactions', 'paid'));
  if (mode === 'future_purchase') p.clearedAtMillis = now;
  if (mode === 'before_interval') event('event', now - 2 * day);
  if (mode === 'at_expiry') { p.expiresAtMillis = now - 1000; event('event', now - 1000); }
  if (mode === 'wrong_owner') p.memberId = 'other';
  if (mode === 'pending') p.paymentStatus = 'pending';
  if (mode === 'reconciliation') p.fulfilmentStatus = 'reconciliation_required';
  if (mode === 'wrong_environment') p.environment = 'production';
  if (mode === 'invalid_duration') p.durationDays = 0;
  expect(await command('award', { eventId: 'event' })).toMatchObject({ award: { points: 5, premiumBonus: false } });
});
it.each(['absent', 'owner', 'source', 'producer', 'policy_version', 'client_time', 'future', 'old', 'before_policy'])('rejects %s event evidence', async mode => {
  const e = store.documents.get(path('rewardEvents', 'event'))!;
  if (mode === 'absent') store.documents.delete(path('rewardEvents', 'event'));
  if (mode === 'owner') e.memberId = 'other';
  if (mode === 'source') e.sourceId = 'workoutSessions';
  if (mode === 'producer') e.producerVersion = 'unconfigured';
  if (mode === 'policy_version') e.rewardPolicyVersion = 'unconfigured';
  if (mode === 'client_time') e.verification = 'client_asserted';
  if (mode === 'future') e.occurredAtMillis = now + 1;
  if (mode === 'old') e.occurredAtMillis = now - 61 * day;
  if (mode === 'before_policy') e.occurredAtMillis = now - 60 * day - 1;
  await expect(command('award', { eventId: 'event' })).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(store.documents.has(path('rewardBalances', uid))).toBe(false);
});
it('Premium bonus starts exactly at the paid grant interval and early renewal cannot backdate it', async () => {
  payment('paid', 'premium', now - day, now + 29 * day);
  event('event', now - day);
  expect(await command('award', { eventId: 'event' })).toMatchObject({ award: { points: 7, premiumBonus: true } });
  payment('renewal', 'premium', now - day, now + 59 * day);
  event('second', now - 1000); store.documents.get(path('rewardEvents', 'second'))!.membershipTransactionId = 'renewal';
  expect(await command('award', { eventId: 'second' })).toMatchObject({ award: { points: 5, premiumBonus: false } });
});
it.each(['disabled', 'no_sources', 'bad_timezone', 'no_rate', 'missing_unknown_tier_rule', 'expired'])('fails closed for %s policy', async mode => {
  const p = store.documents.get(path('rewardPolicies', 'current'))!;
  if (mode === 'disabled') p.enabled = false;
  if (mode === 'no_sources') delete p.sources;
  if (mode === 'bad_timezone') p.timezone = 'No/Such_Timezone';
  if (mode === 'no_rate') delete p.exchangeRate;
  if (mode === 'missing_unknown_tier_rule') delete p.unknownHistoricalTier;
  if (mode === 'expired') p.effectiveUntilMillis = now;
  expect(await command('overview')).toMatchObject({ available: false, canRedeem: false, items: [] });
  await expect(command('award', { eventId: 'event' })).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('does not reset the daily cap on a trusted policy version update', async () => {
  (store.documents.get(path('rewardPolicies', 'current'))!.sources as any[])[0].dailyEvents = 1;
  await command('award', { eventId: 'event' });
  event('second');
  store.documents.get(path('rewardPolicies', 'current'))!.version = 'updated-policy';
  store.documents.get(path('rewardEvents', 'second'))!.rewardPolicyVersion = 'updated-policy';
  await expect(command('award', { eventId: 'second' })).rejects.toMatchObject({ code: 'resource-exhausted' });
});
it('applies configured timezone daily cap atomically and starts a new earning day at its boundary', async () => {
  const localMidnight = Date.UTC(2027, 0, 15, 16);
  const policy = store.documents.get(path('rewardPolicies', 'current'))!;
  policy.effectiveFromMillis = localMidnight - day; policy.effectiveUntilMillis = localMidnight + 2 * day;
  event('a', localMidnight - 1); event('b', localMidnight - 1); event('c', localMidnight - 1); event('d', localMidnight);
  for (const id of ['a', 'b', 'c', 'd']) store.documents.get(path('rewardEvents', id))!.recordedAtMillis = localMidnight + 1;
  const outcomes = await Promise.allSettled(['a', 'b', 'c'].map(eventId => command('award', { eventId }, auth, localMidnight + 1)));
  expect(outcomes.filter(r => r.status === 'fulfilled')).toHaveLength(2);
  expect(outcomes.filter(r => r.status === 'rejected')).toHaveLength(1);
  expect(await command('award', { eventId: 'd' }, auth, localMidnight + 1)).toMatchObject({ award: { points: 5 } });
  expect(store.documents.get(path('rewardBalances', uid))?.points).toBe(15);
});
it('counts the Premium bonus inside the configured points cap', async () => {
  payment(); event('second');
  (store.documents.get(path('rewardPolicies', 'current'))!.sources as any[])[0].dailyAwardPoints = 10;
  await command('award', { eventId: 'event' });
  await expect(command('award', { eventId: 'second' })).rejects.toMatchObject({ code: 'resource-exhausted' });
  expect(store.documents.get(path('rewardBalances', uid))?.points).toBe(7);
});
it('Free keeps earned balance but cannot redeem physical rewards', async () => {
  await command('award', { eventId: 'event' });
  await expect(command('redeem', { itemId: 'item', requestId: 'r' })).rejects.toMatchObject({ code: 'permission-denied' });
  expect(store.documents.get(path('rewardBalances', uid))?.points).toBe(5);
});
it('atomically debits once, decrements last stock once, and retries return same voucher', async () => {
  payment('paid', 'basic'); await command('award', { eventId: 'event' });
  const result = await command('redeem', { itemId: 'item', requestId: 'r' });
  expect(result).toMatchObject({ redemption: { itemId: 'item', points: 5, status: 'issued', memberId: uid } });
  expect(await command('redeem', { itemId: 'item', requestId: 'r' })).toEqual(result);
  expect(store.documents.get(path('rewardBalances', uid))?.points).toBe(0);
  expect(store.documents.get(path('rewardItems', 'item'))?.stock).toBe(0);
});
it('serializes concurrent last-stock redemption across members', async () => {
  payment('paid', 'basic'); await command('award', { eventId: 'event' }); member('other');
  store.documents.set(path('membershipAccounts', 'other'), { ...store.documents.get(path('membershipAccounts', uid)), memberId: 'other', lastTransactionId: 'otherPaid' });
  store.documents.set(path('transactions', 'otherPaid'), { ...store.documents.get(path('transactions', 'paid')), transactionId: 'otherPaid', memberId: 'other' });
  store.documents.set(path('rewardBalances', 'other'), { schemaVersion: 1, organizationId: org, memberId: 'other', points: 5, recentRedemptionIds: [] });
  const results = await Promise.allSettled([command('redeem', { itemId: 'item', requestId: 'r' }), command('redeem', { itemId: 'item', requestId: 'r' }, { ...auth, uid: 'other' })]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect([...store.documents].filter(([p]) => p.includes('/rewardRedemptions/'))).toHaveLength(1);
  expect((store.documents.get(path('rewardBalances', uid))!.points as number) + (store.documents.get(path('rewardBalances', 'other'))!.points as number)).toBe(5);
});
it('prevents double spending on different rewards', async () => {
  payment('paid', 'basic'); await command('award', { eventId: 'event' });
  const item = store.documents.get(path('rewardItems', 'item'))!; item.stock = 2;
  const outcomes = await Promise.allSettled(['a', 'b'].map(requestId => command('redeem', { itemId: 'item', requestId })));
  expect(outcomes.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect(store.documents.get(path('rewardBalances', uid))?.points).toBe(0);
  expect(item.stock).toBe(2); // original input object cannot bypass transaction snapshots
  expect(store.documents.get(path('rewardItems', 'item'))?.stock).toBe(1);
});
it('Basic cannot redeem Premium-exclusive items', async () => {
  payment('paid', 'basic'); await command('award', { eventId: 'event' });
  store.documents.get(path('rewardItems', 'item'))!.premiumOnly = true;
  await expect(command('redeem', { itemId: 'item', requestId: 'r' })).rejects.toMatchObject({ code: 'permission-denied' });
});
it('only a currently verified active Admin fulfils a voucher once, even after member expiry', async () => {
  payment('paid', 'basic'); await command('award', { eventId: 'event' });
  const result = await command('redeem', { itemId: 'item', requestId: 'r' });
  const redemptionId = (result.redemption as Record<string, unknown>).redemptionId;
  await expect(command('fulfil', { redemptionId })).rejects.toMatchObject({ code: 'permission-denied' });
  const admin = { ...auth, uid: 'admin' };
  const fulfilled = await command('fulfil', { redemptionId }, admin);
  expect(fulfilled).toMatchObject({ redemption: { status: 'fulfilled', fulfilledBy: 'admin', fulfilledAtMillis: now } });
  expect(await command('fulfil', { redemptionId }, admin, now + 1)).toEqual(fulfilled);
  store.documents.get(path('members', 'admin'))!.status = 'suspended';
  await expect(command('fulfil', { redemptionId }, admin)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('lets Admin inspect a real reward voucher without fulfilling or debiting it', async () => {
  payment('paid', 'basic'); await command('award', { eventId: 'event' });
  const issued = await command('redeem', { itemId: 'item', requestId: 'inspect' });
  const redemptionId = (issued.redemption as Record<string, unknown>).redemptionId;
  const before = structuredClone([...store.documents]);
  expect(await command('inspect', { redemptionId }, { ...auth, uid: 'admin' })).toEqual(issued);
  expect([...store.documents]).toEqual(before);
  await expect(command('inspect', { redemptionId })).rejects.toMatchObject({ code: 'permission-denied' });
});
it.each(['points', 'memberId', 'tier', 'occurredAtMillis'])('rejects client-supplied %s authority', async key => {
  await expect(command('award', { eventId: 'event', [key]: 50 })).rejects.toBeInstanceOf(InputValidationError);
});
it('rejects disabled current Auth, stale lifecycle, malformed balance and nonuniform item price', async () => {
  await expect(rewardsCommand(store, auth, { schemaVersion: 1, organizationId: org, action: 'overview' }, async () => ({ exists: true, disabled: true, emailVerified: true }), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.get(`users/${uid}`)!.accountLifecycle = { schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: now / 1000 + 1 };
  await expect(command('overview')).rejects.toMatchObject({ code: 'permission-denied' });
  delete store.documents.get(`users/${uid}`)!.accountLifecycle;
  store.documents.set(path('rewardBalances', uid), { points: -1 });
  await expect(command('award', { eventId: 'event' })).rejects.toMatchObject({ code: 'failed-precondition' });
  store.documents.delete(path('rewardBalances', uid)); payment('paid', 'basic'); await command('award', { eventId: 'event' });
  store.documents.get(path('rewardItems', 'item'))!.pointCost = 4;
  await expect(command('redeem', { itemId: 'item', requestId: 'r' })).rejects.toMatchObject({ code: 'failed-precondition' });
});
