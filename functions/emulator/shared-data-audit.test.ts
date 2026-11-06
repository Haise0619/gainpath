/** Expected-exposure audit of EXISTING default-db boundaries. Passing is NOT isolation success. */
import {readFileSync, mkdirSync, writeFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import {initializeApp as adminApp, deleteApp as deleteAdminApp, type App} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore as adminFirestore, FieldPath, type Firestore} from 'firebase-admin/firestore';
import {initializeApp, deleteApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInWithEmailAndPassword} from 'firebase/auth';
import {initializeTestEnvironment, assertFails, type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, limit, orderBy, query, where, connectFirestoreEmulator, getFirestore} from 'firebase/firestore';
import {afterAll, beforeAll, beforeEach, expect, it} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {adminReport, type ReportingReader} from '../src/modules/analytics/admin-reporting';
import {adminWorkoutReport} from '../src/modules/analytics/admin-workout-reporting';
import {validateBackupPayload, digestOf} from '../src/modules/workouts/workout-backup-validation';
import {payload} from '../test/workout-backup-fixture';
import {provisionMember} from '../src/modules/identity/member-provisioning';

const projectId = 'demo-gainpath-shared-audit', host = '127.0.0.1:18221';
const base = 'orgs/gainpath', now = Date.UTC(2026, 10, 3, 4);
let app: App, db: Firestore, env: RulesTestEnvironment;
const auth = (uid: string) => ({uid, token: {email_verified: true, auth_time: 100}});
const client = (uid: string) => env.authenticatedContext(uid, {email_verified: true}).firestore();
const evidence: string[] = [];
function guard() {
  if (process.env.FIRESTORE_EMULATOR_HOST !== host || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:19121' ||
    process.env.GCLOUD_PROJECT !== projectId) throw Error('Dedicated loopback synthetic emulators required.');
}
beforeAll(async () => {
  guard(); app = adminApp({projectId}, 'shared-default-audit'); db = adminFirestore(app);
  env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: 18221,
    rules: readFileSync('../firebase/firestore.rules', 'utf8')}});
});
afterAll(async () => {
  mkdirSync('../build/gainpath-shared-data-20261103', {recursive: true});
  writeFileSync('../build/gainpath-shared-data-20261103/emulator-audit.json', JSON.stringify({schemaVersion: 1,
    projectId, databaseId: '(default)', existingRulesUnchanged: true, interpretation: 'Exposure counterexamples, not a successful isolated seed', observations: evidence}, null, 2));
  await env?.cleanup(); await db?.terminate(); if (app) await deleteAdminApp(app);
});
beforeEach(async () => {
  guard(); await env.clearFirestore();
  const batch = db.batch(); batch.set(db.doc(base), {status: 'active'});
  // Both sides are fictional. "baseline" represents existing non-fixture data; no live records are read.
  for (const [uid, role, cohortId] of [['baseline-member', 'member', 'baseline'], ['fixture-member', 'member', 'fictional'],
    ['baseline-admin', 'admin', 'baseline'], ['fixture-admin', 'admin', 'fictional']] as const) {
    batch.set(db.doc(`users/${uid}`), {organizationId: 'gainpath', role});
    batch.set(db.doc(`${base}/members/${uid}`), {organizationId: 'gainpath', userId: uid, role, status: 'active',
      branchIds: [cohortId === 'baseline' ? 'main' : 'demo-branch'], cohortId});
  }
  for (const cohort of ['baseline', 'fixture']) {
    batch.set(db.doc(`${base}/coaches/${cohort}-coach`), {status: 'published', cohortId: cohort});
    batch.set(db.doc(`${base}/coachProfiles/${cohort}-coach`), {status: 'draft', cohortId: cohort, privateFixture: true});
    batch.set(db.doc(`${base}/content/${cohort}-tutorial`), {status: 'published', kind: 'routine', cohortId: cohort});
    batch.set(db.doc(`${base}/notifications/${cohort}-notice`), {recipientId: `${cohort}-member`, type: 'booking', cohortId: cohort});
  }
  await batch.commit();
});
it('ordinary published Coach query exposes the fictional Coach to a baseline Member', async () => {
  const result = await getDocs(query(collection(client('baseline-member'), `${base}/coaches`), where('status', '==', 'published'), orderBy('__name__'), limit(21)));
  expect(result.docs.map(d => d.id)).toEqual(['baseline-coach', 'fixture-coach']);
  evidence.push('published_coaches_cross_cohort_visible_despite_branch_and_cohort_field');
});
it('ordinary published Tutorial query exposes fictional content to a baseline Member', async () => {
  const result = await getDocs(query(collection(client('baseline-member'), `${base}/content`), where('status', '==', 'published'), where('kind', '==', 'routine'), orderBy('__name__'), limit(21)));
  expect(result.docs.map(d => d.id)).toEqual(['baseline-tutorial', 'fixture-tutorial']);
  evidence.push('published_tutorials_cross_cohort_visible');
});
it('canonical Demo Admin can read baseline memberships and private Coach drafts', async () => {
  const c = client('fixture-admin');
  expect((await getDoc(doc(c, `${base}/members/baseline-member`))).exists()).toBe(true);
  expect((await getDoc(doc(c, `${base}/coachProfiles/baseline-coach`))).exists()).toBe(true);
  evidence.push('canonical_admin_authority_ignores_cohort_and_branch');
});
it('ordinary Member private ownership and direct recommendation denial remain intact', async () => {
  await assertFails(getDoc(doc(client('fixture-member'), `${base}/members/baseline-member`)));
  await assertFails(getDoc(doc(client('fixture-member'), `${base}/notifications/baseline-notice`)));
  await assertFails(getDoc(doc(client('baseline-member'), `${base}/notifications/fixture-notice`)));
  await assertFails(getDoc(doc(client('fixture-admin'), `${base}/recommendationLeads/unknown`)));
  evidence.push('existing_member_private_and_recommendation_direct_read_guards_preserved');
});
it('actual Auth emulator sign-in uses the same unpartitioned ordinary directory query', async () => {
  guard(); const uid = 'fixture-member', email = 'shared-fixture@gainpath-demo.invalid', password = randomBytes(24).toString('base64url');
  const identity = adminAuth(app); try {await identity.deleteUser(uid);} catch (e: any) {if (e.code !== 'auth/user-not-found') throw e;}
  await identity.createUser({uid, email, password, emailVerified: true});
  const a = initializeApp({projectId, apiKey: 'emulator-only-key'}, 'shared-default-client');
  try {
    const auth = getAuth(a); connectAuthEmulator(auth, 'http://127.0.0.1:19121', {disableWarnings: true});
    const c = getFirestore(a); connectFirestoreEmulator(c, '127.0.0.1', 18221);
    expect((await signInWithEmailAndPassword(auth, email, password)).user.uid).toBe(uid);
    const result = await getDocs(query(collection(c, `${base}/coaches`), where('status', '==', 'published'), orderBy('__name__'), limit(21)));
    expect(result.docs.map(d => d.id)).toContain('baseline-coach');
  } finally {await deleteApp(a); await identity.deleteUser(uid);}
  evidence.push('actual_firebase_auth_sign_in_reproduces_shared_directory_visibility');
});
it('existing Admin SDK report mixes canonical fixture census into baseline totals', async () => {
  const reader: ReportingReader = {page: async (kind, after, count) => {
    let q = db.collection(`${base}/${kind}`).orderBy(FieldPath.documentId()).limit(count);
    if (after) q = q.startAfter(after);
    return (await q.get()).docs.map(d => ({id: d.id, data: d.data()}));
  }};
  const result = await adminReport(new FirestoreStore(db), auth('baseline-admin'), {schemaVersion: 1,
    organizationId: 'gainpath', startAtMillis: now - 86400000, endAtMillis: now}, reader, () => now);
  expect(result.currentAccounts.members).toBe(2); // One baseline + one synthetic, not two genuine operational Members.
  const fixtureResult = await adminReport(new FirestoreStore(db), auth('fixture-admin'), {schemaVersion: 1,
    organizationId: 'gainpath', startAtMillis: now - 86400000, endAtMillis: now}, reader, () => now);
  expect(fixtureResult.currentAccounts).toEqual(result.currentAccounts);
  evidence.push('admin_sdk_reports_combine_both_cohorts_rules_do_not_filter_server_reads');
});
it('honestly labeled synthetic measurements fail existing backup validation', () => {
  const synthetic = {...structuredClone(payload), provenance: 'recordedFixture'};
  expect(() => validateBackupPayload('session', synthetic.sessionId, 'gainpath', synthetic.userId, synthetic)).toThrow('Only measured local summaries');
  evidence.push('honest_synthetic_observations_rejected_by_current_backup_validator');
});
it('Module12 refuses honest synthetic backups without producing partial aggregates', async () => {
  const synthetic = {...structuredClone(payload), userId: 'fixture-member', provenance: 'recordedFixture'};
  const backup = {schemaVersion: 1, kind: 'session', id: synthetic.sessionId, key: `session-${synthetic.sessionId}`,
    payloadJson: JSON.stringify(synthetic), digest: digestOf(synthetic), classification: 'provisional_member_backup', updatedAtMillis: now};
  await db.doc(`${base}/members/fixture-member/workoutBackups/session-${synthetic.sessionId}`).set(backup);
  const page = async (path: string, after: string | undefined, count: number) => {
    let q = db.collection(path).orderBy(FieldPath.documentId()).limit(count); if (after) q = q.startAfter(after);
    return (await q.get()).docs.map(d => ({id: d.id, data: d.data()}));
  };
  await expect(adminWorkoutReport(new FirestoreStore(db), auth('baseline-admin'), {schemaVersion: 1,
    organizationId: 'gainpath', startAtMillis: now - 86400000, endAtMillis: now}, {
    members: (after, count) => page(`${base}/members`, after, count),
    backups: (uid, after, count) => page(`${base}/members/${uid}/workoutBackups`, after, count),
  }, () => now)).rejects.toMatchObject({code: 'failed-precondition'});
  expect((await db.doc(`${base}/members/fixture-member/workoutBackups/session-${synthetic.sessionId}`).get()).data()).toEqual(backup);
  evidence.push('module12_honest_synthetic_source_fails_closed_without_writes_or_partial_totals');
});
it('normal provisioning cannot assign roles from a fixture-like name and has no cohort routing', async () => {
  const baseline = await db.doc(`${base}/members/baseline-member`).get();
  const uid = 'demo-m13-coach-01';
  const result = await provisionMember(new FirestoreStore(db), {userId: uid,
    email: 'fictional-provision-probe@gainpath-demo.invalid', displayName: 'Fictional Provision Probe'}, () => now);
  expect(result).toMatchObject({organizationId: 'gainpath', role: 'member', branchIds: ['main']});
  expect((await db.doc(`${base}/members/${uid}`).get()).data()).toMatchObject({role: 'member', branchIds: ['main']});
  expect((await db.doc(`${base}/members/baseline-member`).get()).updateTime?.isEqual(baseline.updateTime!)).toBe(true);
  evidence.push('normal_provisioning_is_member_only_but_would_enroll_missing_cohort_identity_into_canonical_main');
});
