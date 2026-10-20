import { readFileSync } from 'node:fs';
import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertFails, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, documentId, getDocs, limit, orderBy, query, startAfter, startAt, where } from 'firebase/firestore';
import { afterAll, beforeAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { publishRoutine } from '../src/modules/content/publish-routine';

let app: App, db: Firestore, env: RulesTestEnvironment;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Isolated emulator required; never use a live project.');
  app = initializeApp({ projectId: 'demo-gainpath' }, 'a1-discovery');
  db = getFirestore(app);
  env = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: {
    rules: readFileSync('../firebase/firestore.rules', 'utf8'),
  } });
  await env.clearFirestore();
});
afterAll(async () => { await env?.cleanup(); await db?.terminate(); if (app) await deleteApp(app); });

it('trusted fixture publication -> bounded Member discovery/select-by-ID -> refresh, with scope denial', async () => {
  const org = 'a1-fixture-org';
  const root = `orgs/${org}`;
  const seed: Record<string, Record<string, unknown>> = {
    'users/a1-admin': { organizationId: org },
    [`${root}/members/a1-admin`]: { organizationId: org, role: 'admin', status: 'active', branchIds: [] },
    [`${root}/members/a1-member`]: { organizationId: org, role: 'member', status: 'active', branchIds: ['main'] },
    [`${root}/exerciseVideos/a1-exercise`]: { schemaVersion: 1, exerciseName: 'Fixture exercise',
      muscleCategory: 'Core', isActive: true, videoUrl: 'https://example.test/fixture.mp4' },
    [`${root}/routineBlueprints/a`]: { schemaVersion: 1, name: 'Fixture A', sessionDurationMin: 30,
      days: [{ dayNumber: 1, exercises: [{ exerciseId: 'a1-exercise', sets: 3, reps: 8 }] }] },
    [`${root}/routineBlueprints/b`]: { schemaVersion: 1, name: 'Fixture B', sessionDurationMin: 30,
      days: [{ dayNumber: 1, exercises: [{ exerciseId: 'a1-exercise', sets: 2, reps: 5 }] }] },
    [`${root}/content/draft`]: { schemaVersion: 1, kind: 'routine', status: 'draft', title: 'Hidden draft' },
    'orgs/a1-other-org/content/other': { schemaVersion: 1, kind: 'routine', status: 'published', title: 'Other org' },
  };
  const batch = db.batch();
  for (const [path, data] of Object.entries(seed)) batch.set(db.doc(path), data);
  await batch.commit();
  const actor = { uid: 'a1-admin', token: { email_verified: true } };
  const publish = (blueprintId: string, requestId: string) => publishRoutine(new FirestoreStore(db), actor,
    { schemaVersion: 1, organizationId: org, blueprintId, requestId });
  await publish('a', 'a1-create-a'); await publish('b', 'a1-create-b');
  const member = env.authenticatedContext('a1-member', { email_verified: true }).firestore();
  const base = collection(member, `${root}/content`);
  const filters = [where('status', '==', 'published'), where('kind', '==', 'routine')];
  const first = await getDocs(query(base, ...filters, orderBy(documentId()), limit(2)));
  console.info('A1 smoke: initial scoped page read passed.');
  expect(first.docs.map(d => d.id)).toEqual(['routine_a', 'routine_b']);
  // Page size one plus lookahead; cursor uses the last returned item, not lookahead.
  const second = await getDocs(query(base, ...filters, orderBy(documentId()), startAfter('routine_a'), limit(2)));
  expect(second.docs.map(d => d.id)).toEqual(['routine_b']);
  console.info('A1 smoke: cursor page read passed.');
  const lookup = (id: string) => getDocs(query(base, ...filters, orderBy(documentId()), startAt(id), limit(1)));
  const selected = () => lookup('routine_b');
  expect((await selected()).docs[0].data().exercises[0]).toMatchObject({
    exerciseId: 'a1-exercise', dayNumber: 1, sets: 2, reps: 5, videoUrl: 'https://example.test/fixture.mp4' });
  console.info('A1 smoke: published selected-ID read passed.');
  await db.doc(`${root}/routineBlueprints/b`).update({ name: 'Updated fixture B' });
  await publish('b', 'a1-refresh-b');
  expect((await selected()).docs[0].data().title).toBe('Updated fixture B');
  console.info('A1 smoke: refreshed source read passed.');
  expect((await lookup('draft')).docs.some(d => d.id === 'draft')).toBe(false);
  await db.doc(`${root}/content/routine_b`).update({ status: 'draft' });
  expect((await selected()).docs.some(d => d.id === 'routine_b')).toBe(false);
  await assertFails(getDocs(query(base, orderBy(documentId()), limit(2))));
  await assertFails(getDocs(query(collection(member, 'orgs/a1-other-org/content'), ...filters, limit(2))));
  const unverified = env.authenticatedContext('a1-member', { email_verified: false }).firestore();
  await assertFails(getDocs(query(collection(unverified, `${root}/content`), ...filters, limit(2))));
  expect((await db.collection(`${root}/workoutSessions`).get()).empty).toBe(true);
  expect((await db.collection(`${root}/workoutConsents`).get()).empty).toBe(true);
});
