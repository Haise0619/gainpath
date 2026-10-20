import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, it } from 'vitest';

let env: RulesTestEnvironment;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator only.');
  env = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: {
    rules: readFileSync('../firebase/firestore.rules', 'utf8'),
  } });
});
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/author'), { organizationId: 'o' });
    await setDoc(doc(db, 'orgs/o/members/author'), {
      organizationId: 'o', role: 'admin', status: 'active', branchIds: [],
    });
    const timestamp = new Date('2026-10-01T00:00:00Z');
    await setDoc(doc(db, 'orgs/o/exerciseVideos/e'), {
      schemaVersion: 1, exerciseName: 'Isolated CRUD fixture', muscleCategory: 'Legs',
      videoUrl: '', isActive: true, createdAt: timestamp, updatedAt: timestamp,
    });
    await setDoc(doc(db, 'orgs/o/routineBlueprints/r'), {
      schemaVersion: 1, name: 'Isolated CRUD fixture', sessionDurationMin: 30,
      days: [{ dayNumber: 1, exercises: [{ exerciseId: 'e', sets: 3, reps: 8 }] }],
      createdAt: timestamp, updatedAt: timestamp, updatedBy: 'author',
    });
  });
});
const dbFor = () => env.authenticatedContext('author', { email_verified: true }).firestore();

it('preserves currently assigned active Admin and Staff authoring', async () => {
  for (const role of ['admin', 'staff']) {
    await env.withSecurityRulesDisabled(async context => {
      await updateDoc(doc(context.firestore(), 'orgs/o/members/author'), { role });
    });
    const db = dbFor();
    await assertSucceeds(updateDoc(doc(db, 'orgs/o/exerciseVideos/e'), {
      exerciseName: `Edited ${role}`, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'orgs/o/routineBlueprints/r'), {
      name: `Edited ${role}`, updatedAt: serverTimestamp(), updatedBy: 'author',
    }));
  }
});

it('denies old organization content access after canonical reassignment', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), 'users/author'), { organizationId: 'other' });
  });
  const db = dbFor();
  for (const path of ['exerciseVideos/e', 'routineBlueprints/r']) {
    await assertFails(getDoc(doc(db, `orgs/o/${path}`)));
    await assertFails(updateDoc(doc(db, `orgs/o/${path}`), { updatedAt: serverTimestamp() }));
  }
});

it('denies authoring through a malformed membership organization', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), 'orgs/o/members/author'), { organizationId: 'other' });
  });
  const db = dbFor();
  await assertFails(getDoc(doc(db, 'orgs/o/exerciseVideos/e')));
  await assertFails(getDoc(doc(db, 'orgs/o/routineBlueprints/r')));
});
