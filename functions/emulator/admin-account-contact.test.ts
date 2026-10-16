import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, it, expect } from 'vitest';

let env: RulesTestEnvironment;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Isolated emulator required');
  env = await initializeTestEnvironment({ projectId:'demo-gainpath', firestore:{
    rules:readFileSync(process.env.GAINPATH_ACCOUNT_RULES_FILE ?? '../firebase/firestore.rules', 'utf8') } });
});
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    for (const [uid, role] of [['admin', 'admin'], ['other', 'admin']]) {
      await setDoc(doc(c.firestore(), `users/${uid}`), { organizationId:'o', email:`${uid}@example.test`, avatarPath:'kept', role });
      await setDoc(doc(c.firestore(), `orgs/o/members/${uid}`), { organizationId:'o', role, status:'active', branchIds:['main'] });
    }
  });
});
const dbFor = (uid = 'admin') => env.authenticatedContext(uid, { email_verified:true }).firestore();

it('owner creates, edits, reloads and clears the optional name without changing identity or assignment', async () => {
  const db = dbFor(), user = doc(db, 'users/admin'), member = doc(db, 'orgs/o/members/admin');
  const before = (await getDoc(user)).data()!, membership = (await getDoc(member)).data();
  await updateDoc(user, { displayName:'Admin name', updatedAtMillis:1234 });
  expect((await getDoc(user)).data()!.displayName).toBe('Admin name');
  await updateDoc(user, { displayName:'Edited name', updatedAtMillis:1235 });
  expect((await getDoc(user)).data()!.displayName).toBe('Edited name');
  await updateDoc(user, { displayName:'', updatedAtMillis:1236 });
  expect((await getDoc(user)).data()).toEqual({ ...before, displayName:'', updatedAtMillis:1236 });
  expect((await getDoc(member)).data()).toEqual(membership);
});

it('other Admin accounts and anonymous callers cannot read or change this account', async () => {
  const other = dbFor('other'), anonymous = env.unauthenticatedContext().firestore();
  for (const db of [other, anonymous]) {
    await assertFails(getDoc(doc(db, 'users/admin')));
    await assertFails(updateDoc(doc(db, 'users/admin'), { displayName:'Forbidden', updatedAtMillis:1234 }));
  }
});

it('name saves cannot rewrite email, organization, roles, membership lifecycle or branches', async () => {
  const db = dbFor(), user = doc(db, 'users/admin'), member = doc(db, 'orgs/o/members/admin');
  for (const patch of [{ email:'other@example.test' }, { organizationId:'other' }, { role:'member' }, { protected:true }]) {
    await assertFails(updateDoc(user, { displayName:'Attempt', updatedAtMillis:1234, ...patch }));
  }
  for (const patch of [{ organizationId:'other' }, { role:'member' }, { status:'suspended' }, { branchIds:['other'] }]) {
    await assertFails(updateDoc(member, patch));
  }
  await assertFails(deleteDoc(user));
  await assertFails(setDoc(doc(db, 'users/new-account'), { displayName:'Provision attempt' }));
});
