import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { receivePaymentEvent } from '../src/modules/commerce/payment-ingress';
import { command, now, start, seeds, eligibleCoach, paidMemberFixture } from '../test/booking-fixture';
import { getMemberBookingOptionsService } from '../src/modules/coaching/member-booking-options-service';
import { settleConcurrentEmulatorRequests } from './loopback-emulator';

let app: App;
let db: Firestore;
beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Firestore emulator required; never target a live project.');
  app = initializeApp({ projectId: 'demo-gainpath' }, 'transactions'); db = getFirestore(app);
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });
beforeEach(async () => {
  await db.recursiveDelete(db.collection('orgs'));
  await db.recursiveDelete(db.collection('system'));
  await db.recursiveDelete(db.collection('users'));
  const batch = db.batch(); Object.entries(seeds).forEach(([p, data]) => batch.set(db.doc(p), data)); await batch.commit();
});
const hold = (input = command, time = now) => createBookingHoldService(new FirestoreStore(db), 'member-1', input, eligibleCoach, () => time);

async function seedSecondMember(branchIds: string[]) {
  const batch = db.batch();
  batch.set(db.doc('users/member-2'), { organizationId: 'org-1' });
  batch.set(db.doc('orgs/org-1/members/member-2'), { organizationId: 'org-1', role: 'member', status: 'active', branchIds });
  for (const [path, data] of Object.entries(paidMemberFixture('orgs/org-1', 'org-1', 'member-2', now))) {
    batch.set(db.doc(path), data);
  }
  await batch.commit();
}

it('replaces existing expired locks using the real Firestore adapter', async () => {
  const first = await hold();
  const second = await hold({ ...command, requestId: 'request-2' }, first.holdExpiresAtMillis);
  const locks = await db.collection('orgs/org-1/slotLocks').get();
  expect(locks.size).toBe(2);
  expect(locks.docs.every(d => d.data().bookingId === second.bookingId)).toBe(true);
});
it('serializes competing overlapping holds from different members', async () => {
  await seedSecondMember(['branch-1']);
  const results = await settleConcurrentEmulatorRequests([hold, () => createBookingHoldService(new FirestoreStore(db), 'member-2',
    { ...command, memberId: 'member-2', requestId: 'request-2', startAtMillis: start + 1800000 }, eligibleCoach, () => now)]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect(results.find(r => r.status === 'rejected')).toMatchObject({ reason: { code: 'aborted' } });
  expect((await db.collection('orgs/org-1/bookings').get()).size).toBe(1);
});
it('serializes the daily cap across disjoint slots', async () => {
  const results = await settleConcurrentEmulatorRequests([hold, () => hold({ ...command, requestId: 'request-2', startAtMillis: start + 3600000 })]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect(results.find(r => r.status === 'rejected')).toMatchObject({ reason: { code: 'resource-exhausted' } });
  expect((await db.collection('orgs/org-1/bookings').get()).size).toBe(1);
  expect((await db.collection('orgs/org-1/jobs').get()).size).toBe(1);
});
it('deduplicates concurrent retries with one receipt and booking', async () => {
  const [a, b] = await settleConcurrentEmulatorRequests([hold, hold]);
  expect(a).toMatchObject({ status: 'fulfilled' });
  expect(a).toEqual(b);
  expect((await db.collection('orgs/org-1/commandReceipts').get()).size).toBe(1);
  expect((await db.collection('orgs/org-1/bookings').get()).size).toBe(1);
});
it('serializes same-slot members, rejects a different-branch request, and persists options from those exact locks', async () => {
  await seedSecondMember(['branch-1', 'branch-2']);
  await db.doc('orgs/org-1/branches/branch-2').set({ status: 'active' });
  await db.doc('orgs/org-1/coaches/coach-1').update({ branchIds: ['branch-1', 'branch-2'] });
  await db.doc('orgs/org-1/members/coach-1').update({ branchIds: ['branch-1', 'branch-2'] });
  const store = new FirestoreStore(db);
  const results = await settleConcurrentEmulatorRequests([
    hold,
    () => createBookingHoldService(store, 'member-2', { ...command, memberId: 'member-2', requestId: 'same-slot' }, eligibleCoach, () => now),
    () => createBookingHoldService(store, 'member-2', { ...command, memberId: 'member-2', branchId: 'branch-2', requestId: 'cross-branch' }, eligibleCoach, () => now),
  ]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect(results[2]).toMatchObject({ status: 'rejected', reason: { code: 'failed-precondition' } });
  expect((await db.collection('orgs/org-1/bookings').get()).size).toBe(1);
  expect((await db.collection('orgs/org-1/jobs').get()).size).toBe(1);
  const losingMember = results[0].status === 'fulfilled' ? 'member-2' : 'member-1';
  const options = await getMemberBookingOptionsService(store, { uid: losingMember, token: { email_verified: true } },
    { schemaVersion: 1, organizationId: 'org-1', coachId: 'coach-1', localDate: '2026-10-02', durationMinutes: 60 }, eligibleCoach, () => now);
  expect(options.options[0].startAtMillis).toBe(start + 3600000);
});
it('replays a concurrent committed receipt after Auth lookup failure and rejects actor scope drift', async () => {
  let first: unknown;
  const result = await createBookingHoldService(new FirestoreStore(db), 'member-1', command, async () => {
    first = await hold();
    await db.doc('users/coach-1').update({ organizationId: 'elsewhere' });
    throw Error('Auth temporarily unavailable');
  }, () => now);
  expect(result).toEqual(first);
  expect((await db.collection('orgs/org-1/bookings').get()).size).toBe(1);
  await db.doc('users/member-1').update({ organizationId: 'elsewhere' });
  await expect(hold()).rejects.toMatchObject({ code: 'permission-denied' });
});
it('persists verified payment payloads at a valid Firestore document path once', async () => {
  const verifier = { provider: 'test', verify: async () => ({ provider: 'test', eventId: 'evt/1', billId: 'b1',
    amountMinor: 500, currency: 'MYR', status: 'settled' as const }) };
  const store = new FirestoreStore(db); const raw = Buffer.from('provider-payload');
  const deliver = () => receivePaymentEvent(store, verifier, raw, {});
  const [a, b] = await settleConcurrentEmulatorRequests([deliver, deliver]);
  expect(a).toMatchObject({ status: 'fulfilled' });
  expect(a).toEqual(b);
  const inbox = await db.collection('system/paymentIngress/events').get();
  expect(inbox.size).toBe(1); expect(inbox.docs[0].data().rawBodyBase64).toBe(raw.toString('base64'));
  expect(inbox.docs[0].data().event.billId).toBe('b1');
});
