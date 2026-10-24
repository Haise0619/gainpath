import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { membershipAccess, verifyMemberMembership } from '../src/modules/commerce/membership-access-service';

const now = 1800000000000, org = 'gainpath';
const auth = (uid = 'member') => ({ uid, token: { email_verified: true, auth_time: now / 1000 } });
const identity = async (_uid: string) => ({ exists: true, disabled: false, emailVerified: true });
const request = { schemaVersion: 1, organizationId: org, feature: 'exercise', resourceId: 'supported' };
let store: MemoryStore;
const access = (data = request) => membershipAccess(store, auth(), data, identity, () => now);
const verify = () => verifyMemberMembership(store, auth('admin'), { schemaVersion: 1, organizationId: org, memberId: 'member' }, identity, () => now);
function paid(planId = 'premium', expiry = now + 1000) {
  store.documents.set(`orgs/${org}/membershipAccounts/member`, { organizationId: org, memberId: 'member', planId, expiresAtMillis: expiry, lastTransactionId: 'payment' });
  store.documents.set(`orgs/${org}/transactions/payment`, { schemaVersion: 1, organizationId: org, memberId: 'member', transactionId: 'payment', kind: 'MembershipPurchase', planId, planName: 'Paid', benefits: [], environment: 'sandbox', provider: 'billplz', currency: 'MYR', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed', billId: 'bill', collectionId: 'collection', amountMinor: 100, durationDays: 30, clearedAtMillis: now - 1000, expiresAtMillis: expiry });
}
beforeEach(() => {
  store = new MemoryStore();
  store.documents.set(`orgs/${org}`, { status: 'active' });
  for (const uid of ['member', 'admin']) {
    store.documents.set(`users/${uid}`, { organizationId: org });
    store.documents.set(`orgs/${org}/members/${uid}`, { organizationId: org, userId: uid, role: uid, status: 'active', branchIds: [], displayName: uid });
  }
  store.documents.set(`orgs/${org}/membershipPolicies/access`, { schemaVersion: 1, policyVersion: 'gainpath-membership-access-v1', enabled: true, exercises: { supportedIds: ['supported', 'paid'], freeIds: ['supported'] }, advancedReports: { reportIds: ['performance_trends'] } });
});
it('uses the explicit Free list without denying supported paid exercises to paid members', async () => {
  expect(await access()).toMatchObject({ decision: 'allowed', effectiveTier: 'free' });
  expect(await access({ ...request, resourceId: 'paid' })).toMatchObject({ decision: 'denied', requiredTier: 'basic' });
  paid('basic');
  expect(await access({ ...request, resourceId: 'paid' })).toMatchObject({ decision: 'allowed', effectiveTier: 'basic' });
  expect(await access({ ...request, resourceId: 'invented' })).toMatchObject({ decision: 'denied', reason: 'resource_not_configured' });
});
it('requires Premium for configured reports and expires exactly at the paid boundary', async () => {
  const r = { ...request, feature: 'advancedReport', resourceId: 'performance_trends' };
  paid('basic'); expect(await access(r)).toMatchObject({ decision: 'denied', requiredTier: 'premium' });
  paid(); expect(await access(r)).toMatchObject({ decision: 'allowed' });
  paid('premium', now); expect(await access(r)).toMatchObject({ decision: 'denied', effectiveTier: 'free' });
});
it.each(['absent', 'disabled', 'malformed'])('preserves existing access for %s policy', async mode => {
  const path = `orgs/${org}/membershipPolicies/access`;
  if (mode === 'absent') store.documents.delete(path);
  if (mode === 'disabled') store.documents.get(path)!.enabled = false;
  if (mode === 'malformed') store.documents.get(path)!.exercises = { supportedIds: ['supported'], freeIds: ['invented'] };
  expect(await access({ ...request, resourceId: 'legacy' })).toMatchObject({ decision: 'legacy' });
});
it('never grants configured paid access using unknown payment evidence', async () => {
  paid(); store.documents.delete(`orgs/${org}/transactions/payment`);
  expect(await access()).toMatchObject({ decision: 'unknown', effectiveTier: null });
});
it('ignores target session age while verifying current target Auth and lifecycle without impersonation', async () => {
  store.documents.get('users/member')!.accountLifecycle = { schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: now / 1000 + 1 };
  paid();
  const before = structuredClone([...store.documents]);
  expect(await verify()).toMatchObject({ status: 'verified', gymAdmission: true, memberId: 'member', entitlement: { effectiveTier: 'premium' } });
  expect([...store.documents]).toEqual(before);
});
it('shows verified Free without implying general gym admission', async () => {
  expect(await verify()).toMatchObject({ status: 'verified', gymAdmission: false, entitlement: { effectiveTier: 'free' } });
});
it.each(['suspended', 'unverified', 'disabled', 'missing', 'deactivated'])('does not fabricate Free for %s targets', async mode => {
  if (mode === 'suspended') store.documents.get(`orgs/${org}/members/member`)!.status = 'suspended';
  if (mode === 'deactivated') store.documents.get('users/member')!.accountLifecycle = { schemaVersion: 1, state: 'deleted', revocationPending: false, sessionNotBeforeSeconds: 0 };
  const result = await verifyMemberMembership(store, auth('admin'), { schemaVersion: 1, organizationId: org, memberId: 'member' }, async uid => uid === 'admin' ? identity(uid) : ({ exists: mode !== 'missing', disabled: mode === 'disabled', emailVerified: mode !== 'unverified' }), () => now);
  expect(result).toMatchObject({ status: 'denied', gymAdmission: false, entitlement: null });
});
it.each(['member', 'staff', 'wrong_org', 'stale', 'disabled'])('denies unauthorized verifier %s', async mode => {
  const admin = store.documents.get(`orgs/${org}/members/admin`)!;
  if (['member', 'staff'].includes(mode)) admin.role = mode;
  if (mode === 'wrong_org') store.documents.get('users/admin')!.organizationId = 'other';
  if (mode === 'stale') store.documents.get('users/admin')!.accountLifecycle = { schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: now / 1000 + 1 };
  await expect(verifyMemberMembership(store, auth('admin'), { schemaVersion: 1, organizationId: org, memberId: 'member' }, async uid => ({ ...(await identity(uid)), disabled: uid === 'admin' && mode === 'disabled' }), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('rejects cross-account access and client tier overrides', async () => {
  await expect(access({ ...request, memberId: 'other' } as typeof request)).rejects.toThrow('Unsupported');
  await expect(access({ ...request, effectiveTier: 'premium' } as typeof request)).rejects.toThrow('Unsupported');
  store.documents.get('users/member')!.organizationId = 'other';
  await expect(access()).rejects.toMatchObject({ code: 'permission-denied' });
});
it('does not convert identity outages into Free verification', async () => {
  await expect(verifyMemberMembership(store, auth('admin'), { schemaVersion: 1, organizationId: org, memberId: 'member' }, async () => { throw Error('offline'); }, () => now)).rejects.toThrow('offline');
});
it('keeps corrupt paid verification unknown and denies gym admission', async () => {
  paid(); store.documents.delete(`orgs/${org}/transactions/payment`);
  expect(await verify()).toMatchObject({ status: 'unknown', gymAdmission: false, entitlement: { status: 'unknown', effectiveTier: null } });
});
it('rechecks Admin authority after the external target identity read', async () => {
  await expect(verifyMemberMembership(store, auth('admin'), { schemaVersion: 1, organizationId: org, memberId: 'member' }, async uid => {
    if (uid === 'member') store.documents.get(`orgs/${org}/members/admin`)!.status = 'suspended';
    return identity(uid);
  }, () => now)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('target Auth reads happen outside retryable transaction callbacks', async () => {
  let inTransaction = false;
  const retrying = { transact: async <T>(work: Parameters<MemoryStore['transact']>[0]): Promise<T> => {
    inTransaction = true;
    try { await store.transact(work); return await store.transact(work) as T; }
    finally { inTransaction = false; }
  } };
  const checked: string[] = [];
  const result = await verifyMemberMembership(retrying, auth('admin'), { schemaVersion: 1, organizationId: org, memberId: 'member' }, async uid => {
    expect(inTransaction).toBe(false); checked.push(uid); return identity(uid);
  }, () => now);
  expect(checked).toEqual(['admin', 'member']);
  expect(result).toMatchObject({ status: 'verified', gymAdmission: false });
});
