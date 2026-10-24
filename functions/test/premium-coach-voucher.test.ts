import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { now, seeds, eligibleCoach, command } from './booking-fixture';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { createBookingPayment, getBookingPaymentQuote, settleBookingPayment } from '../src/modules/commerce/booking-payment-service';
import { preparePremiumCoachVoucherTerm } from '../src/modules/commerce/premium-coach-voucher';
import type { DocumentData } from '../src/platform/firestore/store';
import type { BillplzGateway, SandboxBill } from '../src/modules/commerce/billplz-sandbox';

const DAY = 86400000, org = 'org-1', uid = 'member-1';
const auth = { uid, token: { email_verified: true } };
const policyPath = `orgs/${org}/settings/premiumCoachVoucher`;
// Synthetic policy: no commercial approval or production configuration implied.
const policy = { schemaVersion: 1, policyVersion: 'fixture-v1', enabled: true,
  discountBasisPoints: 1000, maximumDiscountMinor: 1500, currency: 'MYR', cycleDays: 30,
  rounding: 'floor', fundingSource: 'gym', coachCommissionBasis: 'gross_fee', financeApprovalId: 'fixture-only',
  commissionPolicyVersion: 'sandbox-coach-80-v1', eligibleBranchIds: ['branch-1'], eligibleCoachIds: ['coach-1'],
  eligibleDurationsMinutes: [30, 60], expiry: 'cycle_end', stacking: 'none',
  refund: 'no_reinstatement', unpaidRecovery: 'provider_deleted_only' };
let store: MemoryStore, bookingId: string;
const quoteInput = { schemaVersion: 1, organizationId: org, coachId: 'coach-1', branchId: 'branch-1', durationMinutes: 60, includePremiumVoucher: true };
const quote = (at = now, extra: DocumentData = {}) => getBookingPaymentQuote(store, auth, { ...quoteInput, ...extra }, () => at, eligibleCoach);
const input = (id = bookingId) => ({ schemaVersion: 1, organizationId: org, bookingId: id, usePremiumVoucher: true });
function bill(id = bookingId, paid = false, amount = 10800): SandboxBill {
  return { id: `bill-${id}`, collection_id: 'sandbox-collection', amount, paid, paid_amount: paid ? amount : 0,
    state: paid ? 'paid' : 'due', url: `https://www.billplz-sandbox.com/bills/bill-${id}`, reference_1: id, reference_2: org };
}
const gateway: BillplzGateway = { create: async d => bill(d.reference, false, d.amountMinor), get: async id => bill(id.replace('bill-', ''), true) };
async function grant(id = 'paid-1', start = now - DAY, cleared = start, previous?: DocumentData) {
  const p = { schemaVersion: 1, organizationId: org, memberId: uid, transactionId: id, kind: previous ? 'MembershipRenewal' : 'MembershipPurchase',
    environment: 'sandbox', provider: 'billplz', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed', billId: `bill-${id}`, collectionId: 'collection',
    amountMinor: 8900, currency: 'MYR', durationDays: 30, clearedAtMillis: cleared, expiresAtMillis: start + 30 * DAY,
    planId: 'premium', planName: 'Synthetic Premium', benefits: [] };
  await store.transact(async tx => {
    const apply = await preparePremiumCoachVoucherTerm(tx, org, p, previous);
    tx.set(`orgs/${org}/transactions/${id}`, p);
    tx.set(`orgs/${org}/membershipAccounts/${uid}`, { organizationId: org, memberId: uid, planId: 'premium', expiresAtMillis: p.expiresAtMillis, lastTransactionId: id });
    apply();
  });
}
beforeEach(async () => {
  store = new MemoryStore(); Object.entries(seeds).forEach(([p,d]) => store.documents.set(p, structuredClone(d)));
  Object.assign(store.documents.get(`users/${uid}`)!, { email: 'member@example.invalid' });
  Object.assign(store.documents.get(`orgs/${org}/coaches/coach-1`)!, { displayName: 'Fixture Coach', consultationFeeMinor: 12000, certificationVerified: true });
  store.documents.set(`orgs/${org}/coachProfiles/coach-1/certificationState/current`, { certificationVerified: true, approvedCount: 1 });
  store.documents.set(policyPath, structuredClone(policy));
  bookingId = (await createBookingHoldService(store, uid, command, eligibleCoach, () => now)).bookingId;
});
it('reports unavailable and never grants when any required finance rule is missing; full-price contract survives', async () => {
  store.documents.delete(policyPath); await grant();
  expect(await quote()).toMatchObject({ amountMinor: 12000, premiumVoucher: { status: 'unavailable' } });
  expect([...store.documents.keys()].filter(p => p.includes('/premiumCoachVoucher'))).toEqual([]);
  await expect(createBookingPayment(store, auth, input(), gateway, eligibleCoach, () => now)).rejects.toMatchObject({ code: 'unavailable' });
  const legacy = await getBookingPaymentQuote(store, auth, { ...quoteInput, includePremiumVoucher: undefined });
  expect(legacy).not.toHaveProperty('premiumVoucher');
  expect(legacy.amountMinor).toBe(12000);
});
it.each(['rounding', 'fundingSource', 'coachCommissionBasis', 'financeApprovalId', 'commissionPolicyVersion', 'eligibleBranchIds', 'expiry', 'stacking', 'refund', 'unpaidRecovery'])('fails closed without explicit %s', async field => {
  delete store.documents.get(policyPath)![field]; await grant();
  expect(await quote()).toMatchObject({ premiumVoucher: { status: 'unavailable' } });
});
it('earns exactly one active cycle, preserves it across early renewal, and earns the next at its exact start', async () => {
  await grant();
  const first = (await quote()).premiumVoucher;
  expect(first).toMatchObject({ status: 'available', discountMinor: 1200, cycleStartAtMillis: now - DAY, cycleEndAtMillis: now + 29 * DAY });
  const prior = store.documents.get(`orgs/${org}/membershipAccounts/${uid}`)!;
  await grant('paid-2', now + 29 * DAY, now, prior);
  expect((await quote()).premiumVoucher).toEqual(first);
  expect((await quote(now + 29 * DAY)).premiumVoucher).toMatchObject({ status: 'available', cycleStartAtMillis: now + 29 * DAY });
  expect((await quote(now + 59 * DAY)).premiumVoucher).toMatchObject({ status: 'ineligible' });
});
it('validates cleared historical payment evidence, even after early renewal', async () => {
  await grant(); const prior = store.documents.get(`orgs/${org}/membershipAccounts/${uid}`)!;
  await grant('paid-2', now + 29 * DAY, now, prior);
  store.documents.get(`orgs/${org}/transactions/paid-1`)!.paymentStatus = 'pending';
  expect((await quote()).premiumVoucher).toMatchObject({ status: 'unavailable' });
});
it.each(['pending_review','approved','rejected'])('preserves an earned voucher while membership refund is only %s', async refundStatus => {
  await grant();
  Object.assign(store.documents.get(`orgs/${org}/transactions/paid-1`)!, { refundStatus, fulfilmentStatus: 'reconciliation_required' });
  expect((await quote()).premiumVoucher).toMatchObject({ status: 'available' });
});
it('uses server price and integer rounding/cap, refusing client price/tier/voucher-id tampering', async () => {
  await grant();
  store.documents.get(`orgs/${org}/coaches/coach-1`)!.consultationFeeMinor = 20009;
  expect(await quote(now, { usePremiumVoucher: true })).toMatchObject({ amountMinor: 18509, grossAmountMinor: 20009, discountMinor: 1500 });
  for (const extra of [{ amountMinor: 1 }, { tier: 'premium' }, { voucherId: 'forged' }, { usePremiumVoucher: 'true' }]) {
    await expect(quote(now, extra)).rejects.toThrow();
  }
  store.documents.get(`orgs/${org}/coaches/coach-1`)!.consultationFeeMinor = 10019;
  expect(await quote(now, { usePremiumVoucher: true })).toMatchObject({ amountMinor: 9018, discountMinor: 1001 });
});
it('atomically reserves one voucher against concurrent distinct checkouts', async () => {
  await grant();
  const booking = store.documents.get(`orgs/${org}/bookings/${bookingId}`)!;
  store.documents.set(`orgs/${org}/bookings/other-booking`, { ...booking, bookingId: 'other-booking' });
  const outcomes = await Promise.allSettled([bookingId, 'other-booking'].map(id => createBookingPayment(store, auth, input(id), gateway, eligibleCoach, () => now)));
  expect(outcomes.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect(outcomes.filter(r => r.status === 'rejected')).toHaveLength(1);
  expect((await quote()).premiumVoucher).toMatchObject({ status: 'reserved' });
});
it('retains uncertain reservations through expiry and duplicate attempts until trusted provider recovery', async () => {
  await grant();
  const uncertain: BillplzGateway = { ...gateway, create: async () => { throw Error('timeout'); } };
  expect(await createBookingPayment(store, auth, input(), uncertain, eligibleCoach, () => now)).toMatchObject({ status: 'reconciliation_required', amountMinor: 10800 });
  expect((await quote(now + 900001)).premiumVoucher).toMatchObject({ status: 'reserved' });
  expect(await createBookingPayment(store, auth, input(), gateway, eligibleCoach, () => now + 900001)).toMatchObject({ status: 'reconciliation_required', amountMinor: 10800 });
});
it('releases only a bound independently verified deleted unpaid bill, never a due or forged bill', async () => {
  await grant(); await createBookingPayment(store, auth, input(), gateway, eligibleCoach, () => now);
  await settleBookingPayment(store, org, bookingId, bill(), eligibleCoach, () => now + 1000);
  expect((await quote()).premiumVoucher).toMatchObject({ status: 'reserved' });
  await expect(settleBookingPayment(store, org, bookingId, { ...bill(), id: 'foreign', state: 'deleted' }, eligibleCoach, () => now + 1001)).rejects.toThrow();
  await settleBookingPayment(store, org, bookingId, { ...bill(), state: 'deleted' }, eligibleCoach, () => now + 2000);
  expect((await quote()).premiumVoucher).toMatchObject({ status: 'available' });
  const before = structuredClone([...store.documents]);
  await settleBookingPayment(store, org, bookingId, { ...bill(), state: 'deleted' }, eligibleCoach, () => now + 3000);
  expect([...store.documents]).toEqual(before);
});
it('refuses overlapping/duplicate term grants and cannot manufacture earned evidence from account flags', async () => {
  await grant(); const terms = [...store.documents].filter(([p]) => p.includes('/premiumCoachVoucherTerms/'));
  await grant();
  expect([...store.documents].filter(([p]) => p.includes('/premiumCoachVoucherTerms/'))).toEqual(terms);
  await grant('overlap', now, now, store.documents.get(`orgs/${org}/membershipAccounts/${uid}`));
  expect([...store.documents].filter(([p]) => p.includes('/premiumCoachVoucherTerms/'))).toEqual(terms);
  store.documents.get(`orgs/${org}/transactions/paid-1`)!.memberId = 'foreign';
  expect((await quote()).premiumVoucher).toMatchObject({ status: 'unavailable' });
});
it('consumes once on trusted clearance and keeps approved price despite policy/entitlement expiry or refunds', async () => {
  await grant(); await createBookingPayment(store, auth, input(), gateway, eligibleCoach, () => now);
  store.documents.delete(policyPath);
  const result = await settleBookingPayment(store, org, bookingId, bill(bookingId, true), eligibleCoach, () => now + 1000);
  expect(result).toMatchObject({ status: 'confirmed', amountMinor: 10800, discountMinor: 1200 });
  const before = structuredClone([...store.documents]);
  await settleBookingPayment(store, org, bookingId, bill(bookingId, true), eligibleCoach, () => now + 2000);
  expect([...store.documents]).toEqual(before);
  const voucher = [...store.documents.entries()].find(([p]) => p.includes('/premiumCoachVouchers/'))!;
  expect(voucher[1]).toMatchObject({ status: 'consumed', bookingId, consumedAtMillis: now + 1000 });
  store.documents.get(`orgs/${org}/transactions/${bookingId}`)!.refundStatus = 'completed';
  expect(store.documents.get(voucher[0])!.status).toBe('consumed');
});
it('rejects a corrupted reserved price snapshot without clearing money or consuming the voucher', async () => {
  await grant(); await createBookingPayment(store, auth, input(), gateway, eligibleCoach, () => now);
  const p = store.documents.get(`orgs/${org}/transactions/${bookingId}`)!;
  (p.premiumVoucher as DocumentData).fundingSource = 'coach';
  await expect(settleBookingPayment(store, org, bookingId, bill(bookingId,true), eligibleCoach, () => now+1000)).rejects.toMatchObject({code:'failed-precondition'});
  expect(store.documents.get(`orgs/${org}/transactions/${bookingId}`)!.paymentStatus).toBe('pending');
});
it('rejects stale lifecycle/current Auth, foreign organization and unverified identity', async () => {
  await grant();
  await expect(getBookingPaymentQuote(store, { uid, token: { email_verified: false } }, quoteInput, () => now, eligibleCoach)).rejects.toThrow();
  await expect(getBookingPaymentQuote(store, auth, quoteInput, () => now, async () => ({ exists: true, disabled: true, emailVerified: true }))).rejects.toThrow();
  store.documents.get(`users/${uid}`)!.accountLifecycle = { schemaVersion: 1, state: 'pendingDeletion', revocationPending: true, sessionNotBeforeSeconds: 0 };
  await expect(quote()).rejects.toMatchObject({ code: 'permission-denied' });
});
