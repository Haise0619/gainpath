import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { cancelBookingHoldService, expireBookingHoldService } from '../src/modules/coaching/booking-lifecycle-service';
import { runBookingExpiryBatch } from '../src/modules/coaching/booking-expiry-worker';
import { getBookingListService } from '../src/modules/coaching/booking-list-service';
import { FirestoreBookingQueryReader } from '../src/modules/coaching/booking-query-reader';
import { keyOf } from '../src/platform/idempotency';
import { command, seeds, now, eligibleCoach } from '../test/booking-fixture';
let app: App, db: Firestore, id: string;
const root = 'orgs/org-1';
const auth = (uid = 'member-1') => ({ uid, token: { email_verified: true } });
const store = () => new FirestoreStore(db);
const cancel = (clock: number, requestId = 'cancel') => cancelBookingHoldService(store(), auth(), { schemaVersion: 1, organizationId: 'org-1', requestId, bookingId: id }, () => clock);
const job = () => `${root}/jobs/${keyOf('expireBookingHold', id)}`;
beforeAll(() => {
  if (!/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST ?? '')) throw Error('Local emulator required.');
  app = initializeApp({ projectId: 'demo-gainpath' }, 'b4-lifecycle'); db = getFirestore(app);
});
beforeEach(async () => {
  await db.recursiveDelete(db.collection('orgs')); await db.recursiveDelete(db.collection('users'));
  const batch = db.batch(); Object.entries(seeds).forEach(([p, d]) => batch.set(db.doc(p), d));
  batch.set(db.doc('users/admin-1'), { organizationId: 'org-1' });
  batch.set(db.doc(`${root}/members/admin-1`), { organizationId: 'org-1', role: 'admin', status: 'active', branchIds: [] });
  await batch.commit(); id = (await createBookingHoldService(store(), 'member-1', command, eligibleCoach, () => now)).bookingId;
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });
it('real transaction contention converges on one expiry and all roles read the same persisted terminal ID', async () => {
  await Promise.all([cancel(now + 900000), expireBookingHoldService(store(), job(), () => now + 900000), cancel(now + 900000)]);
  for (const uid of ['member-1', 'coach-1', 'admin-1']) {
    const page = await getBookingListService(store(), auth(uid), { schemaVersion: 1, organizationId: 'org-1', ...(uid === 'admin-1' ? { coachId: 'coach-1' } : {}) }, new FirestoreBookingQueryReader(db), () => now + 900000);
    expect(page.records[0]).toMatchObject({ bookingId: id, status: 'expired', resolution: 'hold_expired', resolvedAtMillis: now + 900000 });
    expect(page.records[0]).not.toHaveProperty('createdBy');
  }
  expect((await db.doc(job()).get()).data()?.attempts).toBe(1);
});
it('cancellation and replacement allocation serialize without releasing the replacement', async () => {
  await Promise.all([cancel(now + 1), cancel(now + 1)]);
  const next = await createBookingHoldService(store(), 'member-1', { ...command, requestId: 'next' }, eligibleCoach, () => now + 2);
  await expireBookingHoldService(store(), job(), () => now + 900000);
  const locks = await db.collection(`${root}/slotLocks`).get();
  expect(locks.docs.every(d => d.data().bookingId === next.bookingId)).toBe(true);
  expect((await db.doc(`${root}/bookingDays/${keyOf('member-1', '2026-10-02')}`).get()).data()?.reservations).toHaveLength(1);
});
it('batch scans only due supported jobs, expires holds, quarantines corrupt ownership, and is repeatable', async () => {
  expect(await runBookingExpiryBatch(db, () => now)).toMatchObject({ scanned: 0 });
  await db.doc(`${root}/jobs/future`).set({ schemaVersion: 1, type: 'expireBookingHold', status: 'pending', dueAtMillis: now + 9999999 });
  await db.doc(`${root}/jobs/corrupt`).set({ schemaVersion: 1, type: 'expireBookingHold', bookingId: 'missing', status: 'pending', dueAtMillis: now, attempts: 0 });
  expect(await runBookingExpiryBatch(db, () => now + 900000)).toEqual({ scanned: 2, processed: 1, blocked: 1, retry: 0 });
  expect((await db.doc(`${root}/bookings/${id}`).get()).data()?.status).toBe('expired');
  expect((await db.doc(`${root}/jobs/corrupt`).get()).data()).toMatchObject({ status: 'blocked', failureCode: 'authorized_review_required' });
  expect(await runBookingExpiryBatch(db, () => now + 900001)).toMatchObject({ scanned: 0 });
});
