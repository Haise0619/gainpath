import { expect, it } from 'vitest';
import { ReadProbeStore } from './read-probe-store';
import { listAdminBookingPayments, type PaymentAdminDependencies } from '../src/modules/commerce/booking-payment-admin';
import { getBookingListService } from '../src/modules/coaching/booking-list-service';
import { getCoachAvailabilityService } from '../src/modules/coaching/coach-availability-service';
import { membershipOverview } from '../src/modules/commerce/membership-payment-service';
import { now, seeds as bookingSeeds } from './booking-fixture';
import { seeds as availabilitySeeds, read as availabilityRead, auth as availabilityAuth, now as availabilityNow } from './coach-availability.fixture';

const auth = { uid: 'admin', token: { email_verified: true } };
const input = { schemaVersion: 1, organizationId: 'org' };
const unavailable = async (): Promise<never> => { throw Error('Provider must never be called by list'); };
function adminFixture() {
  const store = new ReadProbeStore();
  store.documents.set('users/admin', { organizationId: 'org' });
  store.documents.set('orgs/org', { status: 'active' });
  store.documents.set('orgs/org/members/admin', { organizationId: 'org', role: 'admin', status: 'active', branchIds: [] });
  store.documents.set('orgs/org/members/member', { organizationId: 'org', displayName: 'Fixture Member', email: 'private@example.invalid' });
  const rows = Array.from({ length: 21 }, (_, i) => {
    const id = `payment${String(i).padStart(2, '0')}`;
    return { id, data: { schemaVersion: 1, organizationId: 'org', environment: 'sandbox', provider: 'billplz',
      ...(i === 19 ? { transactionId: id, kind: 'MembershipPurchase', durationDays: 30, planName: 'Synthetic plan' } : { bookingId: id, kind: 'CoachingBooking' }),
      memberId: 'member', coachId: 'coach', amountMinor: 100, currency: 'MYR', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed' } };
  });
  const deps: PaymentAdminDependencies = { bills: { create: unavailable, get: unavailable }, collectionId: 'fixture',
    readIdentity: unavailable, reader: { list: async () => rows, events: async () => [] } };
  return { store, rows, deps };
}
it('loads a mixed Admin page in one related-document batch with one read per Member, preserving order and cursor', async () => {
  const { store, deps } = adminFixture();
  const before = structuredClone([...store.documents]);
  const page = await listAdminBookingPayments(store, auth, input, deps);
  expect(page.records).toHaveLength(20);
  expect(page.nextAfterId).toBe('payment19');
  expect(page.records.map(r => r.bookingId)).toEqual(Array.from({ length: 20 }, (_, i) => `payment${String(i).padStart(2, '0')}`));
  expect(page.records.every(r => r.memberDisplayName === 'Fixture Member' && r.email === undefined)).toBe(true);
  expect(page.records[19]).toMatchObject({ kind: 'MembershipPurchase', transactionId: 'payment19' });
  expect(store.readRpcs).toBe(3); // Three fresh authorization snapshots, no skipped recheck.
  const related = store.batches.find(paths => paths.includes('orgs/org/bookings/payment00'))!;
  expect(related).toHaveLength(23); // Three authority docs + 19 bookings + one shared Member.
  expect(related).not.toContain('orgs/org/bookings/payment19');
  expect(related).not.toContain('orgs/org/bookings/payment20');
  expect(store.singles).not.toContain('orgs/org/members/member');
  expect([...store.documents]).toEqual(before);
});
it('retains raw-page pagination even when non-Sandbox rows are filtered', async () => {
  const { store, rows, deps } = adminFixture();
  rows[0].data.provider = 'other';
  let after: string | undefined;
  deps.reader.list = async (_org, cursor) => { after = cursor; return rows; };
  const page = await listAdminBookingPayments(store, auth, { ...input, afterId: 'older' }, deps);
  expect(after).toBe('older');
  expect(page.records).toHaveLength(19);
  expect(page.nextAfterId).toBe('payment19');
});
it('denies revoked Admin scope after the query and never queries for an unauthorized caller', async () => {
  const { store, rows, deps } = adminFixture();
  let queried = false;
  deps.reader.list = async () => { queried = true; store.documents.get('orgs/org/members/admin')!.role = 'member'; return rows; };
  await expect(listAdminBookingPayments(store, { ...auth, uid: 'other' }, input, deps)).rejects.toMatchObject({ code: 'permission-denied' });
  expect(queried).toBe(false);
  await expect(listAdminBookingPayments(store, auth, input, deps)).rejects.toMatchObject({ code: 'permission-denied' });
  expect(store.batches.every(paths => paths.every(p => !p.includes('/bookings/')))).toBe(true);
});
it('batches assigned-branch reads on every Booking scope recheck without changing branch order', async () => {
  const store = new ReadProbeStore();
  for (const [p, d] of Object.entries(bookingSeeds)) store.documents.set(p, structuredClone(d));
  store.documents.get('orgs/org-1/members/coach-1')!.branchIds = ['branch-2', 'branch-1'];
  store.documents.set('orgs/org-1/branches/branch-2', { status: 'active' });
  const result = await getBookingListService(store, { uid: 'coach-1', token: { email_verified: true } },
    { schemaVersion: 1, organizationId: 'org-1' }, { read: async q => { expect(q.branchIds).toEqual(['branch-1', 'branch-2']); return []; } }, () => now);
  expect(result.records).toEqual([]);
  expect(store.batches.filter(b => b.includes('orgs/org-1/branches/branch-1'))).toHaveLength(3);
  expect(store.singles.some(p => p.includes('/branches/'))).toBe(false);
  expect(store.singles.some(p => p.startsWith('users/'))).toBe(false);
  expect(store.readRpcs).toBeLessThanOrEqual(6);
});
it('reads the Coach self-scope once and batches availability branches plus roster/days in the same transaction', async () => {
  const store = new ReadProbeStore();
  for (const [p, d] of Object.entries(availabilitySeeds())) store.documents.set(p, structuredClone(d));
  const before = structuredClone([...store.documents]);
  const result = await getCoachAvailabilityService(store, availabilityAuth('coach'), availabilityRead(), () => availabilityNow);
  expect(result.assignedBranchIds).toEqual(['main', 'other']);
  expect(result.days).toHaveLength(7);
  const reads = [...store.singles, ...store.batches.flat()];
  expect(reads.filter(p => p === 'users/coach')).toHaveLength(1);
  expect(reads.filter(p => p === 'orgs/b2-org/members/coach')).toHaveLength(1);
  expect(store.readRpcs).toBeLessThanOrEqual(2);
  expect(new Set(reads).size).toBe(reads.length);
  expect([...store.documents]).toEqual(before);
});
it('overlaps independent Membership Auth/Firestore checks but gates catalogue/history reads on both', async () => {
  const store = new ReadProbeStore();
  for (const [p, d] of Object.entries(bookingSeeds)) store.documents.set(p, structuredClone(d));
  let overlapped = false, identityChecked = false;
  const reader = { plans: async () => { expect(identityChecked).toBe(true); return []; }, payments: async () => { expect(identityChecked).toBe(true); return []; } };
  const result = await membershipOverview(store, { uid: 'member-1', token: { email_verified: true } },
    { schemaVersion: 1, organizationId: 'org-1' }, reader, () => now, async () => {
      overlapped = store.activeTransactions > 0; identityChecked = true;
      return { exists: true, disabled: false, emailVerified: true };
    });
  expect(overlapped).toBe(true);
  expect(result.entitlement).toMatchObject({ effectiveTier: 'free', paidExpiresAtMillis: null });
});
