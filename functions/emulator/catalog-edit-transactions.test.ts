// SDK/Rules contract checks, separate from the production Dart repository tests.
// These do not execute Flutter platform plugins or contact a real project.
import { readFileSync } from 'node:fs';
import { isDeepStrictEqual } from 'node:util';
import { initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, runTransaction, serverTimestamp, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';

let env: RulesTestEnvironment;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator required.');
  env = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: {
    rules: readFileSync('../firebase/firestore.rules', 'utf8'),
  } });
});
afterAll(async () => { await env?.cleanup(); });
const author = () => env.authenticatedContext('admin', { email_verified: true }).firestore();
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'orgs/o/members/admin'), {
      role: 'admin', status: 'active', organizationId: 'o' });
    await setDoc(doc(context.firestore(), 'users/admin'), { organizationId: 'o' });
  });
  await setDoc(doc(author(), 'orgs/o/exerciseVideos/exercise'), {
    schemaVersion: 1, exerciseName: 'Squat', muscleCategory: 'Compound Lower-Body',
    videoUrl: 'https://example.test/original.mp4', isActive: true,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
});

// Contract fixture captures expected data outside the retryable callback.
async function preparedEdit() {
  const db = author();
  const exercise = doc(db, 'orgs/o/exerciseVideos/exercise');
  const member = doc(db, 'orgs/o/members/admin');
  const assignment = doc(db, 'users/admin');
  const original = (await getDoc(exercise)).data()!;
  const membership = (await getDoc(member)).data()!;
  const assigned = (await getDoc(assignment)).data()!;
  let attempts = 0;
  return { exercise, original, get attempts() { return attempts; },
    save: (betweenReadAndWrite?: () => Promise<void>) => runTransaction(db, async tx => {
      attempts++;
      const currentAssignment = (await tx.get(assignment)).data();
      const currentMember = (await tx.get(member)).data();
      const current = (await tx.get(exercise)).data();
      if (!isDeepStrictEqual(currentAssignment, assigned) ||
          !isDeepStrictEqual(currentMember, membership)) throw new Error('authorization-changed');
      if (!isDeepStrictEqual(current, original)) throw new Error('edit-conflict');
      if (attempts === 1 && betweenReadAndWrite) await betweenReadAndWrite();
      tx.update(exercise, { exerciseName: 'Edited', updatedAt: serverTimestamp() });
    }),
  };
}
it('SDK transaction preserves all fields outside the explicit patch', async () => {
  const edit = await preparedEdit();
  await edit.save();
  const after = (await getDoc(edit.exercise)).data()!;
  expect(after.exerciseName).toBe('Edited');
  for (const key of ['schemaVersion', 'videoUrl', 'muscleCategory', 'isActive', 'createdAt']) {
    expect(after[key]).toEqual(edit.original[key]);
  }
  expect(after.updatedAt.toMillis()).toBeGreaterThanOrEqual(edit.original.updatedAt.toMillis());
});
for (const [field, value] of Object.entries({ exerciseName: 'Concurrent',
  videoUrl: 'https://example.test/concurrent.mp4', muscleCategory: 'Core', isActive: false })) {
  it(`SDK baseline contract detects concurrent ${field}`, async () => {
    const edit = await preparedEdit();
    await updateDoc(edit.exercise, { [field]: value, updatedAt: serverTimestamp() });
    await expect(edit.save()).rejects.toThrow('edit-conflict');
    expect((await getDoc(edit.exercise)).data()![field]).toBe(value);
  });
}
it('web SDK retries with unchanged original baseline and rejects intervening write', async () => {
  const edit = await preparedEdit();
  await expect(edit.save(() => updateDoc(edit.exercise,
    { muscleCategory: 'Core', updatedAt: serverTimestamp() }))).rejects.toThrow('edit-conflict');
  expect(edit.attempts).toBeGreaterThan(1);
  const after = (await getDoc(edit.exercise)).data()!;
  expect(after.muscleCategory).toBe('Core');
  expect(after.exerciseName).toBe('Squat');
});
it('membership admin to staff drift fails even though both roles can author', async () => {
  const edit = await preparedEdit();
  await env.withSecurityRulesDisabled(context => updateDoc(
    doc(context.firestore(), 'orgs/o/members/admin'), { role: 'staff' }));
  await expect(edit.save()).rejects.toThrow('authorization-changed');
  expect((await getDoc(edit.exercise)).data()!.exerciseName).toBe('Squat');
});
it('deleted exercise is never recreated by guarded transaction', async () => {
  const edit = await preparedEdit();
  await env.withSecurityRulesDisabled(context => deleteDoc(
    doc(context.firestore(), 'orgs/o/exerciseVideos/exercise')));
  await expect(edit.save()).rejects.toThrow('edit-conflict');
  expect((await getDoc(edit.exercise)).exists()).toBe(false);
});
it('assignment org switch is rejected while old membership is still active', async () => {
  const edit = await preparedEdit();
  await env.withSecurityRulesDisabled(context => updateDoc(
    doc(context.firestore(), 'users/admin'), { organizationId: 'other' }));
  await expect(edit.save()).rejects.toThrow('authorization-changed');
  expect((await getDoc(edit.exercise)).data()!.exerciseName).toBe('Squat');
});
it('assignment change between reads and commit retries and fails closed', async () => {
  const edit = await preparedEdit();
  await expect(edit.save(() => env.withSecurityRulesDisabled(context => updateDoc(
    doc(context.firestore(), 'users/admin'), { organizationId: 'other' }))))
    .rejects.toThrow('authorization-changed');
  expect(edit.attempts).toBeGreaterThan(1);
  expect((await getDoc(edit.exercise)).data()!.exerciseName).toBe('Squat');
});
