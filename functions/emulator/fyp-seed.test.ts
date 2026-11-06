import {randomBytes} from 'node:crypto';
import {afterAll, beforeAll, describe, expect, it} from 'vitest';
import {initializeApp, deleteApp, type App} from 'firebase-admin/app';
import {getAuth, type Auth} from 'firebase-admin/auth';
import {Firestore} from 'firebase-admin/firestore';
import {buildFypDataset, FYP_ROOT, FYP_EMULATOR_PROJECT, type FypDataset} from '../src/modules/dataset/fyp-dataset';
import {applyFypSeed, cleanupFypSeedDryRun, dryRunFypSeed, validateFypSeed} from '../src/modules/dataset/fyp-seed';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {createFypScopedStore, resolveFypScope} from '../src/modules/dataset/fyp-scope';
import {createRecommendationConsentV2Command} from '../src/modules/recommendation/recommendation-consent-v2';

describe('actual dedicated default-emulator FYP seed', () => {
  let app: App, firestore: Firestore, auth: Auth, dataset: FypDataset;
  const anchorMillis = Date.parse('2026-11-03T04:00:00Z'), password = randomBytes(24).toString('base64url');
  const options = () => ({firestore, auth, dataset, emulatorPassword: password});
  beforeAll(async () => {
    if (process.env.GCLOUD_PROJECT !== FYP_EMULATOR_PROJECT || process.env.GOOGLE_CLOUD_PROJECT !== FYP_EMULATOR_PROJECT
        || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18231' || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:19131') throw Error('Dedicated FYP loopback project and ports required');
    app = initializeApp({projectId: FYP_EMULATOR_PROJECT}, 'fyp-seed-tests'); auth = getAuth(app);
    firestore = new Firestore({projectId: FYP_EMULATOR_PROJECT, host: '127.0.0.1:18231', ssl: false});
    dataset = await buildFypDataset({anchorMillis});
    const response = await fetch(`http://127.0.0.1:18231/emulator/v1/projects/${FYP_EMULATOR_PROJECT}/databases/(default)/documents`, {method: 'DELETE'});
    if (!response.ok) throw Error('Dedicated emulator clear failed');
    // Exact fictional seed IDs only; no Auth enumeration or broad account clear.
    await auth.deleteUsers(dataset.identities.map(u => u.uid));
  }, 60000);
  afterAll(async () => {await firestore?.terminate(); if (app) await deleteApp(app);});
  it.each(['users', 'members'])('preserves a canonical orphan %s and refuses before creating Auth or source', async collection => {
    const uid = dataset.identities[0].uid, path = collection === 'users' ? `users/${uid}` : `orgs/gainpath/members/${uid}`;
    await firestore.doc(path).create({schemaVersion: 1, protectedOrphanFixture: true});
    try {
      await expect(applyFypSeed(options())).rejects.toThrow('canonical identity metadata');
      await expect(auth.getUser(uid)).rejects.toMatchObject({code: 'auth/user-not-found'});
      expect((await firestore.doc(FYP_ROOT).get()).exists).toBe(false);
      expect((await firestore.doc(path).get()).data()).toEqual({schemaVersion: 1, protectedOrphanFixture: true});
    } finally {await firestore.doc(path).delete();} // Exact test-created leaf only.
  });
  it('preflights without creating records, applies, validates and repeats without mutation', async () => {
    expect(await dryRunFypSeed(options())).toMatchObject({dryRun: true, willWrite: false, existingRunStatus: null});
    expect((await firestore.doc(FYP_ROOT).get()).exists).toBe(false);
    const result = await applyFypSeed(options());
    expect(result.createdAuthThisRun).toBe(27); expect(result.validation.valid).toBe(true);
    expect(await validateFypSeed(options())).toMatchObject({valid: true, authIdentities: 27, assignments: 27, observations: 52});
    expect((await applyFypSeed(options())).createdAuthThisRun).toBe(0);
    for (const spec of dataset.identities) {
      const actor = await auth.getUser(spec.uid), assignment = (await firestore.doc(`datasetAssignments/${spec.uid}`).get()).data();
      expect(assignment?.authCreatedAtMillis).toBe(Date.parse(actor.metadata.creationTime));
      expect(actor.customClaims?.fypAuthCreatedAtMillis).toBe(assignment?.authCreatedAtMillis);
      expect((await firestore.doc(`users/${spec.uid}`).get()).exists).toBe(false);
      expect((await firestore.doc(`orgs/gainpath/members/${spec.uid}`).get()).exists).toBe(false);
    }
  }, 60000);
  it('supports actual ordinary Auth email/password login without persisted credentials', async () => {
    const identity = dataset.identities.find(u => u.role === 'member')!;
    const response = await fetch('http://127.0.0.1:19131/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-only', {
      method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify({email: identity.email, password, returnSecureToken: true})});
    const body = await response.json() as {localId?: string; idToken?: string};
    expect(response.ok).toBe(true); expect(body.localId).toBe(identity.uid);
    const decoded = await auth.verifyIdToken(body.idToken!);
    expect(decoded.fypAuthCreatedAtMillis).toBe(Date.parse((await auth.getUser(identity.uid)).metadata.creationTime));
  });
  it('rejects anchor changes and changed owned source without overwriting it', async () => {
    const changed = await buildFypDataset({anchorMillis: anchorMillis + 86400000});
    await expect(applyFypSeed({...options(), dataset: changed})).rejects.toThrow('anchor or manifest collision');
    const p = `${FYP_ROOT}/profiles/${dataset.memberIds[0]}`, original = (await firestore.doc(p).get()).data()!;
    await firestore.doc(p).update({heightCm: 199});
    await expect(applyFypSeed(options())).rejects.toThrow('ownership/content changed');
    expect((await firestore.doc(p).get()).data()?.heightCm).toBe(199);
    await firestore.doc(p).set(original);
  });
  it('returns an exact cleanup inventory without deleting anything', async () => {
    const plan = await cleanupFypSeedDryRun(options());
    expect(plan.willDelete).toBe(false); expect(plan.authBindings).toHaveLength(27);
    expect(plan.firestorePaths).toContain(FYP_ROOT);
    expect((await firestore.doc(FYP_ROOT).get()).exists).toBe(true);
  });
  it('refuses a colliding foreign record when seed ownership is absent', async () => {
    const p = `${FYP_ROOT}/profiles/${dataset.memberIds[1]}`;
    const {fypDigest} = await import('../src/modules/dataset/fyp-dataset');
    const ownershipPath = `${FYP_ROOT}/seedOwnership/${fypDigest(p)}`, original = (await firestore.doc(ownershipPath).get()).data()!;
    await firestore.doc(ownershipPath).delete();
    await expect(dryRunFypSeed(options())).rejects.toThrow('ownership/content changed');
    expect((await firestore.doc(p).get()).exists).toBe(true);
    await firestore.doc(ownershipPath).set(original);
  });
  it('inventories real command-generated consent changes and preserves later tampering without regranting', async () => {
    const spec = dataset.identities.find(u => u.role === 'member')!, actual = await auth.getUser(spec.uid), created = Date.parse(actual.metadata.creationTime);
    const identity = async (uid: string) => {const record = await auth.getUser(uid); return {uid, email: record.email!, emailVerified: record.emailVerified, disabled: record.disabled,
      creationTimeMillis: Date.parse(record.metadata.creationTime), tokensValidAfterMillis: record.tokensValidAfterTime ? Date.parse(record.tokensValidAfterTime) : 0};};
    const request = {app: {appId: 'emulator-seed-test'}, auth: {uid: spec.uid, token: {email_verified: true, email: spec.email, auth_time: Math.floor(Date.now() / 1000), fypAuthCreatedAtMillis: created}}, data: {schemaVersion: 1}};
    const scope = await resolveFypScope(request, {store: new FirestoreStore(firestore), identity});
    const store = createFypScopedStore(new FirestoreStore(firestore), scope), path = `${FYP_ROOT}/recommendationConsent/${spec.uid}`;
    const original = (await firestore.doc(path).get()).data()!;
    await createRecommendationConsentV2Command({store, noticePolicies: dataset.noticePolicies, clock: () => anchorMillis + 1000, readAuthIdentity: identity})({...request,
      data: {schemaVersion: 2, organizationId: 'gainpath', commandId: 'seed-cleanup-test-revoke', expectedRevision: original.revision, purpose: 'exerciseInsights', action: 'revoke'}});
    await expect(applyFypSeed(options())).rejects.toThrow();
    const plan = await cleanupFypSeedDryRun(options());
    expect(plan.willDelete).toBe(false); expect(plan.generatedRecords).toBeGreaterThanOrEqual(3); expect(plan.preserved).toEqual([]);
    expect(plan.firestorePaths).toContain(path);
    await firestore.doc(path).update({revision: 999});
    const tampered = await cleanupFypSeedDryRun(options());
    expect(tampered.firestorePaths).not.toContain(path);
    expect(tampered.preserved).toContainEqual({path, reason: 'generated_ownership_or_current_digest_changed'});
    expect((await firestore.doc(path).get()).data()?.revision).toBe(999);
  }, 60000);
});
