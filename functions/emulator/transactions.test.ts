import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { receivePaymentEvent } from '../src/modules/commerce/payment-ingress';
import { command, now, start, seeds } from '../test/booking-fixture';

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
  const batch = db.batch(); Object.entries(seeds).forEach(([p, data]) => batch.set(db.doc(p), data)); await batch.commit();
});
const hold = (input = command, time = now) => createBookingHoldService(new FirestoreStore(db), 'member-1', input, () => time);

it('replaces existing expired locks using the real Firestore adapter', async () => {
  const first = await hold();
  const second = await hold({ ...command, requestId: 'request-2' }, first.holdExpiresAtMillis);
  const locks = await db.collection('orgs/org-1/slotLocks').get();
  expect(locks.size).toBe(2);
  expect(locks.docs.every(d => d.data().bookingId === second.bookingId)).toBe(true);
});
it('serializes competing overlapping holds from different members', async () => {
  await db.doc('orgs/org-1/members/member-2').set({ role: 'member', status: 'active', branchIds: ['branch-1'] });
  const results = await Promise.allSettled([hold(), createBookingHoldService(new FirestoreStore(db), 'member-2',
    { ...command, memberId: 'member-2', requestId: 'request-2', startAtMillis: start + 1800000 }, () => now)]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect((await db.collection('orgs/org-1/bookings').get()).size).toBe(1);
});
it('serializes the daily cap across disjoint slots', async () => {
  const results = await Promise.allSettled([hold(), hold({ ...command, requestId: 'request-2', startAtMillis: start + 3600000 })]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect((await db.collection('orgs/org-1/bookings').get()).size).toBe(1);
  expect((await db.collection('orgs/org-1/jobs').get()).size).toBe(1);
});
it('deduplicates concurrent retries with one receipt and booking', async () => {
  const [a, b] = await Promise.all([hold(), hold()]);
  expect(a).toEqual(b);
  expect((await db.collection('orgs/org-1/commandReceipts').get()).size).toBe(1);
});
it('persists verified payment payloads at a valid Firestore document path once', async () => {
  const verifier = { provider: 'test', verify: async () => ({ provider: 'test', eventId: 'evt/1', billId: 'b1',
    amountMinor: 500, currency: 'MYR', status: 'settled' as const }) };
  const store = new FirestoreStore(db); const raw = Buffer.from('provider-payload');
  const [a, b] = await Promise.all([receivePaymentEvent(store, verifier, raw, {}), receivePaymentEvent(store, verifier, raw, {})]);
  expect(a).toEqual(b);
  const inbox = await db.collection('system/paymentIngress/events').get();
  expect(inbox.size).toBe(1); expect(inbox.docs[0].data().rawBodyBase64).toBe(raw.toString('base64'));
  expect(inbox.docs[0].data().event.billId).toBe('b1');
});
