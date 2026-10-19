import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { bookingCommunication } from '../src/modules/coaching/booking-communication-service';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { seeds, command, now, eligibleCoach } from '../test/booking-fixture';

let app: App, db: Firestore, id: string;
beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required; never target production.');
  app = initializeApp({ projectId: 'demo-gainpath' }, 'booking-communication'); db = getFirestore(app);
});
beforeEach(async () => {
  await db.recursiveDelete(db.collection('orgs')); await db.recursiveDelete(db.collection('users'));
  const batch = db.batch(); Object.entries(seeds).forEach(([p,d]) => batch.set(db.doc(p), d)); await batch.commit();
  id = (await createBookingHoldService(new FirestoreStore(db), 'member-1', command, eligibleCoach, () => now)).bookingId;
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });
const call = (uid: string, fields = {}) => bookingCommunication(new FirestoreStore(db), { uid, token: { email_verified: true } }, { schemaVersion: 1, organizationId: 'org-1', bookingId: id, ...fields }, () => now);
it('serializes concurrent duplicate sends and preserves booking/lock documents byte-for-byte', async () => {
  const paths = [`orgs/org-1/bookings/${id}`, ...((await db.collection('orgs/org-1/slotLocks').get()).docs.map(d => d.ref.path))];
  const before = await Promise.all(paths.map(async p => (await db.doc(p).get()).data()));
  await Promise.all(Array.from({ length: 5 }, () => call('member-1', { requestId: 'same', text: 'Preparation question' })));
  expect((await call('coach-1')).messages).toHaveLength(1);
  await call('coach-1', { requestId: 'answer', text: 'Bring water' });
  expect((await call('member-1')).messages.map(m => m.sequence)).toEqual([1,2]);
  expect(await Promise.all(paths.map(async p => (await db.doc(p).get()).data()))).toEqual(before);
});
it('denies other roles and revoked memberships without writing messages', async () => {
  await expect(call('staff-1')).rejects.toMatchObject({ code: 'permission-denied' });
  await db.doc('orgs/org-1/members/coach-1').update({ status: 'inactive' });
  await expect(call('coach-1', { requestId: 'x', text: 'Forbidden' })).rejects.toMatchObject({ code: 'permission-denied' });
  expect((await db.collection(`orgs/org-1/bookings/${id}/messages`).get()).empty).toBe(true);
});
