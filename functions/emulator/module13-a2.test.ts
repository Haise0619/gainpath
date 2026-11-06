import {readFileSync} from 'node:fs';
import {initializeApp, deleteApp, type App} from 'firebase-admin/app';
import {getFirestore, type Firestore} from 'firebase-admin/firestore';
import {assertFails, initializeTestEnvironment, type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, setDoc} from 'firebase/firestore';
import {beforeAll, afterAll, beforeEach, expect, it} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {exerciseInsightsHandler} from '../src/modules/recommendation/exercise-insights';
import {createFirestoreExerciseInsightsReader} from '../src/modules/recommendation/firestore-exercise-insights-reader';
import {createRecommendationConsentV2Command, type ReviewedConsentNoticePolicy} from '../src/modules/recommendation/recommendation-consent-v2';
import type {ExerciseInsightsReader, InsightsRequest} from '../src/modules/recommendation/exercise-insights-contracts';
import {consent, now, query, row, scope, session} from '../test/exercise-insights-fixture';

const projectId = 'demo-gainpath-module13-a2', host = '127.0.0.1:18110';
const memberPath = `orgs/gainpath/members/${scope.memberId}`;
const consentPath = `orgs/gainpath/recommendationConsent/${scope.memberId}`;
const heads = `${memberPath}/workoutBackups`;
const auth = {uid: 'synthetic-admin', token: {email: 'synthetic-admin@example.invalid', email_verified: true, auth_time: 100}};
let app: App, db: Firestore, env: RulesTestEnvironment, reader: ExerciseInsightsReader, deps: Parameters<typeof exerciseInsightsHandler>[1];
function guard() {
  if (process.env.FIRESTORE_EMULATOR_HOST !== host ||
    (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT !== projectId)) throw Error('Dedicated loopback demo emulator required; no production fallback.');
}
const invoke = (dependencies = deps, patch: Partial<InsightsRequest> = {}) => exerciseInsightsHandler({
  app: {appId: 'synthetic-trusted-app-boundary'}, auth, data: query, ...patch}, dependencies);
beforeAll(async () => {
  guard(); // Must precede Admin initialization, Rules setup and all fixture writes/deletes.
  app = initializeApp({projectId}, 'module13-a2-local'); db = getFirestore(app);
  env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: 18110,
    rules: readFileSync('../firebase/firestore.rules', 'utf8')}});
  reader = createFirestoreExerciseInsightsReader({firestore: db, organizationId: 'gainpath',
    localReview: {mode: 'local_reviewed_emulator', projectId, firestoreEmulatorHost: host}});
});
afterAll(async () => {await env?.cleanup(); await db?.terminate(); if (app) await deleteApp(app);});
beforeEach(async () => {
  guard(); await env.clearFirestore();
  const b = db.batch();
  b.set(db.doc('orgs/gainpath'), {status: 'active'});
  b.set(db.doc(`users/${auth.uid}`), {organizationId: 'gainpath', role: 'admin'});
  b.set(db.doc(`orgs/gainpath/members/${auth.uid}`), {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});
  b.set(db.doc(`users/${scope.memberId}`), {organizationId: 'gainpath', role: 'member'});
  b.set(db.doc(memberPath), {organizationId: 'gainpath', userId: scope.memberId, role: 'member', status: 'active', branchIds: []});
  b.set(db.doc(consentPath), consent()); b.set(db.doc(`${heads}/session-private-session-001`), row().data);
  await b.commit();
  deps = {store: new FirestoreStore(db), reader, clock: () => now,
    readAuthIdentity: async uid => ({uid, email: String(auth.token.email), emailVerified: true, disabled: false, tokensValidAfterMillis: 0})};
});
it('actual FirestoreStore and bounded head reader return a private aggregate without source writes', async () => {
  const head = db.doc(`${heads}/session-private-session-001`), before = await head.get();
  // Deliberately malformed immutable revision: a heads-only reader must not touch it.
  await head.collection('revisions').doc('synthetic-invalid-revision').set({payloadJson: 'invalid'});
  const result = await invoke();
  expect(result).toMatchObject({status: 'available', source: {recordsScanned: 1}, samplePolicy: null, attentionThreshold: null,
    coverage: {activeMembers: 1, consentedMembers: 1}});
  expect(result.groups[0]).toMatchObject({sessions: 1, members: 1, meanEstimatedFormScore: 80});
  expect((await head.get()).updateTime?.isEqual(before.updateTime!)).toBe(true);
  expect((await db.collection('orgs/gainpath/workoutSessions').get()).empty).toBe(true);
  expect((await db.collection('orgs/gainpath/recommendations').get()).empty).toBe(true);
  for (const privateValue of [scope.memberId, 'payloadJson', 'sessionId', 'digest', auth.uid]) expect(JSON.stringify(result)).not.toContain(privateValue);
});
it('uses real ascending document-ID cursors across member and backup pages', async () => {
  const b = db.batch();
  for (let i = 0; i < 270; i++) b.set(db.doc(`orgs/gainpath/members/inactive-${String(i).padStart(3, '0')}`),
    {organizationId: 'gainpath', role: 'member', status: 'inactive', branchIds: []});
  for (let i = 0; i < 27; i++) {const p = session(`page-${String(i).padStart(3, '0')}`); b.set(db.doc(`${heads}/session-${p.sessionId}`), row(p).data);}
  await b.commit();
  const first = await reader.members('gainpath', undefined, 251), second = await reader.members('gainpath', first.at(-1)!.id, 251);
  expect(first).toHaveLength(251); expect(second).toHaveLength(21);
  expect(new Set([...first, ...second].map(r => r.id)).size).toBe(272);
  expect((await invoke()).groups[0]).toMatchObject({sessions: 28, meanEstimatedFormScore: 80});
});
it.each(['missing', 'revoked', 'other-purpose'])('never opens backup pages for %s consent', async state => {
  if (state === 'missing') await db.doc(consentPath).delete();
  if (state === 'revoked') await db.doc(consentPath).update({revision: 2, revokedAtMillis: now - 1000});
  if (state === 'other-purpose') await db.doc(consentPath).update({'purposes.exerciseInsights': false, 'purposes.recommendationGeneration': true});
  let reads = 0;
  const result = await invoke({...deps, reader: {...reader, backups: async (...args) => {reads++; return reader.backups(...args);}}});
  expect(reads).toBe(0); expect(result.status).toBe('no_consented_members'); expect(result.groups).toEqual([]);
});
it('discards all aggregates after consent revocation during a real source read', async () => {
  await expect(invoke({...deps, reader: {...reader, backups: async (...args) => {
    const page = await reader.backups(...args); await db.doc(consentPath).update({revision: 2, revokedAtMillis: now - 1000}); return page;
  }}})).rejects.toMatchObject({code: 'aborted'});
});
it('v2 grant persists through real transactions but the legacy head adapter fails closed before history reads', async () => {
  // Synthetic local receipt creation is explicit; legacy consent is not silently migrated.
  await db.doc(consentPath).delete();
  const notice: ReviewedConsentNoticePolicy = {policyId: 'synthetic-reviewed-retained', noticeVersion: 'synthetic-v1',
    contentVersion: 'synthetic-v1', history: {mode: 'retained', earliestAtMillis: query.startAtMillis}};
  const memberAuth = {uid: scope.memberId, token: {...auth.token, email: 'synthetic-member@example.invalid'}};
  const grant = createRecommendationConsentV2Command({store: deps.store, clock: () => now - 1000, noticePolicies: [notice],
    readAuthIdentity: async uid => ({uid, email: memberAuth.token.email, emailVerified: true, disabled: false, tokensValidAfterMillis: 0})});
  expect(await grant({app: {appId: 'synthetic-trusted-app-boundary'}, auth: memberAuth, data: {schemaVersion: 2,
    organizationId: 'gainpath', commandId: 'synthetic-v2-grant', expectedRevision: 0, purpose: 'exerciseInsights', action: 'grant',
    noticePolicyId: notice.policyId, acceptedNoticeVersion: notice.noticeVersion, acceptedContentVersion: notice.contentVersion}}))
    .toMatchObject({schemaVersion: 2, granted: true, revision: 1});
  expect((await db.doc(consentPath).get()).data()?.schemaVersion).toBe(2);
  expect(reader.consentScopedBackups).toBeUndefined();
  let historyReads = 0;
  await expect(invoke({...deps, consentNoticePolicies: [notice], reader: {...reader, backups: async (...args) => {
    historyReads++; return reader.backups(...args);
  }}})).rejects.toMatchObject({code: 'failed-precondition', message: 'Exercise insight sources require review.'});
  expect(historyReads).toBe(0);
});
it('rejects canonical Admin drift and Member lifecycle drift during real reads', async () => {
  await expect(invoke({...deps, reader: {...reader, backups: async (...args) => {
    const page = await reader.backups(...args); await db.doc(`users/${auth.uid}`).update({organizationId: 'foreign'}); return page;
  }}})).rejects.toMatchObject({code: 'permission-denied'});
  await db.doc(`users/${auth.uid}`).update({organizationId: 'gainpath'});
  await expect(invoke({...deps, reader: {...reader, backups: async (...args) => {
    const page = await reader.backups(...args); await db.doc(memberPath).update({status: 'inactive'}); return page;
  }}})).rejects.toMatchObject({code: 'aborted'});
});
it('isolates foreign organizations and Members and rejects a substituted payload owner', async () => {
  await db.doc('orgs/foreign/members/foreign/workoutBackups/session-foreign').set({payloadJson: 'foreign invalid'});
  await db.doc('orgs/gainpath/members/unlisted/workoutBackups/session-unlisted').set({payloadJson: 'unlisted invalid'});
  expect((await invoke()).source.recordsScanned).toBe(1);
  await expect(reader.members('foreign', undefined, 1)).rejects.toMatchObject({code: 'permission-denied'});
  const p = session('substitution'); p.userId = 'foreign'; await db.doc(`${heads}/session-substitution`).set(row(p).data);
  await expect(invoke()).rejects.toMatchObject({code: 'failed-precondition', message: 'Exercise insight sources require review.'});
});
it('enforces the trusted App Check boundary and canonical Admin role before any source query', async () => {
  const forbidden: ExerciseInsightsReader = {members: async () => {throw Error('Unexpected source read');}, backups: async () => {throw Error('Unexpected history read');}};
  await expect(invoke({...deps, reader: forbidden}, {app: undefined})).rejects.toMatchObject({code: 'unauthenticated'});
  await expect(invoke({...deps, reader: forbidden}, {auth: {...auth, uid: scope.memberId}})).rejects.toMatchObject({code: 'permission-denied'});
  // Emulator does not attest real App Check tokens: app above is a trusted injection.
  // No production callable/SDK bootstrap for this handler is registered in index.ts.
  expect(readFileSync('src/index.ts', 'utf8')).not.toMatch(/exerciseInsightsHandler|createFirestoreExerciseInsightsReader/);
});
it('unchanged Rules deny every client history read and M13 config/consent write', async () => {
  const paths = [`${heads}/session-private-session-001`, `${heads}/session-private-session-001/revisions/rev`];
  for (const uid of [scope.memberId, 'foreign', auth.uid]) {
    const client = env.authenticatedContext(uid, {email_verified: true}).firestore();
    for (const path of paths) {await assertFails(getDoc(doc(client, path))); await assertFails(setDoc(doc(client, path), {injected: true}));}
    await assertFails(getDocs(collection(client, heads)));
    for (const path of [consentPath, 'orgs/gainpath/recommendationConfiguration/current',
      'orgs/gainpath/recommendationConfigurationReceipts/receipt', 'orgs/gainpath/recommendationConfigurationAudit/audit',
      'orgs/gainpath/recommendationConsentReceipts/receipt', 'orgs/gainpath/recommendationConsentAudit/audit']) {
      await assertFails(getDoc(doc(client, path))); await assertFails(setDoc(doc(client, path), {injected: true}));
    }
  }
});
