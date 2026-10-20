import { readFileSync } from 'node:fs';
import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertFails, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { getCoachRosterService, saveCoachRosterService, getCoachAvailabilityService } from '../src/modules/coaching/coach-availability-service';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { eligibleCoach } from '../test/booking-fixture';
import { root, org, now, date, start, auth, seeds, read } from '../test/coach-availability.fixture';
import { weekly, rosterSave } from '../test/coach-roster.fixture';

let app: App, db: Firestore, rules: RulesTestEnvironment;
const parent = `${root}/coachAvailability/coach`;
const hold = (memberId: string, at: number) => ({ schemaVersion: 1, organizationId: org, requestId: `hold-${memberId}`, memberId, coachId: 'coach', branchId: 'main', startAtMillis: at, durationMinutes: 60 });
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Isolated emulator required.');
  app = initializeApp({ projectId: 'demo-gainpath' }, 'module10-roster'); db = getFirestore(app);
  rules = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: { rules: readFileSync(process.env.MODULE10_RULES_FILE ?? '../firebase/firestore.rules', 'utf8') } });
});
beforeEach(async () => {
  await rules.clearFirestore(); const batch = db.batch(); Object.entries(seeds()).forEach(([p, v]) => batch.set(db.doc(p), v));
  batch.set(db.doc('users/member2'), { organizationId: org });
  batch.set(db.doc(`${root}/members/member2`), { organizationId: org, status: 'active', role: 'member', branchIds: ['main'] });
  await batch.commit();
});
afterAll(async () => { await rules?.cleanup(); await db?.terminate(); if (app) await deleteApp(app); });
const store = () => new FirestoreStore(db);
it('serializes capacity across different members taking different slots without extra accounting', async () => {
  await saveCoachRosterService(store(), auth('coach'), { ...rosterSave(), weeklyAvailability: { ...weekly, dailyCapacityHours: 1 } }, () => now);
  const result = await Promise.allSettled([
    createBookingHoldService(store(), 'member', hold('member', start), eligibleCoach, () => now),
    createBookingHoldService(store(), 'member2', hold('member2', start + 3600000), eligibleCoach, () => now),
  ]);
  expect(result.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  const rejected = result.find(r => r.status === 'rejected') as PromiseRejectedResult;
  expect(rejected.reason).toMatchObject({ code: 'resource-exhausted' });
  expect((await db.collection(`${root}/slotLocks`).get()).size).toBe(2);
  expect((await db.collection(`${root}/bookings`).get()).size).toBe(1);
});
it('serializes exception creation against an overlapping new hold', async () => {
  await saveCoachRosterService(store(), auth('coach'), rosterSave(), () => now);
  const result = await Promise.allSettled([
    createBookingHoldService(store(), 'member', hold('member', start), eligibleCoach, () => now),
    saveCoachRosterService(store(), auth('coach'), rosterSave('block', 1, [{ id: 'lunch', type: 'breakTime', reason: '', startAtMillis: start, endAtMillis: start + 1800000 }]), () => now),
  ]);
  expect(result.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  const roster = await getCoachRosterService(store(), auth('coach'), { schemaVersion: 1, organizationId: org, coachId: 'coach' }, () => now);
  const bookings = await db.collection(`${root}/bookings`).get();
  expect(bookings.size + roster.exceptions.length).toBe(1);
});
it('pins the real old dated baseline when a weekly edit races an allocation', async () => {
  await saveCoachRosterService(store(), auth('coach'), rosterSave(), () => now);
  const result = await Promise.allSettled([
    createBookingHoldService(store(), 'member', hold('member', start), eligibleCoach, () => now),
    saveCoachRosterService(store(), auth('coach'), { ...rosterSave('inactive', 1), weeklyAvailability: { ...weekly, schedule: weekly.schedule.map(d => ({ ...d, isActive: false })) } }, () => now),
  ]);
  expect(result[1].status).toBe('fulfilled');
  const booked = !(await db.collection(`${root}/bookings`).get()).empty;
  const view = await getCoachAvailabilityService(store(), auth('member'), read(), () => now);
  if (booked) {
    expect((await db.doc(`${parent}/days/${date}`).get()).data()?.windows).toEqual([{ branchId: 'main', startAtMillis: start, endAtMillis: start + 14400000 }]);
    expect(view.days.find(d => d.localDate === date)?.windows).toHaveLength(1);
  } else expect(view.days.find(d => d.localDate === date)?.windows).toEqual([]);
});
it('protects the private aggregate from direct client reads and writes', async () => {
  await saveCoachRosterService(store(), auth('coach'), rosterSave(), () => now);
  for (const uid of ['coach', 'member', 'admin']) {
    const client = rules.authenticatedContext(uid, { email_verified: true }).firestore();
    await assertFails(getDoc(doc(client, parent)));
    await assertFails(setDoc(doc(client, parent), { schemaVersion: 1 }));
  }
});
