import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {collection, deleteDoc, doc, getDoc, getDocs, limit, query, setDoc, updateDoc, where} from 'firebase/firestore';
import {afterAll, beforeAll, beforeEach, describe, expect, it} from 'vitest';

// Fixed reviewed overlay only; no arbitrary caller-supplied path or live fallback.
const rules = readFileSync(process.env.FYP_LIVE_STAGED_RULES === '1'
  ? '../build/fyp-live-20261104/firestore-additive.rules' : '../firebase/firestore.rules', 'utf8');
const base = 'orgs/gainpath/cohorts/fyp-v1';
const assignment = (role = 'member') => ({schemaVersion: 1, datasetId: 'fyp-v1', organizationId: 'gainpath',
  seedId: 'gainpath-fyp-v1', enabled: true, role, revision: 1, authCreatedAtMillis: 1000});
const manifest = {schemaVersion: 1, datasetId: 'fyp-v1', organizationId: 'gainpath', seedId: 'gainpath-fyp-v1', enabled: true, status: 'active'};

it('source contract: isolated explicit cohort reads and server-owned assignment authority', () => {
  expect(rules.includes('function fypCohortReader()')).toBe(true);
  expect(rules.includes('function fypLifecycleCurrent(user)')).toBe(true);
  expect(rules.includes('&& fypCanonicalIdentityAbsent(uid)')).toBe(true);
  expect(rules.includes('match /datasetAssignments/{uid}')).toBe(true);
  expect(rules.includes('match /orgs/gainpath/cohorts/fyp-v1')).toBe(true);
  expect(rules).not.toMatch(/match \/orgs\/gainpath\/cohorts\/fyp-v1\/\{[^}]+=\*\*\}/);
});

describe('FYP actual default-database Rules isolation', () => {
  let env: RulesTestEnvironment;
  const client = (uid = 'fyp-member', verified = true, authTime = 1000) => env.authenticatedContext(uid, {email_verified: verified, auth_time: authTime, fypAuthCreatedAtMillis: 1000}).firestore();
  const seed = async (path: string, data: Record<string, unknown>) => env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), path), data));
  beforeAll(async () => {
    if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18231' || process.env.GCLOUD_PROJECT !== 'demo-gainpath-fyp') {
      throw Error('Dedicated loopback demo-gainpath-fyp default Firestore emulator required; no live fallback.');
    }
    env = await initializeTestEnvironment({projectId: 'demo-gainpath-fyp', firestore: {host: '127.0.0.1', port: 18231, rules}});
  });
  afterAll(async () => env?.cleanup());
  beforeEach(async () => {
    await env.clearFirestore();
    await seed('orgs/gainpath', {status: 'active'});
    await seed(base, manifest);
    for (const [uid, role] of [['fyp-member', 'member'], ['fyp-other', 'member'], ['fyp-admin', 'admin'], ['fyp-coach', 'coach']]) {
      await seed(`datasetAssignments/${uid}`, assignment(role));
      await seed(`${base}/users/${uid}`, {organizationId: 'gainpath', userId: uid, role, status: 'active'});
      await seed(`${base}/members/${uid}`, {organizationId: 'gainpath', userId: uid, role, status: 'active'});
      await seed(`${base}/profiles/${uid}`, {schemaVersion: 2, displayName: uid});
    }
    for (const [uid, role] of [['ordinary-member', 'member'], ['ordinary-admin', 'admin']]) {
      await seed(`users/${uid}`, {organizationId: 'gainpath', role});
      await seed(`orgs/gainpath/members/${uid}`, {organizationId: 'gainpath', userId: uid, role, status: 'active'});
    }
    for (const status of ['published', 'draft']) {
      await seed(`${base}/coaches/${status}`, {status});
      await seed(`${base}/content/${status}`, {status, kind: 'routine'});
      await seed(`orgs/gainpath/coaches/ordinary-${status}`, {status});
      await seed(`orgs/gainpath/content/ordinary-${status}`, {status, kind: 'routine'});
    }
    await seed(`${base}/coachProfiles/fyp-coach`, {private: true});
    await seed(`${base}/coachProfiles/fyp-coach/certifications/cert`, {private: true});
    await seed(`${base}/notifications/own`, {recipientId: 'fyp-member'});
    await seed(`${base}/notifications/other`, {recipientId: 'fyp-other'});
  });
  it('assignment: verified owner gets own present or absent assignment; no enumeration, writes, spoofing or unverified access', async () => {
    await assertSucceeds(getDoc(doc(client(), 'datasetAssignments/fyp-member')));
    await assertSucceeds(getDoc(doc(client('ordinary-member'), 'datasetAssignments/ordinary-member')));
    await assertFails(getDoc(doc(client('fyp-other'), 'datasetAssignments/fyp-member')));
    await assertFails(getDoc(doc(client('fyp-member', false), 'datasetAssignments/fyp-member')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'datasetAssignments/fyp-member')));
    await assertFails(getDocs(collection(client('fyp-admin'), 'datasetAssignments')));
    await assertFails(setDoc(doc(client('ordinary-member'), 'datasetAssignments/ordinary-member'), assignment('admin')));
    await assertFails(updateDoc(doc(client(), 'datasetAssignments/fyp-member'), {role: 'admin'}));
  });
  it('published Coach and Tutorial queries return cohort documents only; missing publication filters fail closed', async () => {
    for (const kind of ['coaches', 'content']) {
      const result = await assertSucceeds(getDocs(query(collection(client(), `${base}/${kind}`), where('status', '==', 'published'), limit(21))));
      expect(result.docs.map(d => d.id)).toEqual(['published']);
      await assertFails(getDocs(query(collection(client(), `${base}/${kind}`), limit(21))));
      await assertFails(getDoc(doc(client(), `${base}/${kind}/draft`)));
      await assertFails(getDocs(query(collection(client(), `orgs/gainpath/${kind}`), where('status', '==', 'published'), limit(21))));
      expect((await getDocs(query(collection(client('ordinary-member'), `orgs/gainpath/${kind}`), where('status', '==', 'published')))).size).toBe(1);
      await assertFails(getDocs(query(collection(client('ordinary-member'), `${base}/${kind}`), where('status', '==', 'published'))));
    }
  });
  it('cohort Admin management is scoped; ordinary Admin and cohort Members cannot read cross-owner private records', async () => {
    expect((await assertSucceeds(getDocs(query(collection(client('fyp-admin'), `${base}/members`), where('role', '==', 'member'), limit(20))))).size).toBe(2);
    for (const path of ['members/fyp-other', 'profiles/fyp-other', 'coachProfiles/fyp-coach', 'coachProfiles/fyp-coach/certifications/cert']) {
      await assertSucceeds(getDoc(doc(client('fyp-admin'), `${base}/${path}`)));
      await assertFails(getDoc(doc(client(), `${base}/${path}`)));
      await assertFails(getDoc(doc(client('ordinary-admin'), `${base}/${path}`)));
    }
    await assertSucceeds(getDoc(doc(client(), `${base}/profiles/fyp-member`)));
    await assertSucceeds(getDoc(doc(client('fyp-coach'), `${base}/coachProfiles/fyp-coach`)));
    await assertFails(getDoc(doc(client('fyp-admin'), 'orgs/gainpath/members/ordinary-member')));
    await assertFails(getDoc(doc(client('fyp-admin'), `${base}/users/fyp-member`)));
  });
  it('notification reads require the recipient query even for Admin', async () => {
    await assertSucceeds(getDoc(doc(client(), `${base}/notifications/own`)));
    await assertFails(getDoc(doc(client(), `${base}/notifications/other`)));
    await assertFails(getDoc(doc(client('fyp-admin'), `${base}/notifications/own`)));
    expect((await assertSucceeds(getDocs(query(collection(client(), `${base}/notifications`), where('recipientId', '==', 'fyp-member'), limit(21))))).size).toBe(1);
    await assertFails(getDocs(query(collection(client(), `${base}/notifications`), limit(21))));
  });
  it('own preference and numeric-goal projections stay private and read only', async () => {
    for (const suffix of ['preferences/fyp-member', 'profiles/fyp-member/goals/goal', 'profiles/fyp-member/goals/goal/revisions/1']) {
      await seed(`${base}/${suffix}`, {schemaVersion: 1, status: 'active'});
      await assertSucceeds(getDoc(doc(client(), `${base}/${suffix}`)));
      await assertSucceeds(getDoc(doc(client('fyp-admin'), `${base}/${suffix}`)));
      await assertFails(getDoc(doc(client('fyp-other'), `${base}/${suffix}`)));
      await assertFails(updateDoc(doc(client(), `${base}/${suffix}`), {status: 'archived'}));
    }
  });
  it('availability resolves only a published Coach, and catalog authoring sources stay Admin only', async () => {
    for (const coachId of ['published', 'draft']) {
      await seed(`${base}/coachAvailability/${coachId}`, {schemaVersion: 1});
      await seed(`${base}/coachAvailability/${coachId}/days/2026-11-03`, {schemaVersion: 1});
    }
    await assertSucceeds(getDoc(doc(client(), `${base}/coachAvailability/published`)));
    await assertSucceeds(getDocs(collection(client(), `${base}/coachAvailability/published/days`)));
    await assertFails(getDoc(doc(client(), `${base}/coachAvailability/draft`)));
    await assertFails(getDocs(collection(client(), `${base}/coachAvailability/draft/days`)));
    await assertSucceeds(getDoc(doc(client('fyp-admin'), `${base}/coachAvailability/draft`)));
    for (const kind of ['exerciseVideos', 'routineBlueprints']) {
      await seed(`${base}/${kind}/source`, {status: 'published'});
      await assertSucceeds(getDoc(doc(client('fyp-admin'), `${base}/${kind}/source`)));
      await assertFails(getDoc(doc(client(), `${base}/${kind}/source`)));
    }
  });
  it('a valid cohort assignment grants no sibling cohort or organization authority', async () => {
    for (const foreignBase of ['orgs/gainpath/cohorts/fyp-v2', 'orgs/foreign/cohorts/fyp-v1']) {
      await seed(`${foreignBase}/coaches/published`, {status: 'published'});
      await seed(`${foreignBase}/profiles/fyp-member`, {displayName: 'foreign'});
      for (const uid of ['fyp-member', 'fyp-admin']) {
        await assertFails(getDoc(doc(client(uid), `${foreignBase}/coaches/published`)));
        await assertFails(getDoc(doc(client(uid), `${foreignBase}/profiles/fyp-member`)));
      }
    }
  });
  it('current assignment, manifest, identity and membership drift revoke all cohort access', async () => {
    const variants: [string, Record<string, unknown>][] = [
      ['datasetAssignments/fyp-member', {enabled: false}], ['datasetAssignments/fyp-member', {seedId: 'foreign'}],
      ['datasetAssignments/fyp-member', {datasetId: 'foreign'}], ['datasetAssignments/fyp-member', {organizationId: 'foreign'}],
      ['datasetAssignments/fyp-member', {role: 'admin'}], ['datasetAssignments/fyp-member', {revision: 0}],
      [base, {enabled: false}], [base, {status: 'disabled'}], [base, {seedId: 'foreign'}],
      [`${base}/users/fyp-member`, {role: 'admin'}], [`${base}/users/fyp-member`, {status: 'disabled'}],
      [`${base}/members/fyp-member`, {status: 'disabled'}], [`${base}/members/fyp-member`, {organizationId: 'foreign'}],
      [`${base}/members/fyp-member`, {userId: 'fyp-other'}],
    ];
    for (const [path, patch] of variants) {
      let previous: Record<string, unknown> = {};
      await env.withSecurityRulesDisabled(async c => {
        previous = (await getDoc(doc(c.firestore(), path))).data()!;
        await updateDoc(doc(c.firestore(), path), patch);
      });
      await assertFails(getDoc(doc(client(), `${base}/profiles/fyp-member`)));
      await seed(path, previous);
    }
    await assertFails(getDoc(doc(client('fyp-member', false), `${base}/profiles/fyp-member`)));
  });
  it('a recreated UID or mismatched Auth creation claim cannot inherit a valid assignment', async () => {
    const missing = env.authenticatedContext('fyp-member', {email_verified: true, auth_time: 1000}).firestore();
    const wrong = env.authenticatedContext('fyp-member', {email_verified: true, auth_time: 1000, fypAuthCreatedAtMillis: 2000}).firestore();
    for (const db of [missing, wrong]) {
      await assertFails(getDoc(doc(db, `${base}/profiles/fyp-member`)));
      await assertFails(getDocs(query(collection(db, `${base}/coaches`), where('status', '==', 'published'), limit(21))));
      // Routing discovery is still own/verified only; discovery itself grants no scope.
      await assertSucceeds(getDoc(doc(db, 'datasetAssignments/fyp-member')));
    }
  });
  it('lifecycle barriers revoke direct reads for malformed, inactive, pending-revocation or stale sessions', async () => {
    const path = `${base}/users/fyp-member`;
    let previous: Record<string, unknown> = {};
    await env.withSecurityRulesDisabled(async c => {previous = (await getDoc(doc(c.firestore(), path))).data()!;});
    const active = {schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: 1000};
    await seed(path, {...previous, accountLifecycle: active});
    await assertSucceeds(getDoc(doc(client(), `${base}/profiles/fyp-member`)));
    await assertFails(getDoc(doc(client('fyp-member', true, 999), `${base}/profiles/fyp-member`)));
    for (const lifecycle of [null, [], 'active', {}, {...active, schemaVersion: 2}, {...active, state: 'pendingDeletion'},
      {...active, revocationPending: true}, {...active, revocationPending: null}, {...active, sessionNotBeforeSeconds: -1},
      {...active, sessionNotBeforeSeconds: 1001}, {...active, sessionNotBeforeSeconds: '1000'}, {...active, sessionNotBeforeSeconds: 999.5}]) {
      await seed(path, {...previous, accountLifecycle: lifecycle});
      await assertFails(getDoc(doc(client(), `${base}/profiles/fyp-member`)));
      await assertFails(getDocs(query(collection(client(), `${base}/coaches`), where('status', '==', 'published'), limit(21))));
    }
  });
  it('assigned UIDs with any orphaned canonical identity or membership cannot read cohort records', async () => {
    for (const path of ['users/fyp-member', 'orgs/gainpath/members/fyp-member']) {
      await seed(path, {organizationId: 'gainpath', userId: 'fyp-member', role: 'member', status: 'active'});
      try {
        await assertFails(getDoc(doc(client(), `${base}/profiles/fyp-member`)));
        await assertFails(getDocs(query(collection(client(), `${base}/coaches`), where('status', '==', 'published'), limit(21))));
      } finally {
        await env.withSecurityRulesDisabled(c => deleteDoc(doc(c.firestore(), path)));
      }
      await assertSucceeds(getDoc(doc(client(), `${base}/profiles/fyp-member`)));
    }
  });
  it('authority, synthetic observations, recommendation internals, unsupported modules and unknown nested paths remain server-only', async () => {
    for (const suffix of ['users/fyp-member', 'members/fyp-member', 'profiles/fyp-member', 'preferences/fyp-member',
      'syntheticObservations/observation', 'recommendationLeads/lead', 'recommendationReceipts/receipt',
      'bookings/booking', 'rewardWallets/fyp-member', 'payments/payment', 'unknown/nested']) {
      for (const uid of ['fyp-member', 'fyp-admin', 'ordinary-admin']) {
        await assertFails(setDoc(doc(client(uid), `${base}/${suffix}`), {role: 'admin'}));
      }
    }
    for (const suffix of ['syntheticObservations/observation', 'recommendationLeads/lead', 'recommendationReceipts/receipt',
      'payments/payment', 'unknown/nested']) {
      await seed(`${base}/${suffix}`, {recipientId: 'fyp-member', memberId: 'fyp-member'});
      await assertFails(getDoc(doc(client(), `${base}/${suffix}`)));
      await assertFails(getDoc(doc(client('fyp-admin'), `${base}/${suffix}`)));
    }
  });
});
