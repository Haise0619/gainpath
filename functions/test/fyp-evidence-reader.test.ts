import {beforeEach, describe, expect, it, vi} from 'vitest';
import type {Firestore} from 'firebase-admin/firestore';
import {buildFypDataset, FYP_ROOT, fypDigest, type FypDataset} from '../src/modules/dataset/fyp-dataset';
import {createFypScopedStore, mintFypRuntimeCapability, resolveFypScope, type FypScope} from '../src/modules/dataset/fyp-scope';
import {createFypEvidenceReader} from '../src/modules/dataset/fyp-evidence-reader';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {MemoryStore} from './memory-store';

const now = Date.parse('2026-11-03T04:00:00Z');
let dataset: FypDataset, base: MemoryStore, scope: FypScope, queries: number, mutateAfterQuery: (() => void) | undefined, reportedSize: number | undefined;
async function setup(role: 'admin' | 'member' = 'admin') {
  dataset = await buildFypDataset({anchorMillis: now}); base = new MemoryStore(); queries = 0; mutateAfterQuery = undefined; reportedSize = undefined;
  for (const [p, d] of Object.entries(dataset.documents)) {
    base.documents.set(p, structuredClone(d));
    base.documents.set(`${FYP_ROOT}/seedOwnership/${fypDigest(p)}`, {schemaVersion: 1, seedId: dataset.seedId, path: p, digest: fypDigest(d)});
  }
  for (const u of dataset.identities) base.documents.set(`datasetAssignments/${u.uid}`, {schemaVersion: 1, datasetId: 'fyp-v1', organizationId: 'gainpath', seedId: dataset.seedId, role: u.role, revision: 1, enabled: true, authCreatedAtMillis: now - 1000});
  const uid = role === 'admin' ? dataset.adminId : dataset.memberIds[0], identity = dataset.identities.find(u => u.uid === uid)!;
  scope = await resolveFypScope({app: {appId: 'test'}, auth: {uid, token: {email_verified: true, email: identity.email, auth_time: now / 1000, fypAuthCreatedAtMillis: now - 1000}}, data: {schemaVersion: 1}},
    {store: base, identity: async () => ({...identity, creationTimeMillis: now - 1000, tokensValidAfterMillis: 0})});
}
function reader(clockMillis = now) {
  const db = {collection: (path: string) => {
    const filters: [string, string, number][] = [];
    const q = {where: (key: string, op: string, value: number) => {filters.push([key, op, value]); return q;}, orderBy: () => q, limit: () => q,
      get: async () => {queries++; const docs = [...base.documents].filter(([p, d]) => p.startsWith(path + '/') && p.split('/').length === path.split('/').length + 1 && filters.every(([k, op, v]) => op === '>=' ? Number(d[k]) >= v : Number(d[k]) < v))
        .map(([p, d]) => ({id: p.split('/').at(-1)!, ref: {path: p}, data: () => structuredClone(d)}));
        const result = {docs, size: reportedSize ?? docs.length}; mutateAfterQuery?.(); return result;}};
    return q;
  }} as unknown as Firestore;
  return createFypEvidenceReader({db, scope, store: createFypScopedStore(base, scope), fypCapability: mintFypRuntimeCapability(scope), source: dataset.source as never,
    noticePolicies: dataset.noticePolicies, clock: () => clockMillis, readAuthIdentity: async uid => ({...dataset.identities.find(u => u.uid === uid)!, creationTimeMillis: now - 1000, tokensValidAfterMillis: 0})});
}
beforeEach(() => setup());
describe('cohort-owned bounded observation reader', () => {
  it('allows a through-now Insights window over frozen owned fixtures while preserving generation bounds', async () => {
    const r=reader(now+7200000),target={organizationId:'gainpath',memberId:dataset.memberIds[0]},window={...dataset.legacyDataset.window,endAtMillis:now+3600000};
    expect((await r.read(target,window,false)).rows).toHaveLength(3);
    await expect(r.read(target,window,true)).rejects.toThrow();
    await expect(r.read(target,{...window,endAtMillis:now+7200001},false)).rejects.toThrow();
  });
  it('rejects unapproved rows after the frozen anchor rather than returning a partial Insights aggregate',async()=>{
    const r=reader(now+7200000),target={organizationId:'gainpath',memberId:dataset.memberIds[0]};
    base.documents.set(`${FYP_ROOT}/members/${target.memberId}/syntheticObservations/unowned-after-anchor`,{...base.documents.get(dataset.observations[0].path),observedAtMillis:now+1000});
    await expect(r.read(target,{...dataset.legacyDataset.window,endAtMillis:now+3600000},false)).rejects.toThrow();
  });
  it('reads the same owned rows with truthful attestations and revalidates exact source/policy', async () => {
    const r = reader(), target = {organizationId: 'gainpath', memberId: dataset.memberIds[0]}, window = dataset.legacyDataset.window;
    const batch = await r.read(target, window, true);
    expect(batch.rows).toHaveLength(3); expect(batch.rows.every(row => row.data.classification === 'fictional_synthetic_observation')).toBe(true);
    expect(batch.attestations.every(a => a.trust === 'cohort_synthetic_observation')).toBe(true);
    const policy = dataset.policies.find(p => p.policyId === dataset.memberScenarios[0].policyId)!;
    expect(await createFypScopedStore(base, scope).transact(tx => r.revalidate(tx, target, batch.sourceRevision, digestOf(policy)))).toBe(true);
    expect((await r.rows(target.memberId)).map(x => x.data.digest)).toEqual(batch.rows.map(x => x.data.digest));
  });
  it('checks default-off/revoked consent before querying', async () => {
    const r = reader(), off = dataset.memberScenarios.find(m => m.scenario === 'all_purposes_off')!;
    await expect(r.read({organizationId: 'gainpath', memberId: off.memberId}, dataset.legacyDataset.window, true)).rejects.toThrow();
    expect(queries).toBe(0);
  });
  it('rejects data mutation or consent revocation between query and transaction', async () => {
    const r = reader(), target = {organizationId: 'gainpath', memberId: dataset.memberIds[0]};
    mutateAfterQuery = () => {base.documents.get(dataset.observations[0].path)!.digest = '0'.repeat(64);};
    await expect(r.read(target, dataset.legacyDataset.window, true)).rejects.toThrow();
  });
  it('rejects consent revocation after query and does not return partial rows', async () => {
    const r = reader(), target = {organizationId: 'gainpath', memberId: dataset.memberIds[0]};
    mutateAfterQuery = () => {base.documents.delete(`${FYP_ROOT}/recommendationConsent/${target.memberId}`);};
    await expect(r.read(target, dataset.legacyDataset.window, true)).rejects.toThrow();
  });
  it.each(['deleted', 'moved-date'])('rejects %s source before query without silently dropping it', async mode => {
    const r = reader(), target = {organizationId: 'gainpath', memberId: dataset.memberIds[0]}, p = dataset.observations[0].path;
    if (mode === 'deleted') base.documents.delete(p); else base.documents.get(p)!.observedAtMillis = now + 1000;
    await expect(r.read(target, dataset.legacyDataset.window, true)).rejects.toThrow();
  });
  it('rejects an over-bound query and invalid source paths', async () => {
    const r = reader(), target = {organizationId: 'gainpath', memberId: dataset.memberIds[0]};
    reportedSize = 101; await expect(r.read(target, dataset.legacyDataset.window, true)).rejects.toThrow('reviewed bound');
    reportedSize = undefined;
    (dataset.source.observationPathsByMember as Record<string, string[]>)[target.memberId] = ['orgs/gainpath/members/real-person/workoutBackups/private'];
    await expect(r.rows(target.memberId)).rejects.toThrow();
  });
  it('rejects absent ownership, policy drift and a foreign Member request', async () => {
    const r = reader(), target = {organizationId: 'gainpath', memberId: dataset.memberIds[0]}, batch = await r.read(target, dataset.legacyDataset.window, true);
    base.documents.delete(`${FYP_ROOT}/seedOwnership/${fypDigest(dataset.observations[0].path)}`);
    await expect(r.rows(target.memberId)).rejects.toThrow();
    expect(await createFypScopedStore(base, scope).transact(tx => r.revalidate(tx, target, batch.sourceRevision, '0'.repeat(64)))).toBe(false);
    await setup('member');
    await expect(reader().rows(dataset.memberIds[1])).rejects.toThrow();
  });
  it('returns only Member-owned fictional history without recommendation consent', async () => {
    await setup('member'); const r = reader(), identity = dataset.identities.find(u => u.uid === scope.uid)!;
    base.documents.delete(`${FYP_ROOT}/recommendationConsent/${scope.uid}`);
    const result = await r.history({app: {appId: 'test'}, auth: {uid: scope.uid, token: {email_verified: true, email: identity.email, auth_time: now / 1000, fypAuthCreatedAtMillis: now - 1000}}, data: {schemaVersion: 1, organizationId: 'gainpath'}});
    expect(result).toMatchObject({schemaVersion: 1, fictional: true, provenance: 'recordedFixture', nextCursor: null}); expect(result.records).toHaveLength(3);
    await setup(); await expect(reader().history({data: {schemaVersion: 1}})).rejects.toThrow();
  });
});
