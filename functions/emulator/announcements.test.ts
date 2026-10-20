import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, limit, orderBy, documentId, query, runTransaction, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';

let env: RulesTestEnvironment;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Isolated emulator required.');
  env = await initializeTestEnvironment({projectId: 'demo-gainpath', firestore: {
    rules: readFileSync(process.env.GAINPATH_ANNOUNCEMENT_RULES_FILE ?? '../firebase/firestore.rules', 'utf8'),
  }});
});
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    for (const [uid, role] of [['admin', 'admin'], ['staff', 'staff'], ['member', 'member'], ['coach', 'coach']]) {
      await setDoc(doc(c.firestore(), `users/${uid}`), {organizationId: 'o'});
      await setDoc(doc(c.firestore(), `orgs/o/members/${uid}`), {organizationId: 'o', role, status: 'active', branchIds: ['main']});
    }
  });
});
const dbFor = (uid: string, verified = true) => env.authenticatedContext(uid, {email_verified: verified}).firestore();
const path = 'orgs/o/announcements/a';
const draft = () => ({schemaVersion: 1, title: 'Development fixture', body: 'Emulator only', status: 'draft', revision: 1,
  validFrom: new Date('2026-01-01'), validTo: new Date('2027-01-01'), publishedAt: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), createdBy: 'admin', updatedBy: 'admin'});

it('Admin draft -> edit -> publish -> scoped Member refresh -> deactivate, preserving identity', async () => {
  const admin = dbFor('admin'), member = dbFor('member');
  const ref = doc(admin, path);
  await setDoc(ref, draft());
  await assertFails(getDoc(doc(member, path)));
  const published = () => getDocs(query(collection(member, 'orgs/o/announcements'), where('status', '==', 'published'), orderBy(documentId()), limit(20)));
  expect((await published()).empty).toBe(true);
  const original = (await getDoc(ref)).data()!;
  await updateDoc(ref, {title: 'Updated fixture', status: 'published', publishedAt: serverTimestamp(), revision: 2, updatedAt: serverTimestamp(), updatedBy: 'admin'});
  expect((await published()).docs.map(d => d.data().title)).toEqual(['Updated fixture']);
  expect((await getDoc(ref)).data()!.createdAt).toEqual(original.createdAt);
  await updateDoc(ref, {status: 'inactive', revision: 3, updatedAt: serverTimestamp(), updatedBy: 'admin'});
  expect((await published()).empty).toBe(true);
  expect((await getDoc(ref)).data()!.revision).toBe(3);
  await assertFails(deleteDoc(ref));
});

it('denies foreign org, unverified, Member/Coach writes and stale canonical assignment', async () => {
  const admin = dbFor('admin');
  await setDoc(doc(admin, path), draft());
  for (const uid of ['member', 'coach']) {
    await assertFails(setDoc(doc(dbFor(uid), 'orgs/o/announcements/new'), {...draft(), createdBy: uid, updatedBy: uid}));
    await assertFails(getDocs(query(collection(dbFor(uid), 'orgs/other/announcements'), where('status', '==', 'published'), limit(20))));
  }
  await assertFails(getDoc(doc(dbFor('admin', false), path)));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'users/admin'), {organizationId: 'other'}));
  await assertFails(getDoc(doc(admin, path)));
  await assertFails(updateDoc(doc(admin, path), {body: 'Forbidden', revision: 2, updatedAt: serverTimestamp()}));
  await assertFails(setDoc(doc(admin, 'orgs/o/announcements/after-reassignment'), draft()));
});

it('keeps Staff content authority; rejects stale revisions, invalid dates and immutable-field changes', async () => {
  const admin = dbFor('admin'), staff = dbFor('staff');
  await setDoc(doc(admin, path), draft());
  const patch = {revision: 2, updatedBy: 'staff', updatedAt: serverTimestamp()};
  await updateDoc(doc(staff, path), {...patch, body: 'Staff edit'});
  await assertFails(updateDoc(doc(staff, path), {...patch, body: 'Stale'}));
  for (const bad of [{validTo: new Date('2025-01-01')}, {createdBy: 'staff'}, {schemaVersion: 2}, {body: ''}, {title: 'x'.repeat(121)}, {extraField: true}]) {
    await assertFails(updateDoc(doc(staff, path), {...patch, revision: 3, ...bad}));
  }
  const originalRevision = 2;
  await updateDoc(doc(admin, path), {body: 'Second editor', revision: 3, updatedAt: serverTimestamp(), updatedBy: 'admin'});
  await expect(runTransaction(staff, async tx => {
    const current = await tx.get(doc(staff, path));
    if (current.data()!.revision !== originalRevision) throw new Error('Reload required');
    tx.update(doc(staff, path), {...patch, revision: 3, body: 'Stale editor'});
  })).rejects.toThrow('Reload required');
  expect((await getDoc(doc(admin, path))).data()!.body).toBe('Second editor');
});
