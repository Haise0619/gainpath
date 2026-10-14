import { readFileSync } from 'node:fs';
import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertFails, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import type { DocumentStore } from '../src/platform/firestore/store';
import { getCoachAvailabilityService, saveCoachAvailabilityDayService } from '../src/modules/coaching/coach-availability-service';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { root, org, now, date, start, auth, windows, seeds, read, save } from '../test/coach-availability.fixture';

let app: App, db: Firestore, rules: RulesTestEnvironment;
const path = `${root}/coachAvailability/coach/days/${date}`;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Isolated emulator required.');
  app = initializeApp({ projectId: 'demo-gainpath' }, 'b2-availability'); db = getFirestore(app);
  rules = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: { rules: readFileSync('../firebase/firestore.rules', 'utf8') } });
});
beforeEach(async () => { await rules.clearFirestore(); const batch = db.batch(); Object.entries(seeds()).forEach(([p, v]) => batch.set(db.doc(p), v)); await batch.commit(); });
afterAll(async () => { await rules?.cleanup(); await db?.terminate(); if (app) await deleteApp(app); });
const store = () => new FirestoreStore(db);
it('persists Coach CRUD and the same scoped Member/Admin schedule; direct clients remain denied', async () => {
  await saveCoachAvailabilityDayService(store(), auth('coach'), save(), () => now);
  expect((await getCoachAvailabilityService(store(), auth('member'), read(), () => now)).days.find(d => d.localDate === date)?.windows).toEqual(windows);
  expect((await getCoachAvailabilityService(store(), auth('admin'), read(), () => now)).days.find(d => d.localDate === date)?.windows).toEqual(windows);
  for (const uid of ['coach', 'member', 'admin']) {
    const client = rules.authenticatedContext(uid, { email_verified: true }).firestore();
    await assertFails(getDoc(doc(client, path))); await assertFails(setDoc(doc(client, path), { schemaVersion: 1, windows: [] }));
  }
  await saveCoachAvailabilityDayService(store(), auth('coach'), save('edit', 1, [{ ...windows[0], endAtMillis: start + 7200000 }]), () => now + 1);
  await saveCoachAvailabilityDayService(store(), auth('coach'), save('remove', 2, []), () => now + 2);
  expect((await db.doc(path).get()).data()).toMatchObject({ revision: 3, windows: [], createdAtMillis: now });
  for (const collection of ['bookings', 'slotLocks', 'jobs', 'workoutSessions', 'workoutConsents']) expect((await db.collection(`${root}/${collection}`).get()).empty).toBe(true);
});
it('serializes concurrent immutable-baseline edits with one winner', async () => {
  await saveCoachAvailabilityDayService(store(), auth('coach'), save(), () => now);
  const result = await Promise.allSettled([3600000, 7200000].map((extra, i) => saveCoachAvailabilityDayService(store(), auth('coach'), save(`edit-${i}`, 1, [{ ...windows[0], endAtMillis: start + 3600000 + extra }]), () => now)));
  expect(result.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect((await db.doc(path).get()).data()?.revision).toBe(2);
});
it('serializes concurrent hold/removal so incompatible schedule and reservation cannot both win', async () => {
  await saveCoachAvailabilityDayService(store(), auth('coach'), save(), () => now);
  const result = await Promise.allSettled([
    createBookingHoldService(store(), 'member', { schemaVersion: 1, requestId: 'hold', organizationId: org, branchId: 'main', coachId: 'coach', memberId: 'member', startAtMillis: start, durationMinutes: 60 }, () => now),
    saveCoachAvailabilityDayService(store(), auth('coach'), save('remove', 1, []), () => now),
  ]);
  expect(result.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  const persisted = (await db.doc(path).get()).data()!;
  const locks = await db.collection(`${root}/slotLocks`).get();
  if (!locks.empty) expect(persisted.windows).toEqual(windows);
  else expect(persisted.windows).toEqual([]);
});
it('callback retry never adopts a changed revision; scope drift prevents receipt replay', async () => {
  await saveCoachAvailabilityDayService(store(), auth('coach'), save(), () => now);
  const retry: DocumentStore = { transact: async work => {
    await work({ get: async p => (await db.doc(p).get()).data(), create: () => {}, set: () => {} });
    await db.doc(path).update({ revision: 2 });
    return store().transact(work);
  } };
  await expect(saveCoachAvailabilityDayService(retry, auth('coach'), save('retry', 1, []), () => now)).rejects.toMatchObject({ code: 'aborted' });
  expect((await db.doc(path).get()).data()?.windows).toEqual(windows);
  await db.doc('users/coach').update({ organizationId: 'elsewhere' });
  await expect(saveCoachAvailabilityDayService(store(), auth('coach'), save(), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
});
