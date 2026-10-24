import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { resolveMembershipEntitlement } from '../src/modules/commerce/membership-entitlement';
import { membershipOverview } from '../src/modules/commerce/membership-payment-service';
const now = 1800000000000, org = 'gainpath', uid = 'member';
const auth = { uid, token: { email_verified: true, auth_time: now / 1000 } };
let store: MemoryStore;
const accountPath = `orgs/${org}/membershipAccounts/${uid}`;
const resolve = (at = now, who = auth) => store.transact(tx => resolveMembershipEntitlement(tx, who, org, at));
function paid(planId = 'premium', expiry = now + 86400000) {
  const account = { organizationId: org, memberId: uid, planId, planName: 'Configured name', expiresAtMillis: expiry, lastTransactionId: 'paid', benefits: ['Configured benefit'] };
  store.documents.set(accountPath, account);
  store.documents.set(`orgs/${org}/transactions/paid`, { schemaVersion: 1, organizationId: org, memberId: uid, transactionId: 'paid', kind: 'MembershipRenewal',
    environment: 'sandbox', provider: 'billplz', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed', billId: 'bill', collectionId: 'collection',
    amountMinor: 8900, currency: 'MYR', durationDays: 30, clearedAtMillis: now - 29 * 86400000, expiresAtMillis: expiry,
    planId, planName: 'Configured name', benefits: ['Configured benefit'] });
}
beforeEach(() => {
  store = new MemoryStore();
  store.documents.set(`orgs/${org}`, { status: 'active' });
  store.documents.set(`users/${uid}`, { organizationId: org });
  store.documents.set(`orgs/${org}/members/${uid}`, { organizationId: org, role: 'member', status: 'active', branchIds: [] });
});
it('derives Free with no expiry and performs no writes', async () => {
  const before = structuredClone([...store.documents]);
  expect(await resolve()).toMatchObject({ status: 'resolved', effectiveTier: 'free', paidTier: null, paidStatus: 'none', paidExpiresAtMillis: null, resolvedAtMillis: now });
  expect([...store.documents]).toEqual(before);
});
it('keeps an unpaid checkout Free without manufacturing a paid tier', async () => {
  store.documents.set(accountPath, { organizationId: org, memberId: uid, pendingTransactionId: 'creating' });
  expect(await resolve()).toMatchObject({ effectiveTier: 'free', paidStatus: 'none', reason: 'no_paid_membership' });
});
it.each(['basic', 'premium'])('resolves verified active %s independently of branch assignments', async tier => {
  paid(tier);
  expect(await resolve()).toMatchObject({ effectiveTier: tier, paidTier: tier, paidStatus: 'active', paidExpiresAtMillis: now + 86400000 });
});
it('expires exactly at the server boundary, retaining previous paid facts without writes', async () => {
  paid('premium', now);
  const before = structuredClone([...store.documents]);
  expect(await resolve()).toMatchObject({ effectiveTier: 'free', paidTier: 'premium', paidStatus: 'expired', paidExpiresAtMillis: now, paidPlanName: 'Configured name' });
  expect([...store.documents]).toEqual(before);
});
it('does not revoke paid time for a refund review or approval', async () => {
  paid();
  Object.assign(store.documents.get(`orgs/${org}/transactions/paid`)!, { fulfilmentStatus: 'reconciliation_required', refundStatus: 'approved', invoiceStatus: 'disputed' });
  expect(await resolve()).toMatchObject({ effectiveTier: 'premium', paidStatus: 'active' });
});
it.each(['elite', 'free'])('does not map unsupported paid tier %s to Free', async tier => {
  paid(tier);
  expect(await resolve()).toMatchObject({ status: 'unknown', effectiveTier: null, reason: 'unsupported_paid_tier' });
});
it.each(['missing_receipt', 'wrong_owner', 'pending', 'expiry_mismatch'])('fails closed for %s paid evidence', async mode => {
  paid();
  const p = store.documents.get(`orgs/${org}/transactions/paid`)!;
  if (mode === 'missing_receipt') store.documents.delete(`orgs/${org}/transactions/paid`);
  if (mode === 'wrong_owner') p.memberId = 'other';
  if (mode === 'pending') p.paymentStatus = 'pending';
  if (mode === 'expiry_mismatch') p.expiresAtMillis = now + 2 * 86400000;
  expect(await resolve()).toMatchObject({ status: 'unknown', effectiveTier: null, paidStatus: 'unknown' });
});
it('does not turn malformed or incomplete paid state into Free', async () => {
  store.documents.set(accountPath, { organizationId: org, memberId: uid, expiresAtMillis: 'bad' });
  expect(await resolve()).toMatchObject({ status: 'unknown', effectiveTier: null });
});
it.each(['suspended', 'coach', 'admin', 'wrong_org', 'deactivated', 'stale_session'])('denies %s rather than deriving Free', async mode => {
  const member = store.documents.get(`orgs/${org}/members/${uid}`)!, user = store.documents.get(`users/${uid}`)!;
  if (mode === 'suspended') member.status = 'suspended';
  if (['coach', 'admin'].includes(mode)) member.role = mode;
  if (mode === 'wrong_org') user.organizationId = 'other';
  if (mode === 'deactivated') user.accountLifecycle = { schemaVersion: 1, state: 'pendingDeletion', revocationPending: true, sessionNotBeforeSeconds: now / 1000 + 1 };
  if (mode === 'stale_session') user.accountLifecycle = { schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: now / 1000 + 1 };
  await expect(resolve()).rejects.toMatchObject({ code: 'permission-denied' });
});
it('denies unauthenticated, unverified and cross-account reads', async () => {
  await expect(store.transact(tx => resolveMembershipEntitlement(tx, undefined, org, now))).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(resolve(now, { uid, token: { email_verified: false, auth_time: now / 1000 } })).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(resolve(now, { ...auth, uid: 'other' })).rejects.toMatchObject({ code: 'permission-denied' });
});
it('adds entitlement to the existing overview without altering legacy paid facts or ledger', async () => {
  paid('basic', now);
  const before = structuredClone([...store.documents]);
  const result = await membershipOverview(store, auth, { schemaVersion: 1, organizationId: org }, { plans: async () => [], payments: async () => [] }, () => now);
  expect(result).toMatchObject({ account: { planId: 'basic', expiresAtMillis: now, status: 'expired' }, entitlement: { effectiveTier: 'free', paidTier: 'basic', paidStatus: 'expired' }, plans: [], transactions: [] });
  expect([...store.documents]).toEqual(before);
});
it.each(['disabled', 'unverified', 'deleted'])('does not return Free when current Auth identity is %s', async mode => {
  await expect(membershipOverview(store, auth, { schemaVersion: 1, organizationId: org },
    { plans: async () => [], payments: async () => [] }, () => now,
    async () => ({ exists: mode !== 'deleted', disabled: mode === 'disabled', emailVerified: mode !== 'unverified' })))
    .rejects.toMatchObject({ code: 'permission-denied' });
});
it('does not turn an Auth service outage into Free', async () => {
  await expect(membershipOverview(store, auth, { schemaVersion: 1, organizationId: org },
    { plans: async () => [], payments: async () => [] }, () => now,
    async () => { throw Error('Identity unavailable'); })).rejects.toThrow('Identity unavailable');
});
