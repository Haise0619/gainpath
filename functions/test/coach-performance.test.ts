import { describe, expect, it } from 'vitest';
import { commissionFor } from '../src/modules/coaching/coach-performance-service';
describe('Coach earnings policy', () => {
  const booking = { status: 'completed' };
  const payment = { schemaVersion: 1, environment: 'sandbox', provider: 'billplz', currency: 'MYR', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed', amountMinor: 10001 };
  it('rounds 80 percent to minor units with platform receiving the remainder', () => {
    expect(commissionFor(booking, payment)).toEqual({ grossMinor: 10001, coachMinor: 8001, platformMinor: 2000 });
  });
  it('honors approved gym-funded gross commission and exposes collected cash/discount expense', () => {
    const discounted = { ...payment, memberId:'member',amountMinor:9000,grossAmountMinor:10000,discountMinor:1000,premiumVoucher:{
      schemaVersion:1,voucherId:'fixture',memberId:'member',policyVersion:'fixture',cycleStartAtMillis:1,cycleEndAtMillis:2592000001,
      grossAmountMinor:10000,discountMinor:1000,amountMinor:9000,rounding:'floor',fundingSource:'gym',coachCommissionBasis:'gross_fee',
      financeApprovalId:'fixture',commissionPolicyVersion:'sandbox-coach-80-v1',stacking:'none',refund:'no_reinstatement',unpaidRecovery:'provider_deleted_only',
    } };
    expect(commissionFor(booking,discounted)).toEqual({grossMinor:10000,coachMinor:8000,platformMinor:1000,collectedMinor:9000,discountMinor:1000});
    expect(commissionFor(booking,{...discounted,premiumVoucher:{...discounted.premiumVoucher,commissionPolicyVersion:'other'}})).toBeNull();
    expect(commissionFor(booking,{...discounted,discountMinor:999})).toBeNull();
  });
  it('excludes unpaid, undelivered, refunded and review cases', () => {
    for (const change of [{ paymentStatus: 'pending' }, { refundStatus: 'completed' }, { refundStatus: 'approved' }, { fulfilmentStatus: 'reconciliation_required' }]) {
      expect(commissionFor(booking, { ...payment, ...change })).toBeNull();
    }
    expect(commissionFor({ status: 'confirmed' }, payment)).toBeNull();
    expect(commissionFor(booking, { ...payment, environment: 'live' })).toBeNull();
  });
});
import { MemoryStore } from './memory-store';
import { seeds, now, start } from './booking-fixture';
import { coachPerformance } from '../src/modules/coaching/coach-performance-service';
const reportAuth = { uid: 'coach-1', token: { email_verified: true } };
const reportInput = { schemaVersion: 1, organizationId: 'org-1' };
function reportFixture() {
  const store = new MemoryStore();
  for (const [p, d] of Object.entries(seeds)) store.documents.set(p, structuredClone(d));
  const root = 'orgs/org-1/bookings/b1';
  const booking = { schemaVersion: 1, bookingId: 'b1', organizationId: 'org-1', memberId: 'member-1', coachId: 'coach-1', branchId: 'branch-1', requestId: 'r1', createdBy: 'member-1', createdAtMillis: now,
    startAtMillis: start, endAtMillis: start + 3600000, durationMinutes: 60, status: 'completed', holdExpiresAtMillis: now + 900000, localDate: '2026-10-02', timeZone: 'Asia/Kuala_Lumpur', policyVersion: 'booking-v1' };
  store.documents.set(root, booking);
  store.documents.set(root + '/consultation/current', { schemaVersion: 1, bookingId: 'b1', organizationId: 'org-1', memberId: 'member-1', coachId: 'coach-1' });
  store.documents.set(root + '/review/current', { schemaVersion: 1, bookingId: 'b1', memberId: 'member-1', coachId: 'coach-1', stars: 4 });
  store.documents.set('orgs/org-1/transactions/b1', { schemaVersion: 1, organizationId: 'org-1', bookingId: 'b1', memberId: 'member-1', environment: 'sandbox', provider: 'billplz', currency: 'MYR', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed', amountMinor: 10001 });
  const reader = { read: async () => [{ path: root, data: booking }] };
  return { store, reader };
}
describe('Coach report integration', () => {
  it('uses canonical noted/paid session, real review and one immutable earning; excludes subsequent refund', async () => {
    const { store, reader } = reportFixture();
    const run = () => coachPerformance(store, reportAuth, reportInput, reader, () => start + 7200000);
    const first = await run();
    expect(first).toMatchObject({ grossMinor: 10001, coachMinor: 8001, platformMinor: 2000, averageRating: 4, reviewCount: 1, payoutStatus: 'not_available' });
    const ledger = structuredClone(store.documents.get('orgs/org-1/coachEarnings/b1'));
    await run(); expect(store.documents.get('orgs/org-1/coachEarnings/b1')).toEqual(ledger);
    const p = store.documents.get('orgs/org-1/transactions/b1')!;
    store.documents.set('orgs/org-1/transactions/b1', { ...p, refundStatus: 'completed' });
    expect(await run()).toMatchObject({ coachMinor: 0, grossMinor: 0, reversedMinor: 8001 });
  });
  it('rejects Member requests and does not credit a session without notes', async () => {
    const { store, reader } = reportFixture();
    await expect(coachPerformance(store, { ...reportAuth, uid: 'member-1' }, reportInput, reader)).rejects.toThrow('private');
    store.documents.delete('orgs/org-1/bookings/b1/consultation/current');
    expect(await coachPerformance(store, reportAuth, reportInput, reader, () => start + 7200000)).toMatchObject({ coachMinor: 0 });
  });
});

it('rejects branch access removed after reading the final report session', async () => {
  const { store, reader } = reportFixture();
  let calls = 0;
  const guarded: import('../src/platform/firestore/store').DocumentStore = {
    transact: async work => {
      const result = await store.transact(work);
      if (++calls === 5) store.documents.set('orgs/org-1/members/coach-1', { organizationId: 'org-1', role: 'coach', status: 'active', branchIds: [] });
      return result;
    },
  };
  await expect(coachPerformance(guarded, reportAuth, reportInput, reader, () => start + 7200000)).rejects.toThrow('access changed');
});
