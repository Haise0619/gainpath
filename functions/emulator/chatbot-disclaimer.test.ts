import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, writeBatch, collection, getDocs, query, orderBy, limit } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, it, expect } from 'vitest';

let env: RulesTestEnvironment;
const path = 'orgs/o/chatbotDisclaimer/config';
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Isolated emulator required');
  env = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: { rules: readFileSync('../firebase/firestore.rules', 'utf8') } });
});
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    for (const role of ['admin', 'staff', 'member', 'coach']) {
      await setDoc(doc(c.firestore(), `users/${role}`), { organizationId: 'o' });
      await setDoc(doc(c.firestore(), `orgs/o/members/${role}`), { organizationId: 'o', role, status: 'active', branchIds: ['main'] });
    }
  });
});
const dbFor = (uid = 'admin', verified = true) => env.authenticatedContext(uid, { email_verified: verified }).firestore();
const record = () => ({ schemaVersion: 1, text: 'Emulator notice only', isActive: false, revision: 1, createdAt: serverTimestamp(), createdBy: 'admin', updatedAt: serverTimestamp(), updatedBy: 'admin' });
async function save(db: ReturnType<typeof dbFor>, data: Record<string, unknown>, target = path) {
  const batch = writeBatch(db);
  batch.set(doc(db, target), data);
  batch.set(doc(db, `${target}/versions/${data.revision}`), data);
  await batch.commit();
}

it('creates inactive, edits, activates, deactivates and reloads immutable versions', async () => {
  const db = dbFor();
  await save(db, record());
  const original = (await getDoc(doc(db, path))).data()!;
  await save(db, { ...original, text: 'Updated notice', isActive: true, revision: 2, updatedAt: serverTimestamp() });
  await save(db, { ...(await getDoc(doc(db, path))).data(), isActive: false, revision: 3, updatedAt: serverTimestamp() });
  expect((await getDoc(doc(db, path))).data()!.text).toBe('Updated notice');
  expect((await getDocs(query(collection(db, `${path}/versions`), orderBy('revision', 'desc'), limit(20)))).docs.map(d => d.data().revision)).toEqual([3, 2, 1]);
  expect((await getDoc(doc(db, `${path}/versions/2`))).data()!.isActive).toBe(true);
  await assertFails(updateDoc(doc(db, `${path}/versions/2`), { text: 'Rewrite' }));
  await assertFails(deleteDoc(doc(db, path)));
  await assertFails(deleteDoc(doc(db, `${path}/versions/1`)));
});

it('requires paired history, sequential revisions, valid content and immutable creation fields', async () => {
  const db = dbFor();
  await assertFails(setDoc(doc(db, path), record()));
  await assertFails(save(db, { ...record(), isActive: true }));
  await save(db, record());
  const original = (await getDoc(doc(db, path))).data()!;
  for (const bad of [{ revision: 1 }, { revision: 3 }, { text: '' }, { text: ' '.repeat(5) }, { text: 'x'.repeat(4001) }, { createdBy: 'staff' }, { createdAt: new Date(0) }, { schemaVersion: 2 }, { extra: true }]) {
    await assertFails(save(db, { ...original, revision: 2, updatedAt: serverTimestamp(), ...bad }));
  }
  await assertFails(setDoc(doc(db, `${path}/versions/99`), { ...record(), revision: 99 }));
  const batch = writeBatch(db);
  batch.update(doc(db, path), { text: 'Good', revision: 2, updatedAt: serverTimestamp() });
  batch.set(doc(db, `${path}/versions/2`), { ...original, text: 'Different', revision: 2, updatedAt: serverTimestamp() });
  await assertFails(batch.commit());
});

it('preserves Admin/Staff authority and denies other roles, unverified, foreign and inactive assignments', async () => {
  const admin = dbFor();
  await save(admin, record());
  const original = (await getDoc(doc(admin, path))).data()!;
  await save(dbFor('staff'), { ...original, text: 'Staff notice', revision: 2, updatedAt: serverTimestamp(), updatedBy: 'staff' });
  for (const role of ['member', 'coach']) {
    await assertFails(getDoc(doc(dbFor(role), path)));
    await assertFails(save(dbFor(role), { ...record(), createdBy: role, updatedBy: role }));
    await assertFails(getDocs(collection(dbFor(role), `${path}/versions`)));
  }
  await assertFails(getDoc(doc(dbFor('admin', false), path)));
  await assertFails(save(admin, record(), 'orgs/other/chatbotDisclaimer/config'));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'users/admin'), { organizationId: 'other' }));
  await assertFails(getDoc(doc(admin, path)));
  await assertFails(save(admin, { ...original, revision: 3, updatedAt: serverTimestamp() }));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'orgs/o/members/staff'), { status: 'suspended' }));
  await assertFails(getDoc(doc(dbFor('staff'), path)));
});
