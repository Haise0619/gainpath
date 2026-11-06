import {afterEach, describe, expect, it, vi} from 'vitest';
import {Firestore} from 'firebase-admin/firestore';
import type {Auth} from 'firebase-admin/auth';
import {buildFypDataset, fypDigest, FYP_EMULATOR_PROJECT, FYP_ROOT} from '../src/modules/dataset/fyp-dataset';
import {describeFypSeed, guardFypSeed, assignmentForIdentity, inspectFypCleanupRecord, applyFypSeed} from '../src/modules/dataset/fyp-seed';

const saved = {...process.env};
afterEach(() => {process.env = {...saved};});
function clients(projectId = FYP_EMULATOR_PROJECT) {
  process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:18129'; process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19109';
  const firestore = new Firestore({projectId, host: '127.0.0.1:18129', ssl: false});
  return {firestore, auth: {app: {options: {projectId}}} as Auth};
}
describe('dedicated emulator seed boundary', () => {
  it('accepts only the dedicated project, default database and actual loopback SDK endpoint', () => {
    expect(() => guardFypSeed(clients())).not.toThrow();
    expect(() => guardFypSeed(clients('gainpath-0619'))).toThrow();
    const c = clients(); process.env.FIREBASE_AUTH_EMULATOR_HOST = 'example.com:9099';
    expect(() => guardFypSeed(c)).toThrow();
    process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19109';
    const other = new Firestore({projectId: FYP_EMULATOR_PROJECT, databaseId: 'named', host: '127.0.0.1:18129', ssl: false});
    expect(() => guardFypSeed({...c, firestore: other})).toThrow();
  });
  it('produces an exact dry-run inventory and refuses mutated source', async () => {
    const d = await buildFypDataset({anchorMillis: Date.parse('2026-11-03T04:00:00Z')}), plan = describeFypSeed(d);
    expect(plan).toMatchObject({databaseId: '(default)', liveApplyEnabled: false, seedId: 'gainpath-fyp-v1', authAccounts: 27});
    expect(plan.sourcePaths).toEqual(Object.keys(d.documents).sort());
    expect(plan.sourcePaths.every(p => p === FYP_ROOT || p.startsWith(`${FYP_ROOT}/`))).toBe(true);
    d.documents[FYP_ROOT].enabled = false; expect(() => describeFypSeed(d)).toThrow();
  });
  it('binds assignments to actual Auth creation times and fixed server-owned scope', async () => {
    const d = await buildFypDataset({anchorMillis: Date.parse('2026-11-03T04:00:00Z')});
    expect(assignmentForIdentity(d.identities[0], 1793678400000)).toEqual({schemaVersion: 1, datasetId: 'fyp-v1', organizationId: 'gainpath', seedId: 'gainpath-fyp-v1', role: 'admin', enabled: true, revision: 1, authCreatedAtMillis: 1793678400000});
    expect(() => assignmentForIdentity(d.identities[0], NaN)).toThrow();
  });
  it('inventories legitimate runtime changes while preserving altered or unowned records', () => {
    const path = `${FYP_ROOT}/recommendationConsent/member`, baseline = {revision: 1}, changed = {revision: 2};
    const seedProof = {schemaVersion: 1, seedId: 'gainpath-fyp-v1', path, digest: fypDigest(baseline)};
    const generated = {schemaVersion: 1, seedId: 'gainpath-fyp-v1', datasetId: 'fyp-v1', path, digest: fypDigest(changed), actorId: 'demo-m13-admin', assignmentRevision: 1, lastWrittenAtMillis: 1793678400000};
    const approvedActorIds = ['demo-m13-admin'];
    expect(inspectFypCleanupRecord({path, current: baseline, baseline, seedProof})).toEqual({owned: true, generated: false});
    expect(inspectFypCleanupRecord({path, current: changed, baseline, seedProof, generatedProof: generated, approvedActorIds})).toEqual({owned: true, generated: true});
    expect(inspectFypCleanupRecord({path, current: changed, baseline, seedProof})).toMatchObject({owned: false, reason: 'content_changed_without_matching_generated_ownership'});
    expect(inspectFypCleanupRecord({path, current: changed, baseline, seedProof, generatedProof: {...generated, digest: '0'.repeat(64)}, approvedActorIds})).toMatchObject({owned: false});
    expect(inspectFypCleanupRecord({path, current: changed, baseline, seedProof, generatedProof: {...generated, actorId: 'demo-m13-member-99'}, approvedActorIds})).toMatchObject({owned: false});
    expect(inspectFypCleanupRecord({path: 'users/ordinary', current: changed, generatedProof: {...generated, path: 'users/ordinary'}})).toMatchObject({owned: false, reason: 'path_outside_cohort'});
    expect(inspectFypCleanupRecord({path, current: changed, generatedProof: generated, approvedActorIds})).toEqual({owned: true, generated: true});
  });
  it.each(['users', 'members'])('refuses canonical orphan %s before any Auth creation or source access', async collection => {
    const dataset = await buildFypDataset({anchorMillis: Date.parse('2026-11-03T04:00:00Z')}), c = clients(), uid = dataset.identities[0].uid;
    const occupied = collection === 'users' ? `users/${uid}` : `orgs/gainpath/members/${uid}`;
    // Real SDK object for endpoint verification, fully intercepted before any network call.
    vi.spyOn(c.firestore, 'doc').mockImplementation((path: string) => ({path, get: async () => {throw Error('Unexpected source access before canonical absence check');}} as never));
    vi.spyOn(c.firestore, 'getAll').mockImplementation(async (...refs: unknown[]) => refs.map(ref => ({exists: (ref as {path: string}).path === occupied})) as never);
    const transact = vi.spyOn(c.firestore, 'runTransaction').mockRejectedValue(Error('Unexpected transaction'));
    const createUser = vi.fn(); Object.assign(c.auth, {createUser});
    await expect(applyFypSeed({...c, dataset})).rejects.toThrow('canonical identity metadata');
    expect(createUser).not.toHaveBeenCalled(); expect(transact).not.toHaveBeenCalled();
  });
});
