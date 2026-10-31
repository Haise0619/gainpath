import {readFileSync} from 'node:fs';
import {assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, serverTimestamp, setDoc, Timestamp, updateDoc} from 'firebase/firestore';
import {afterAll, beforeAll, beforeEach, expect, it} from 'vitest';

let env: RulesTestEnvironment;
const original = {
  schemaVersion: 1, exerciseName: 'Single-arm row', muscleCategory: 'Back',
  videoUrl: 'https://media.example.test/original.mp4', coverImageUrl: 'https://media.example.test/cover.jpg',
  isActive: true, createdAt: Timestamp.fromMillis(1000), updatedAt: Timestamp.fromMillis(2000),
  createdBy: 'registered-author', updatedBy: 'registration-tool',
  tutorialSteps: [{title: 'Set up', description: 'Support the free hand.', imageUrl: ''}],
  aiSupported: true, trackerId: 'existing-system-metadata', futureField: {preserve: [1, 2]},
};
beforeAll(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18102') throw new Error('Dedicated local catalog status emulator required.');
  env = await initializeTestEnvironment({projectId: 'demo-gainpath-catalog-status', firestore: {
    rules: readFileSync(process.env.GAINPATH_EXERCISE_FIRESTORE_RULES_FILE || '../firebase/firestore.rules', 'utf8'),
  }});
});
afterAll(async () => { await env?.cleanup(); });
const dbFor = (uid: string, verified = true) => env.authenticatedContext(uid, {email_verified: verified}).firestore();
const refFor = (uid = 'admin', verified = true) => doc(dbFor(uid, verified), 'orgs/o/exerciseVideos/row');
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [uid, role, status, organizationId] of [
      ['admin', 'admin', 'active', 'o'], ['staff', 'staff', 'active', 'o'],
      ['member', 'member', 'active', 'o'], ['inactive', 'admin', 'inactive', 'o'],
      ['foreign', 'admin', 'active', 'other'],
    ]) {
      await setDoc(doc(db, `users/${uid}`), {organizationId});
      await setDoc(doc(db, `orgs/o/members/${uid}`), {role, status, organizationId: 'o'});
    }
    await setDoc(doc(db, 'orgs/o/exerciseVideos/row'), original);
  });
});

it.each(['admin', 'staff'])('%s can deactivate, archive and restore CLI-authored records preserving all metadata', async uid => {
  const reference = refFor(uid);
  for (const [archived, isActive] of [[false, false], [true, false], [false, true], [true, false], [false, false]]) {
    await assertSucceeds(updateDoc(reference, {archived, isActive, updatedAt: serverTimestamp()}));
    const saved = (await getDoc(reference)).data()!;
    expect(saved.archived).toBe(archived);
    expect(saved.isActive).toBe(isActive);
    for (const [key, value] of Object.entries(original)) {
      if (!['isActive', 'updatedAt'].includes(key)) expect(saved[key]).toEqual(value);
    }
    expect(saved.updatedAt.toMillis()).toBeGreaterThan(2000);
  }
  await assertFails(deleteDoc(reference));
});

it.each([
  {exerciseName: 'Changed'}, {videoUrl: 'https://media.example.test/new.mp4'},
  {coverImageUrl: ''}, {tutorialSteps: []}, {createdBy: 'admin'}, {updatedBy: 'admin'},
  {aiSupported: false}, {poseTracking: true}, {trackerId: 'forged'},
  {futureField: {preserve: []}}, {createdAt: Timestamp.fromMillis(3000)}, {schemaVersion: 2},
])('status-only compatibility does not permit content or metadata edits %#', async patch => {
  await assertFails(updateDoc(refFor(), {...patch, archived: true, isActive: false, updatedAt: serverTimestamp()}));
});

it.each([
  {archived: true, isActive: true}, {archived: 'true', isActive: false},
  {archived: false, isActive: 1}, {archived: true, isActive: false, updatedAt: Timestamp.fromMillis(3000)},
])('rejects invalid lifecycle flags and non-server timestamps %#', async patch => {
  await assertFails(updateDoc(refFor(), {updatedAt: serverTimestamp(), ...patch}));
});

it.each(['member', 'inactive', 'foreign'])('rejects status writes by %s', async uid => {
  await assertFails(updateDoc(refFor(uid), {archived: true, isActive: false, updatedAt: serverTimestamp()}));
  await assertFails(deleteDoc(refFor(uid)));
});
it('rejects unverified and anonymous status writes', async () => {
  await assertFails(updateDoc(refFor('admin', false), {archived: true, isActive: false, updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(env.unauthenticatedContext().firestore(), 'orgs/o/exerciseVideos/row'),
    {archived: true, isActive: false, updatedAt: serverTimestamp()}));
});
it('compatibility does not allow author metadata on new records', async () => {
  await assertFails(setDoc(doc(dbFor('admin'), 'orgs/o/exerciseVideos/new'), {
    ...original, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), archived: false,
  }));
});
it('archived ordinary records require a separate restore before editing content', async () => {
  const ref = doc(dbFor('admin'), 'orgs/o/exerciseVideos/ordinary');
  await assertSucceeds(setDoc(ref, {
    schemaVersion: 1, exerciseName: 'Squat', muscleCategory: 'Legs', videoUrl: '',
    isActive: false, archived: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(ref, {exerciseName: 'Changed', updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(ref, {exerciseName: 'Changed', archived: false, isActive: true, updatedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(ref, {archived: false, isActive: false, updatedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(ref, {exerciseName: 'Changed', updatedAt: serverTimestamp()}));
});
