import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { getAdminBookingPayment, listAdminBookingPayments } from '../src/modules/commerce/booking-payment-admin';
import { getCoachCertifications } from '../src/modules/coaching/coach-certification-service';
import { getCoachPublishedPhoto } from '../src/modules/coaching/coach-photo-service';
import { fixture, auth, input, org, certificationId } from '../test/read-batch2-fixture';
import { localFirestoreEmulator } from './loopback-emulator';

const emulator = localFirestoreEmulator(), projectId = 'demo-gainpath-read-batch2';
let app: App, db: Firestore;
beforeAll(() => { app = initializeApp({ projectId }); db = getFirestore(app); });
beforeEach(async () => {
  await fetch(`http://${emulator.authority}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  const data = fixture(), batch = db.batch();
  for (const [path, value] of data.store.documents) batch.set(db.doc(path), value);
  await batch.commit();
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });

it('reads real payment snapshots and event projections without writing or invoking a provider', async () => {
  const { deps, rows } = fixture(), store = new FirestoreStore(db);
  const before = (await db.collection(`orgs/${org}/transactions`).get()).docs.map(d => d.data());
  const page = await listAdminBookingPayments(store, auth, input, deps);
  expect(page.records.map(r => r.bookingId)).toEqual(rows.slice(0, 20).map(r => r.id));
  expect(page.nextAfterId).toBe(rows[19].id);
  const detail = await getAdminBookingPayment(store, auth, { ...input, bookingId: rows[0].id }, deps);
  expect(detail.events).toEqual([{ id: 'event', event: 'fixture', atMillis: 1 }]);
  expect((await db.collection(`orgs/${org}/transactions`).get()).docs.map(d => d.data())).toEqual(before);
  deps.reader.events = async () => { await db.doc(`orgs/${org}/members/admin`).update({ role: 'member' }); return []; };
  await expect(getAdminBookingPayment(store, auth, { ...input, bookingId: rows[0].id }, deps)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('uses real getAll for certification pages and preserves history order, missing entries and scope denial', async () => {
  const store = new FirestoreStore(db), query = { ...input, coachId: 'coach' };
  expect((await getCoachCertifications(store, auth, query)).certifications).toHaveLength(20);
  await db.doc(`orgs/${org}/coachProfiles/coach/certifications/${certificationId}/history/19`).delete();
  const result = await getCoachCertifications(store, auth, { ...query, certificationId });
  expect(result.certifications[0].history.map((h: any) => h.revision)).toEqual([20, ...Array.from({ length: 18 }, (_, i) => 18 - i)]);
  await expect(getCoachCertifications(store, { ...auth, uid: 'member' }, query)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('rechecks photo access and revision after external download on fresh Firestore snapshots', async () => {
  const store = new FirestoreStore(db), session = { ...auth, uid: 'member' }, query = { ...input, coachId: 'coach' };
  const image = { contentType: 'image/png', bytesBase64: 'fixture' };
  expect((await getCoachPublishedPhoto(store, session, query, async () => image)).bytesBase64).toBe('fixture');
  await expect(getCoachPublishedPhoto(store, session, query, async () => {
    await db.doc(`orgs/${org}/coaches/coach`).update({ revision: 2 }); return image;
  })).rejects.toMatchObject({ code: 'aborted' });
  await expect(getCoachPublishedPhoto(store, session, query, async () => {
    await db.doc(`orgs/${org}/members/member`).update({ status: 'inactive' }); return image;
  })).rejects.toMatchObject({ code: 'permission-denied' });
});
