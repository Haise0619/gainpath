import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { membershipQuote, createMembershipPayment, settleMembershipPayment, membershipRefund, readMembershipPayment } from '../src/modules/commerce/membership-payment-service';
import type { BillplzGateway, SandboxBill } from '../src/modules/commerce/billplz-sandbox';
import { manageAdminBookingPayment, listAdminBookingPayments, type PaymentAdminDependencies } from '../src/modules/commerce/booking-payment-admin';
let store: MemoryStore, creates: number;
const now = 1800000000000, auth = { uid: 'member', token: { email_verified: true } };
const base = { schemaVersion: 1, organizationId: 'gainpath' };
const input = { ...base, planId: 'trusted', requestId: 'request1', intent: 'purchase' };
const path = 'orgs/gainpath/transactions/';
let reference = '';
const bill = (paid = false): SandboxBill => ({ id: 'bill', collection_id: 'collection', amount: 10000, paid, paid_amount: paid ? 10000 : 0, state: paid ? 'paid' : 'due', url: 'https://www.billplz-sandbox.com/bills/bill', reference_1: reference, reference_2: 'gainpath' });
const gateway: BillplzGateway = { create: async x => { creates++; reference = x.reference; return bill(); }, get: async () => bill(true) };
beforeEach(() => {
  store = new MemoryStore(); creates = 0;
  store.documents.set('orgs/gainpath', { status: 'active' });
  store.documents.set('users/member', { organizationId: 'gainpath', email: 'm@example.invalid', displayName: 'Member' });
  store.documents.set('orgs/gainpath/members/member', { organizationId: 'gainpath', status: 'active', role: 'member', branchIds: [] });
  store.documents.set('orgs/gainpath/membershipPlans/trusted', { active: true, name: 'Configured plan', amountMinor: 10000, currency: 'MYR', durationDays: 30, benefits: ['Configured benefit'], version: 'v1' });
});
it('quotes configured prices and rejects client price overrides and unconfigured plans', async () => {
  expect(await membershipQuote(store, auth, { ...base, planId: 'trusted' }, () => now)).toMatchObject({ amountMinor: 10000, durationDays: 30 });
  await expect(createMembershipPayment(store, auth, { ...input, amountMinor: 1 }, gateway, () => now)).rejects.toThrow();
  await expect(membershipQuote(store, auth, { ...base, planId: 'missing' }, () => now)).rejects.toThrow();
});
it('refuses changed catalogue terms after member reviewed a quote', async () => {
  const q = await membershipQuote(store, auth, { ...base, planId: 'trusted' }, () => now);
  store.documents.get('orgs/gainpath/membershipPlans/trusted')!.amountMinor = 20000;
  await expect(createMembershipPayment(store, auth, { ...input, quoteId: q.quoteId }, gateway, () => now)).rejects.toThrow();
  expect(creates).toBe(0);
});
it('reserves one bill across concurrent requests and applies duplicate paid events exactly once', async () => {
  const rows = await Promise.all([createMembershipPayment(store, auth, input, gateway, () => now), createMembershipPayment(store, auth, input, gateway, () => now)]);
  expect(creates).toBe(1);
  const id = String(rows[0].transactionId);
  await Promise.all([settleMembershipPayment(store, 'gainpath', id, bill(true), () => now), settleMembershipPayment(store, 'gainpath', id, bill(true), () => now)]);
  expect(store.documents.get('orgs/gainpath/membershipAccounts/member')?.expiresAtMillis).toBe(now + 30 * 86400000);
  expect(store.documents.get(path + id)?.paymentStatus).toBe('cleared');
});
it('preserves remaining paid time and serializes multiple renewals', async () => {
  store.documents.set('orgs/gainpath/membershipAccounts/member', { planId: 'trusted', expiresAtMillis: now + 50000 });
  const first = await createMembershipPayment(store, auth, { ...input, intent: 'renewal' }, gateway, () => now);
  await settleMembershipPayment(store, 'gainpath', String(first.transactionId), bill(true), () => now);
  const second = await createMembershipPayment(store, auth, { ...input, requestId: 'second', intent: 'renewal' }, gateway, () => now);
  await settleMembershipPayment(store, 'gainpath', String(second.transactionId), bill(true), () => now);
  expect(store.documents.get('orgs/gainpath/membershipAccounts/member')?.expiresAtMillis).toBe(now + 50000 + 60 * 86400000);
});
it('quarantines ambiguous creation and never creates a replacement', async () => {
  const uncertain = { ...gateway, create: async () => { creates++; throw Error('timeout'); } };
  const p = await createMembershipPayment(store, auth, input, uncertain, () => now);
  expect(p.fulfilmentStatus).toBe('reconciliation_required');
  await createMembershipPayment(store, auth, { ...input, requestId: 'new' }, gateway, () => now);
  expect(creates).toBe(1);
});
it('rejects cross-account, wrong-organization and unverified-email calls', async () => {
  const p = await createMembershipPayment(store, auth, input, gateway, () => now);
  await expect(readMembershipPayment(store, { ...auth, uid: 'other' }, { ...base, transactionId: p.transactionId }, gateway, () => now)).rejects.toThrow();
  await expect(membershipQuote(store, auth, { ...base, organizationId: 'other', planId: 'trusted' })).rejects.toThrow();
  await expect(membershipQuote(store, { ...auth, token: {} }, { ...base, planId: 'trusted' })).rejects.toThrow();
});
it('checks promo date, tier and capacity atomically', async () => {
  store.documents.set('orgs/gainpath/promoCodes/VALID', { active: true, discountPercent: 10, validFromMillis: now - 1, validToMillis: now + 10000, maxRedemptions: 1, currentRedemptions: 0, planIds: ['trusted'] });
  expect(await membershipQuote(store, auth, { ...base, planId: 'trusted', promoCode: 'VALID' }, () => now)).toMatchObject({ amountMinor: 9000 });
  await expect(membershipQuote(store, auth, { ...base, planId: 'trusted', promoCode: 'VALID' }, () => now + 20000)).rejects.toThrow();
  const g = { ...gateway, create: async (x: Parameters<BillplzGateway['create']>[0]) => { reference = x.reference; return { ...bill(), amount: x.amountMinor }; } };
  await createMembershipPayment(store, auth, { ...input, promoCode: 'VALID' }, g, () => now);
  await expect(membershipQuote(store, auth, { ...base, planId: 'trusted', promoCode: 'VALID' }, () => now)).rejects.toThrow();
});
it('allows a seven-day refund request once, never executes a provider transfer', async () => {
  const p = await createMembershipPayment(store, auth, input, gateway, () => now);
  await settleMembershipPayment(store, 'gainpath', String(p.transactionId), bill(true), () => now);
  const request = { ...base, transactionId: p.transactionId, reason: 'Duplicate charge', notes: 'Please review' };
  await membershipRefund(store, auth, request, () => now + 86400000);
  await membershipRefund(store, auth, request, () => now + 86400000);
  expect(store.documents.get(path + p.transactionId)).toMatchObject({ refundStatus: 'pending_review', invoiceStatus: 'disputed', paymentStatus: 'cleared' });
  await expect(membershipRefund(store, auth, request, () => now + 8 * 86400000)).rejects.toThrow();
  expect(creates).toBe(1);
});
it('keeps late cleared money in review, rejects wrong amount, and permits retry after verified deletion', async () => {
  const p = await createMembershipPayment(store, auth, input, gateway, () => now);
  await expect(settleMembershipPayment(store, 'gainpath', String(p.transactionId), { ...bill(true), paid_amount: 1 }, () => now)).rejects.toThrow();
  expect((await settleMembershipPayment(store, 'gainpath', String(p.transactionId), { ...bill(), state: 'deleted' }, () => now)).fulfilmentStatus).toBe('failed');
  const retry = await createMembershipPayment(store, auth, { ...input, requestId: 'retry' }, gateway, () => now);
  expect(creates).toBe(2);
  await settleMembershipPayment(store, 'gainpath', String(retry.transactionId), bill(true), () => now + 31 * 60000);
  expect(store.documents.get(path + retry.transactionId)).toMatchObject({ paymentStatus: 'cleared', fulfilmentStatus: 'reconciliation_required' });
  expect(store.documents.get('orgs/gainpath/membershipAccounts/member')?.expiresAtMillis).toBeUndefined();
});
it('restarts expired membership at current server time', async () => {
  store.documents.set('orgs/gainpath/membershipAccounts/member', { planId: 'trusted', expiresAtMillis: now - 10000 });
  const p = await createMembershipPayment(store, auth, { ...input, intent: 'renewal' }, gateway, () => now);
  await settleMembershipPayment(store, 'gainpath', String(p.transactionId), bill(true), () => now);
  expect(store.documents.get('orgs/gainpath/membershipAccounts/member')?.expiresAtMillis).toBe(now + 30 * 86400000);
});
it('atomically retains one earned Premium voucher term for each verified paid period', async () => {
  store.documents.set('orgs/gainpath/settings/premiumCoachVoucher', {
    schemaVersion: 1, policyVersion: 'fixture-v1', enabled: true, currency: 'MYR', cycleDays: 30,
    discountBasisPoints: 1000, maximumDiscountMinor: 1500, rounding: 'floor', fundingSource: 'gym', coachCommissionBasis: 'gross_fee',
    financeApprovalId: 'fixture-only', commissionPolicyVersion: 'sandbox-coach-80-v1', eligibleBranchIds: ['fixture-branch'], eligibleCoachIds: ['fixture-coach'],
    eligibleDurationsMinutes: [30, 60], expiry: 'cycle_end', stacking: 'none', refund: 'no_reinstatement', unpaidRecovery: 'provider_deleted_only',
  });
  store.documents.set('orgs/gainpath/membershipPlans/premium', { ...store.documents.get('orgs/gainpath/membershipPlans/trusted')! });
  const p = await createMembershipPayment(store, auth, { ...input, planId: 'premium' }, gateway, () => now);
  await Promise.all([settleMembershipPayment(store, 'gainpath', String(p.transactionId), bill(true), () => now), settleMembershipPayment(store, 'gainpath', String(p.transactionId), bill(true), () => now)]);
  const terms = () => [...store.documents.entries()].filter(([key]) => key.includes('/premiumCoachVoucherTerms/'));
  expect(terms()).toHaveLength(1);
  expect(terms()[0][1]).toMatchObject({ memberId: 'member', paymentId: p.transactionId, startAtMillis: now, endAtMillis: now + 30 * 86400000, previousPaymentId: null });
  const renewal = await createMembershipPayment(store, auth, { ...input, planId: 'premium', intent: 'renewal', requestId: 'premium-renewal' }, gateway, () => now);
  await settleMembershipPayment(store, 'gainpath', String(renewal.transactionId), bill(true), () => now);
  expect(terms()).toHaveLength(2);
  expect(store.documents.get('orgs/gainpath/premiumCoachVoucherTerms/' + renewal.transactionId)).toMatchObject({ previousPaymentId: p.transactionId, startAtMillis: now + 30 * 86400000, endAtMillis: now + 60 * 86400000 });
});
it('does not activate after Firebase Auth becomes ineligible or current organization is removed', async () => {
  const p = await createMembershipPayment(store, auth, input, gateway, () => now);
  await settleMembershipPayment(store, 'gainpath', String(p.transactionId), bill(true), () => now,
    async () => ({ exists: true, disabled: true, emailVerified: true }));
  expect(store.documents.get(path + p.transactionId)).toMatchObject({ paymentStatus: 'cleared', resolutionReason: 'account_ineligible' });
  expect(store.documents.get('orgs/gainpath/membershipAccounts/member')?.expiresAtMillis).toBeUndefined();
});
it('reuses Admin review without sending membership refund transfers or touching entitlement', async () => {
  const p = await createMembershipPayment(store, auth, input, gateway, () => now);
  await settleMembershipPayment(store, 'gainpath', String(p.transactionId), bill(true), () => now);
  await membershipRefund(store, auth, { ...base, transactionId: p.transactionId, reason: 'Duplicate charge', notes: '' }, () => now);
  store.documents.set('users/admin', { organizationId: 'gainpath' });
  store.documents.set('orgs/gainpath/members/admin', { organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: [] });
  const deps: PaymentAdminDependencies = { bills: gateway, collectionId: 'collection', readIdentity: async () => { throw Error('Not used for membership'); },
    reader: { list: async () => [{ id: String(p.transactionId), data: store.documents.get(path + p.transactionId)! }], events: async () => [] } };
  const command = { ...base, bookingId: p.transactionId, requestId: 'decision', action: 'approve_refund', reason: 'Reviewed duplicate charge' };
  await expect(manageAdminBookingPayment(store, auth, command, deps)).rejects.toMatchObject({ code: 'permission-denied' });
  const adminAuth = { uid: 'admin', token: { email_verified: true } };
  expect((await listAdminBookingPayments(store, adminAuth, base, deps)).records[0]).toMatchObject({ kind: 'MembershipPurchase' });
  const result = await manageAdminBookingPayment(store, adminAuth, command, deps, () => now);
  expect(result.payment.refundStatus).toBe('approved');
  expect(result.refundExecutionAvailable).toBe(false);
  expect(store.documents.get('orgs/gainpath/membershipAccounts/member')?.expiresAtMillis).toBe(now + 30 * 86400000);
  await expect(manageAdminBookingPayment(store, adminAuth, { ...command, requestId: 'execute', action: 'execute_refund' }, deps)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('Admin recovers an unpaid orphan bill with its checkout URL then verifies clearance on first request', async () => {
  const p = await createMembershipPayment(store, auth, input, { ...gateway, create: async x => { reference = x.reference; throw Error('uncertain'); } }, () => now);
  store.documents.set('users/admin', { organizationId: 'gainpath' });
  store.documents.set('orgs/gainpath/members/admin', { organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: [] });
  let providerPaid = false;
  const deps: PaymentAdminDependencies = { bills: { ...gateway, get: async () => bill(providerPaid) }, collectionId: 'collection',
    readIdentity: async () => ({ exists: true, disabled: false, emailVerified: true }),
    reader: { list: async () => [], events: async () => [] } };
  const command = { ...base, bookingId: p.transactionId, requestId: 'recover', action: 'recover_bill', billId: 'bill', reason: 'Provider bill verified' };
  const adminAuth = { uid: 'admin', token: { email_verified: true } };
  await manageAdminBookingPayment(store, adminAuth, command, deps, () => now + 1000);
  expect(store.documents.get(path + p.transactionId)).toMatchObject({ billId: 'bill', checkoutUrl: bill().url, fulfilmentStatus: 'awaiting_payment' });
  providerPaid = true;
  const result = await manageAdminBookingPayment(store, adminAuth, { ...base, bookingId: p.transactionId, requestId: 'verify', action: 'verify' }, deps, () => now + 2000);
  expect(result.payment.paymentStatus).toBe('cleared');
  expect(store.documents.get('orgs/gainpath/membershipAccounts/member')?.expiresAtMillis).toBe(now + 2000 + 30 * 86400000);
});
