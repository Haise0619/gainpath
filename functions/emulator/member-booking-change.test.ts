import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { memberBookingChange } from '../src/modules/coaching/member-booking-change-service';
import { seeds, now, start, command, eligibleCoach } from '../test/booking-fixture';
import { keyOf } from '../src/platform/idempotency';
import { localFirestoreEmulator } from './loopback-emulator';

const projectId = 'demo-module7-uat';
const emulator = localFirestoreEmulator();
let app: App, db: Firestore, id: string;
const auth = { uid: 'member-1', token: { email_verified: true } };
const store = () => new FirestoreStore(db);
const change = (action: string, requestId: string, target?: number) => memberBookingChange(store(), auth, {
  schemaVersion: 1, organizationId: 'org-1', bookingId: id, action, requestId,
  expectedStartAtMillis: start, reason: 'Synthetic emulator test',
  ...(target === undefined ? {} : { newStartAtMillis: target }),
}, eligibleCoach, () => now);
beforeAll(() => {
  app = initializeApp({ projectId }, 'module7-changes'); db = getFirestore(app);
});
beforeEach(async () => {
  const response = await fetch(`http://${emulator.authority}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  if (!response.ok) throw Error('Could not clear isolated fixture database.');
  const batch = db.batch();
  Object.entries(seeds).forEach(([p, d]) => batch.set(db.doc(p), d));
  batch.set(db.doc('users/member-2'), { organizationId: 'org-1' });
  batch.set(db.doc('orgs/org-1/members/member-2'), { organizationId: 'org-1', role: 'member', status: 'active', branchIds: ['branch-1'] });
  batch.set(db.doc('orgs/org-1/coaches/coach-1'), { status: 'published', branchIds: ['branch-1'], certificationVerified: true, approvedCertificationCount: 1 });
  batch.set(db.doc('orgs/org-1/coachProfiles/coach-1/certificationState/current'), { certificationVerified: true, approvedCount: 1 });
  await batch.commit();
  id = (await createBookingHoldService(store(), auth.uid, command, eligibleCoach, () => now)).bookingId;
  const confirm = db.batch();
  confirm.update(db.doc(`orgs/org-1/bookings/${id}`), { status: 'confirmed' });
  for (let slot = start; slot < start + 3600000; slot += 1800000) confirm.update(db.doc(`orgs/org-1/slotLocks/${keyOf('coach-1', slot)}`), { status: 'confirmed' });
  confirm.update(db.doc(`orgs/org-1/bookingDays/${keyOf(auth.uid, '2026-10-02')}`), { reservations: [{ bookingId: id, status: 'confirmed', expiresAtMillis: now + 900000 }] });
  confirm.set(db.doc(`orgs/org-1/transactions/${id}`), { schemaVersion: 1, type: 'CoachingBooking', environment: 'sandbox', provider: 'billplz', organizationId: 'org-1', bookingId: id, memberId: auth.uid, coachId: 'coach-1', branchId: 'branch-1', durationMinutes: 60, currency: 'MYR', amountMinor: 10000, paymentStatus: 'cleared', fulfilmentStatus: 'confirmed' });
  await confirm.commit();
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });
it('serializes replacement against another Member taking the target', async () => {
  const target = start + 2 * 3600000;
  const results = await Promise.allSettled([
    change('reschedule', 'replacement', target),
    createBookingHoldService(store(), 'member-2', { ...command, memberId: 'member-2', requestId: 'competing', startAtMillis: target }, eligibleCoach, () => now),
  ]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  const booking = (await db.doc(`orgs/org-1/bookings/${id}`).get()).data()!;
  const targetLock = (await db.doc(`orgs/org-1/slotLocks/${keyOf('coach-1', target)}`).get()).data()!;
  if (results[0].status === 'fulfilled') expect(targetLock).toMatchObject({ bookingId: id, status: 'confirmed' });
  else {
    expect(booking.startAtMillis).toBe(start);
    expect((await db.doc(`orgs/org-1/slotLocks/${keyOf('coach-1', start)}`).get()).data()).toMatchObject({ bookingId: id, status: 'confirmed' });
    expect(targetLock.bookingId).not.toBe(id);
  }
});
it('allows only one concurrent edit of the displayed baseline', async () => {
  const results = await Promise.allSettled([
    change('reschedule', 'first', start + 3600000),
    change('reschedule', 'second', start + 2 * 3600000),
  ]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  const booking = (await db.doc(`orgs/org-1/bookings/${id}`).get()).data()!;
  const locks = (await db.collection('orgs/org-1/slotLocks').get()).docs.map(d => d.data()).filter(d => d.bookingId === id && d.status === 'confirmed');
  expect(locks).toHaveLength(2);
  expect((await db.doc(`orgs/org-1/bookingDays/${keyOf(auth.uid, booking.localDate)}`).get()).data()?.reservations).toHaveLength(1);
  expect((await db.doc(`orgs/org-1/transactions/${id}`).get()).data()).toMatchObject({ amountMinor: 10000, paymentStatus: 'cleared', fulfilmentStatus: 'confirmed' });
});
it('serializes cancellation against rescheduling without orphan reservations', async () => {
  const results = await Promise.allSettled([change('cancel', 'cancel'), change('reschedule', 'move', start + 2 * 3600000)]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  const booking = (await db.doc(`orgs/org-1/bookings/${id}`).get()).data()!;
  const locks = (await db.collection('orgs/org-1/slotLocks').get()).docs.map(d => d.data()).filter(d => d.bookingId === id && d.status === 'confirmed');
  const reservations = (await db.doc(`orgs/org-1/bookingDays/${keyOf(auth.uid, booking.localDate)}`).get()).data()?.reservations;
  expect(locks).toHaveLength(booking.status === 'cancelled' ? 0 : 2);
  expect(reservations).toHaveLength(booking.status === 'cancelled' ? 0 : 1);
});
it('serializes the same Member taking overlapping times with different Coaches when multiple sessions are allowed', async () => {
  const batch=db.batch();
  for(const [path,data] of Object.entries(seeds))if(path.includes('coach-1'))batch.set(db.doc(path.replaceAll('coach-1','coach-2')),structuredClone(data));
  batch.update(db.doc('orgs/org-1/settings/booking'),{maxActiveBookingsPerMemberPerDay:32});
  await batch.commit();
  const target=start+2*3600000;
  const results=await Promise.allSettled(['coach-1','coach-2'].map(coachId=>createBookingHoldService(store(),auth.uid,{...command,coachId,requestId:'same-member-'+coachId,startAtMillis:target},eligibleCoach,()=>now)));
  expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);
  expect((await db.doc(`orgs/org-1/bookingDays/${keyOf(auth.uid,'2026-10-02')}`).get()).data()?.reservations).toHaveLength(2);
  expect((await db.collection('orgs/org-1/bookings').get()).size).toBe(2);
});
