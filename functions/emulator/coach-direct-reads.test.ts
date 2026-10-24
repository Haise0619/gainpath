import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, limit} from 'firebase/firestore';
import {beforeAll, beforeEach, afterAll, it} from 'vitest';
import {localFirestoreEmulator} from './loopback-emulator';

let env: RulesTestEnvironment;
const proof = (uid: string) => `orgs/o/coachReadScopes/${uid}`;
const cert = `orgs/o/coachProfiles/coach/certifications/${'a'.repeat(32)}`;
const paths = [cert, `${cert}/history/1`, 'orgs/o/coachProfiles/coach/certificationState/current'];
const client = (uid = 'coach', verified = true) => env.authenticatedContext(uid, {email_verified: verified}).firestore();
beforeAll(async () => {
  const {host, port} = localFirestoreEmulator();
  env = await initializeTestEnvironment({projectId: 'demo-gainpath', firestore: {
    host, port, rules: readFileSync(process.env.COACH_DIRECT_RULES_FILE ?? '../firebase/firestore.rules', 'utf8'),
  }});
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore();
    await setDoc(doc(db, 'orgs/o'), {organizationId: 'o', status: 'active', privateField: 'private'});
    for (const [uid, role] of [['coach', 'coach'], ['other', 'coach'], ['admin', 'admin'], ['member', 'member'], ['staff', 'staff']]) {
      await setDoc(doc(db, `users/${uid}`), {organizationId: 'o'});
      await setDoc(doc(db, `orgs/o/members/${uid}`), {organizationId: 'o', status: 'active', role, branchIds: ['main']});
      await setDoc(doc(db, proof(uid)), {schemaVersion: 1, organizationId: 'o', userId: uid, role, validatedBranchIds: ['main']});
    }
    for (const path of paths) await setDoc(doc(db, path), {revision: 1, status: 'pending'});
  });
});
afterAll(async () => env?.cleanup());

it('requires a server-owned scope for credential reads', async () => {
  await env.withSecurityRulesDisabled(c => deleteDoc(doc(c.firestore(), proof('coach'))));
  for (const path of paths) await assertFails(getDoc(doc(client(), path)));
});
it('does not expose private organization data to a Coach', async () => {
  await assertSucceeds(getDoc(doc(client(), proof('coach'))));
  await assertFails(getDoc(doc(client(), 'orgs/o')));
});
it('allows only own Coach scope and own credentials, or scoped Admin review', async () => {
  for (const uid of ['coach', 'admin']) {
    await assertSucceeds(getDoc(doc(client(uid), proof(uid))));
    for (const path of paths) await assertSucceeds(getDoc(doc(client(uid), path)));
  }
  for (const uid of ['other', 'member', 'staff']) {
    for (const path of paths) await assertFails(getDoc(doc(client(uid), path)));
  }
  await assertFails(getDoc(doc(client('admin'), proof('coach'))));
  for (const path of [proof('coach'), ...paths]) {
    await assertFails(getDoc(doc(client('coach', false), path)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), path)));
    await assertFails(setDoc(doc(client(), path), {role: 'admin'}));
  }
});
it.each([
  ['orgs/o', {status: 'inactive'}],
  ['users/coach', {organizationId: 'foreign'}],
  ['orgs/o/members/coach', {organizationId: 'foreign'}],
  ['orgs/o/members/coach', {status: 'inactive'}],
  ['orgs/o/members/coach', {role: 'member'}],
  ['orgs/o/members/coach', {branchIds: ['another']}],
  ['orgs/o/members/coach', {branchIds: [123]}],
  [proof('coach'), {schemaVersion: 2}],
  [proof('coach'), {userId: 'other'}],
] as const)('revokes direct reads on live authority or scope drift: %s %j', async (path, patch) => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), path), patch));
  for (const target of [proof('coach'), ...paths]) await assertFails(getDoc(doc(client(), target)));
});
it('keeps list bounds and scope enumeration denied', async () => {
  await assertSucceeds(getDocs(query(collection(client(), 'orgs/o/coachProfiles/coach/certifications'), limit(100))));
  await assertFails(getDocs(collection(client(), 'orgs/o/coachProfiles/coach/certifications')));
  await assertSucceeds(getDocs(query(collection(client(), `${cert}/history`), limit(20))));
  await assertFails(getDocs(query(collection(client(), `${cert}/history`), limit(21))));
  await assertFails(getDocs(collection(client('admin'), 'orgs/o/coachReadScopes')));
});
it('denies expired identity sessions without changing identity bootstrap rules', async () => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'users/coach'), {accountLifecycle: {
    schemaVersion: 1, state: 'active', revision: 1, requestedAtMillis: 1000, sessionNotBeforeSeconds: 2,
  }}));
  const stale = env.authenticatedContext('coach', {email_verified: true, auth_time: 1}).firestore();
  await assertFails(getDoc(doc(stale, proof('coach'))));
  await assertFails(getDoc(doc(stale, cert)));
  const fresh = env.authenticatedContext('coach', {email_verified: true, auth_time: 2}).firestore();
  await assertSucceeds(getDoc(doc(fresh, proof('coach'))));
});
