// SDK/Rules contract checks, separate from the production Dart repository tests.
// These do not execute Flutter platform plugins or contact a real project.
import { readFileSync } from 'node:fs';
import { isDeepStrictEqual } from 'node:util';
import { assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, runTransaction, serverTimestamp, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';

let env: RulesTestEnvironment;
const richTutorial = {
  description: 'Move slowly with control.', coverImageUrl: 'https://media.example.test/cover.jpg',
  difficulty: 'Intermediate', equipment: 'Exercise mat',
  tutorialSteps: [
    { title: 'Set up', description: 'Stand tall.', imageUrl: 'https://media.example.test/setup.webp' },
    { title: 'Move', description: 'Lower slowly.', imageUrl: '' },
  ],
};
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator required.');
  env = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: {
    rules: readFileSync(process.env.GAINPATH_EXERCISE_FIRESTORE_RULES_FILE || '../firebase/firestore.rules', 'utf8'),
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
it('authors can save rich instructions and clear optional fields', async () => {
  const reference = doc(author(), 'orgs/o/exerciseVideos/exercise');
  await assertSucceeds(updateDoc(reference, { ...richTutorial, updatedAt: serverTimestamp() }));
  expect((await getDoc(reference)).data()).toMatchObject(richTutorial);
  await assertSucceeds(updateDoc(reference, {
    description: '', coverImageUrl: '', equipment: '', tutorialSteps: [], updatedAt: serverTimestamp(),
  }));
});
it('authors can create an exercise with 12 steps and signed image URLs', async () => {
  const step = {title:'M'.repeat(80), description:'D'.repeat(1200), imageUrl:'https://media.example.test/o/image?alt=media&token=fixture'};
  const reference = doc(author(), 'orgs/o/exerciseVideos/rich');
  await assertSucceeds(setDoc(reference, {
    schemaVersion:1, exerciseName:'Move', muscleCategory:'Core', videoUrl:'', isActive:true,
    ...richTutorial, tutorialSteps:Array.from({length:12}, () => step),
    createdAt:serverTimestamp(), updatedAt:serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(reference, {equipment:'Updated setup', updatedAt:serverTimestamp()}));
  const invalidLastStep = Array.from({length:12}, (_, i) => i === 11 ? {...step, title:''} : step);
  await assertFails(updateDoc(reference, {tutorialSteps:invalidLastStep, updatedAt:serverTimestamp()}));
});
it.each([
  { tutorialSteps: Array.from({length: 13}, () => richTutorial.tutorialSteps[0]) },
  { tutorialSteps: [{ title: '', description: 'Move' }] },
  { tutorialSteps: [{ title: '   ', description: 'Move' }] },
  { tutorialSteps: [{ title: ['Move'], description: 'Move' }] },
  { tutorialSteps: [{ title: 'Move', description: 1 }] },
  { tutorialSteps: ['Move'] },
  { tutorialSteps: null },
  { tutorialSteps: [{ title: 'Move', description: 'x'.repeat(1201) }] },
  { tutorialSteps: [{ title: 'Move', description: 'Move', trackerId: 'forged' }] },
  { tutorialSteps: [{ title: 'Move', description: 'Move', imageUrl: 'file:///private.jpg' }] },
  { coverImageUrl: 'https://user:password@media.example.test/cover.jpg' },
  { difficulty: 'Expert' }, { description: 'x'.repeat(2001) },
  { equipment: 'x'.repeat(301) }, { aiSupported: true },
])('rejects invalid content and authored capability flags %#', async patch => {
  await assertFails(updateDoc(doc(author(), 'orgs/o/exerciseVideos/exercise'),
    { ...patch, updatedAt: serverTimestamp() }));
});
it('rich fields do not broaden member or wrong-organization write authority', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/member'), { organizationId: 'o' });
    await setDoc(doc(context.firestore(), 'orgs/o/members/member'), {
      role: 'member', status: 'active', organizationId: 'o',
    });
  });
  const memberDb = env.authenticatedContext('member', {email_verified:true}).firestore();
  await assertFails(updateDoc(doc(memberDb, 'orgs/o/exerciseVideos/exercise'),
    { ...richTutorial, updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(author(), 'orgs/other/exerciseVideos/exercise'), {
    schemaVersion: 1, exerciseName: 'Move', muscleCategory: 'Core', videoUrl: '', isActive:true,
    ...richTutorial, createdAt:serverTimestamp(), updatedAt:serverTimestamp(),
  }));
});

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
      if (!isDeepStrictEqual(currentAssignment, assigned)) throw new Error('authorization-changed');
      const currentMember = (await tx.get(member)).data();
      if (!isDeepStrictEqual(currentMember, membership)) throw new Error('authorization-changed');
      const current = (await tx.get(exercise)).data();
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
  await env.withSecurityRulesDisabled(async context => {
    expect((await getDoc(doc(context.firestore(), 'orgs/o/exerciseVideos/exercise'))).data()!.exerciseName).toBe('Squat');
  });
});
it('assignment change between reads and commit fails closed at Rules or retry', async () => {
  const edit = await preparedEdit();
  await expect(edit.save(() => env.withSecurityRulesDisabled(context => updateDoc(
    doc(context.firestore(), 'users/admin'), { organizationId: 'other' }))))
    .rejects.toThrow(/authorization-changed|PERMISSION_DENIED|permission-denied/);
  // Canonical assignment is now checked by Rules as well as the callback.
  // Rules may reject the first commit before the SDK needs to retry it.
  await env.withSecurityRulesDisabled(async context => {
    expect((await getDoc(doc(context.firestore(), 'orgs/o/exerciseVideos/exercise'))).data()!.exerciseName).toBe('Squat');
  });
});
