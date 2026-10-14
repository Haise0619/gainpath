import { readFileSync } from 'node:fs';
import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, documentId, getDoc, getDocs, limit, orderBy, query, setDoc, startAt, where } from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import type { DocumentStore } from '../src/platform/firestore/store';
import { saveCoachProfile, setCoachDirectoryStatus } from '../src/modules/coaching/coach-profile-service';

let app: App, db: Firestore, env: RulesTestEnvironment;
const root = 'orgs/b1-org', org = 'b1-org';
const fields = { displayName: 'Fixture Coach', specialty: 'Strength', bio: 'Draft professional bio', specializationTags: ['Strength'], yearsExperience: null };
const actor = (uid: string) => ({ uid, token: { email_verified: true } });
const identity = async () => ({ exists: true, disabled: false, emailVerified: true }); // injected synthetic Auth observation, not live Auth evidence
const save = (requestId: string, expectedRevision = 0, patch: object = fields) => ({ schemaVersion: 1, organizationId: org, requestId, expectedRevision, patch });
const pub = (requestId: string, action = 'publish', expectedPublicRevision = 0) => ({ schemaVersion: 1, organizationId: org, coachId: 'coach', requestId, action, expectedPublicRevision, ...(action === 'publish' ? { expectedProfileRevision: 1, expectedCoachBranchIds: ['main'] } : {}) });
const client = (uid: string, verified = true) => env.authenticatedContext(uid, { email_verified: verified }).firestore();
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Isolated Firestore emulator required.');
  app = initializeApp({ projectId: 'demo-gainpath' }, 'b1-coach-directory'); db = getFirestore(app);
  env = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: { rules: readFileSync('../firebase/firestore.rules', 'utf8') } });
});
beforeEach(async () => {
  await env.clearFirestore();
  const batch = db.batch(); batch.set(db.doc(root), { status: 'active' }); batch.set(db.doc(`${root}/branches/main`), { status: 'active' });
  for (const [uid, role] of [['coach', 'coach'], ['other-coach', 'coach'], ['admin', 'admin'], ['staff', 'staff'], ['member', 'member'], ['cross-org', 'member']]) {
    batch.set(db.doc(`users/${uid}`), { organizationId: uid === 'cross-org' ? 'elsewhere' : org });
    batch.set(db.doc(`${root}/members/${uid}`), { organizationId: org, role, status: 'active', branchIds: ['main'] });
  }
  await batch.commit();
});
afterAll(async () => { await env?.cleanup(); await db?.terminate(); if (app) await deleteApp(app); });
it('Coach saves → Admin reviews/publishes → Member reads; draft edits stay private and public-only deactivation withdraws', async () => {
  const store = new FirestoreStore(db), coach = client('coach'), admin = client('admin'), member = client('member');
  await assertSucceeds(getDoc(doc(coach, `${root}/coachProfiles/coach`))); // missing owner draft supports creation
  await assertSucceeds(getDoc(doc(coach, `${root}/coaches/coach`))); // missing own projection is not an error
  await saveCoachProfile(store, actor('coach'), save('create'));
  expect((await getDoc(doc(coach, `${root}/coachProfiles/coach`))).data()?.revision).toBe(1);
  await assertFails(getDoc(doc(member, `${root}/coachProfiles/coach`)));
  expect((await getDoc(doc(admin, `${root}/coachProfiles/coach`))).data()?.displayName).toBe(fields.displayName);
  await setCoachDirectoryStatus(store, actor('admin'), pub('publish'), identity);
  const base = collection(member, `${root}/coaches`), read = () => getDocs(query(base, where('status', '==', 'published'), orderBy(documentId()), limit(21)));
  const page = await read(); expect(page.docs.map(d => d.id)).toEqual(['coach']);
  expect(page.docs[0].data()).toMatchObject({ ...fields, branchIds: ['main'], status: 'published', sourceRevision: 1 });
  await saveCoachProfile(store, actor('coach'), save('edit', 1, { bio: 'Pending edit' }));
  expect((await read()).docs[0].data().bio).toBe(fields.bio);
  await db.doc(`${root}/coachProfiles/coach`).delete(); await db.doc(`${root}/members/coach`).delete();
  expect((await getDocs(query(collection(admin, `${root}/coaches`), orderBy(documentId()), limit(21)))).docs[0].id).toBe('coach');
  await setCoachDirectoryStatus(store, actor('admin'), pub('withdraw', 'deactivate', 1), identity);
  expect((await read()).empty).toBe(true);
  const exact = await getDocs(query(base, where('status', '==', 'published'), orderBy(documentId()), startAt('coach'), limit(1)));
  expect(exact.empty).toBe(true);
  await assertFails(getDoc(doc(member, `${root}/coaches/coach`)));
  expect((await db.collection(`${root}/bookings`).get()).empty).toBe(true);
  expect((await db.collection(`${root}/workoutSessions`).get()).empty).toBe(true);
});
it('denies other-role drafts/direct writes, stale assignments, unverification and former-Coach inactive access', async () => {
  const store = new FirestoreStore(db);
  await saveCoachProfile(store, actor('coach'), save('create'));
  await setCoachDirectoryStatus(store, actor('admin'), pub('publish'), identity);
  for (const uid of ['member', 'other-coach', 'staff', 'cross-org']) await assertFails(getDoc(doc(client(uid), `${root}/coachProfiles/coach`)));
  for (const uid of ['coach', 'admin', 'member']) for (const c of ['coachProfiles', 'coaches']) await assertFails(setDoc(doc(client(uid), `${root}/${c}/coach`), fields));
  await assertFails(getDoc(doc(client('cross-org'), `${root}/coaches/coach`)));
  await assertFails(getDoc(doc(client('member', false), `${root}/coaches/coach`)));
  await assertFails(getDocs(collection(client('member'), `${root}/coaches`)));
  await db.doc('users/coach').update({ organizationId: 'elsewhere' });
  await assertFails(getDoc(doc(client('coach'), `${root}/coachProfiles/coach`)));
  await db.doc('users/admin').update({ organizationId: 'elsewhere' });
  await assertFails(getDocs(collection(client('admin'), `${root}/coachProfiles`)));
  await db.doc('users/admin').update({ organizationId: org }); await db.doc('users/coach').update({ organizationId: org });
  await setCoachDirectoryStatus(store, actor('admin'), pub('withdraw', 'deactivate', 1), identity);
  await db.doc(`${root}/members/coach`).update({ role: 'member' });
  await assertFails(getDoc(doc(client('coach'), `${root}/coaches/coach`)));
});
it('real contention and a deterministic callback retry keep the original revision', async () => {
  const store = new FirestoreStore(db);
  await saveCoachProfile(store, actor('coach'), save('create'));
  const outcomes = await Promise.allSettled(['first', 'second'].map(id => saveCoachProfile(store, actor('coach'), save(id, 1, { bio: id }))));
  expect(outcomes.filter(o => o.status === 'fulfilled')).toHaveLength(1);
  expect((outcomes.find(o => o.status === 'rejected') as PromiseRejectedResult).reason.code).toBe('aborted');
  await db.doc(`${root}/coachProfiles/coach`).update({ privateNote: 'preserved' });
  let callbacks = 0;
  // Discard a successful callback's writes, change persisted state, then run
  // again. This is a deterministic retry simulation; the contention above is
  // actual Firestore. Awaiting an external writer inside a pessimistic server
  // transaction would deadlock its document lock and test the harness instead.
  const retryStore: DocumentStore = { transact: async work => {
    callbacks++;
    await work({ get: async path => (await db.doc(path).get()).data(), create: () => {}, set: () => {} });
    await db.doc(`${root}/coachProfiles/coach`).update({ revision: 3, bio: 'Concurrent external edit' });
    return store.transact(tx => { callbacks++; return work(tx); });
  } };
  await expect(saveCoachProfile(retryStore, actor('coach'), save('retry', 2, { bio: 'Stale intent' }))).rejects.toMatchObject({ code: 'aborted' });
  expect(callbacks).toBeGreaterThan(1);
  expect((await db.doc(`${root}/coachProfiles/coach`).get()).data()).toMatchObject({ revision: 3, bio: 'Concurrent external edit', privateNote: 'preserved' });
});
