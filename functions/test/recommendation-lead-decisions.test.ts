import {expect, it} from 'vitest';
import {DomainError} from '../src/platform/errors';
import {createRecommendationLeadDecision} from '../src/modules/recommendation/recommendation-lead-decisions';
import {readRecommendationMemberState} from '../src/modules/recommendation/recommendation-queue-security';
import type {RecommendationLead} from '../src/modules/recommendation/recommendation-queue-contracts';
import {parseRecommendationLead} from '../src/modules/recommendation/recommendation-queue-contracts';
import {queueSecurityFixture} from './recommendation-queue-fixture';
const org = 'synthetic-org', leadPath = `orgs/${org}/recommendationLeads/lead-1`;
async function fixture(ai = false) {
  const base = await queueSecurityFixture(ai ? ['exerciseInsights', 'recommendationGeneration', 'recommendationDelivery', 'externalAiInference'] : undefined);
  const state = await base.store.transact(tx => readRecommendationMemberState(tx, {organizationId: org, memberId: 'member'}, 200000, base.deps.noticePolicies!, ['exerciseInsights', 'recommendationGeneration']));
  const lead: RecommendationLead = {schemaVersion: 1, mode: 'synthetic_local', leadId: 'lead-1', organizationId: org,
    memberId: 'member', kind: 'trainer', exerciseId: 'squat', objective: 'technique_foundations', level: 'beginner', memberLabel: 'Synthetic Member',
    exerciseLabel: 'Squat', category: 'Strength', targetLabel: 'Synthetic Coach', specialization: 'Foundations', branchLabel: 'Synthetic Branch',
    target: {kind: 'trainer', coachId: 'coach', branchId: 'branch', observedStartAtMillis: 300000, observedEndAtMillis: 2100000},
    evidence: {summary: 'Synthetic fixture evidence only.', scoredSessions: 3, estimatedFormScorePercent: 65, coverage: 0.8, sourceVersion: 'fixture-v1', configVersion: 'fixture-v1'},
    ranking: {origin: ai ? 'ai_reranked' : 'deterministic_fallback', reasonCodes: ['exercise_match'], explanations: ['Reviewed mapping supports this exercise.'], model: ai ? 'mock-model' : null,
      promptVersion: 'module13-rank-v1', algorithmVersion: 'fixture-v1', fallbackReason: ai ? null : 'provider_not_configured'},
    sourceFingerprint: 'a'.repeat(64), memberFingerprint: state.fingerprint, runId: 'run-1', createdAtMillis: 190000, expiresAtMillis: 400000, status: 'pending', revision: 1, decision: null};
  base.store.documents.set(leadPath, lead as unknown as Record<string, unknown>);
  let validationCalls = 0;
  const deps = {...base.deps, validateTarget: async (tx: {get: unknown; create?: unknown}, current: RecommendationLead): Promise<'valid' | 'stale'> => {
    validationCalls++; expect(tx.create).toBeUndefined(); expect(current.target).toEqual(lead.target); return 'valid';
  }};
  const request = {...base.request, data: {schemaVersion: 1, organizationId: org, commandId: 'decision-1', leadId: lead.leadId, expectedRevision: 1, action: 'send', reason: null as string | null}};
  return {...base, deps, request, lead, validationCalls: () => validationCalls, run: createRecommendationLeadDecision(deps)};
}
it('refuses future-created leads without persisting an earlier decision',async()=>{
  const f=await fixture();f.store.documents.get(leadPath)!.createdAtMillis=300000;const before=JSON.stringify([...f.store.documents]);
  await expect(f.run(f.request)).rejects.toMatchObject({code:'failed-precondition'});expect(JSON.stringify([...f.store.documents])).toBe(before);
});
it('rejects terminal lead records missing the durable recipient or dismissal reason',async()=>{
  const f=await fixture();const decision={actorId:'admin',commandId:'test',atMillis:200000,reason:null,recipientRecommendationId:null};
  expect(()=>parseRecommendationLead({...f.lead,status:'sent',revision:2,decision},org)).toThrow();
  expect(()=>parseRecommendationLead({...f.lead,status:'dismissed',revision:2,decision},org)).toThrow();
});
it('atomically prepares a Member recipient draft, status, immutable audit and idempotent actor-bound receipt', async () => {
  const {store, request, run, validationCalls} = await fixture();
  const result = await run(request);
  expect(result).toMatchObject({status: 'sent', revision: 2, outcome: 'prepared', deliveryStatus: 'prepared_local'});
  const recipients = [...store.documents].filter(([path]) => path.includes('/recommendationRecipients/'));
  expect(recipients).toHaveLength(1);
  expect(recipients[0][1]).toMatchObject({status: 'prepared', memberId: 'member', memberReadAtMillis: null, acknowledgedAtMillis: null,
    notificationDraft: {schemaVersion: 1, type: 'recommendation', recipientId: 'member', read: false}});
  const snapshot = JSON.stringify([...store.documents]);
  expect(await run(request)).toEqual(result);
  expect(JSON.stringify([...store.documents])).toBe(snapshot);
  expect([...store.documents.keys()].filter(path => path.includes('/recommendationDecisionAudits/'))).toHaveLength(1);
  expect([...store.documents.keys()].some(path => path.includes('/notifications/'))).toBe(false);
  expect(validationCalls()).toBe(1);
});
it('dismisses with a persisted meaningful reason even after Member consent and target access have been revoked', async () => {
  const {store, request, deps} = await fixture();
  store.documents.delete(`orgs/${org}/recommendationConsent/member`);
  store.documents.set('users/member', {organizationId: org, role: 'member', accountLifecycle: {schemaVersion: 1, state: 'deleting', revocationPending: true, sessionNotBeforeSeconds: 0}});
  const run = createRecommendationLeadDecision({...deps, readAuthIdentity: async uid => {if (uid === 'member') throw Error('Must not read dismissed target Auth'); return deps.readAuthIdentity(uid);}, validateTarget: async () => {throw Error('Must not validate dismissed target');}});
  expect(await run({...request, data: {...request.data, action: 'dismiss', reason: 'The learning objective needs review.'}})).toMatchObject({status: 'dismissed', outcome: 'dismissed', recipientRecommendationId: null});
  expect(store.documents.get(leadPath)).toMatchObject({decision: {reason: 'The learning objective needs review.'}});
  expect([...store.documents.keys()].some(path => path.includes('/recommendationRecipients/'))).toBe(false);
});
it.each(['', 'short', '        ', '!!!!!!!!', 'x'.repeat(301), 'Invalid\nreason'])(
  'rejects a nonmeaningful dismissal reason %s without writes', async reason => {
    const {store, request, run} = await fixture(); const snapshot = JSON.stringify([...store.documents]);
    await expect(run({...request, data: {...request.data, action: 'dismiss', reason}})).rejects.toMatchObject({code: 'invalid-argument'});
    expect(JSON.stringify([...store.documents])).toBe(snapshot);
  });
it.each(['exerciseInsights', 'recommendationGeneration', 'recommendationDelivery'])(
  'durably blocks a send after %s permission is revoked', async purpose => {
    const {store, request, run} = await fixture();
    const c = structuredClone(store.documents.get(`orgs/${org}/recommendationConsent/member`)!);
    const p = c.purposes as Record<string, Record<string, unknown>>;
    p[purpose] = {...p[purpose], granted: false, revision: Number(p[purpose].revision) + 1, revokedAtMillis: 200000}; c.revision = Number(c.revision) + 1;
    store.documents.set(`orgs/${org}/recommendationConsent/member`, c);
    expect(await run(request)).toMatchObject({status: 'revoked', outcome: 'blocked', deliveryStatus: 'not_prepared'});
    expect(store.documents.get(leadPath)).toMatchObject({status: 'revoked', revision: 2});
    expect([...store.documents.keys()].some(path => path.includes('/recommendationRecipients/'))).toBe(false);
  });
it('requires external AI purpose again for a lead that used inference', async () => {
  const {store, request, run} = await fixture(true);
  const c = structuredClone(store.documents.get(`orgs/${org}/recommendationConsent/member`)!);
  const p = c.purposes as Record<string, Record<string, unknown>>;
  p.externalAiInference = {...p.externalAiInference, granted: false, revision: 2, revokedAtMillis: 200000}; c.revision = 5;
  store.documents.set(`orgs/${org}/recommendationConsent/member`, c);
  expect(await run(request)).toMatchObject({status: 'revoked', outcome: 'blocked'});
});
it.each(['expired', 'stale'] as const)('durably marks a current pending lead %s without preparing a recipient', async status => {
  const {store, request, deps, lead} = await fixture();
  if (status === 'expired') store.documents.set(leadPath, {...lead, expiresAtMillis: 200000});
  const run = createRecommendationLeadDecision({...deps, validateTarget: async () => status === 'stale' ? 'stale' : 'valid'});
  expect(await run(request)).toMatchObject({status, outcome: 'blocked'});
  expect([...store.documents.keys()].some(path => path.includes('/recommendationRecipients/'))).toBe(false);
});
it('detects a changed current Member fingerprint', async () => {
  const {store, run, request} = await fixture();
  store.documents.set(`orgs/${org}/members/member`, {organizationId: org, userId: 'member', role: 'member', status: 'active', branchIds: ['new-branch']});
  expect(await run(request)).toMatchObject({status: 'stale', outcome: 'blocked'});
});
it('rejects stale expected revisions and changed requests under the same actor command ID', async () => {
  const {store, request, run} = await fixture(); await run(request); const snapshot = JSON.stringify([...store.documents]);
  await expect(run({...request, data: {...request.data, action: 'dismiss', reason: 'Reviewed and dismissed.'}})).rejects.toMatchObject({code: 'aborted'});
  await expect(run({...request, data: {...request.data, commandId: 'new-command'}})).rejects.toMatchObject({code: 'aborted'});
  expect(JSON.stringify([...store.documents])).toBe(snapshot);
});
it.each(['target', 'member_auth'] as const)('sanitizes %s source failures with no writes', async source => {
  const {store, request, deps} = await fixture(); const snapshot = JSON.stringify([...store.documents]);
  const run = createRecommendationLeadDecision({...deps,
    ...(source === 'target' ? {validateTarget: async () => {throw new DomainError('unavailable', 'private provider body');}} :
      {readAuthIdentity: async (uid: string) => {if (uid === 'member') throw Error('private recipient email'); return deps.readAuthIdentity(uid);}})});
  await expect(run(request)).rejects.toMatchObject({code: 'unavailable', message: expect.not.stringContaining('private')});
  expect(JSON.stringify([...store.documents])).toBe(snapshot);
});
it('blocks a disabled current Member Auth account', async () => {
  const {request, deps} = await fixture();
  const run = createRecommendationLeadDecision({...deps, readAuthIdentity: async uid => ({...await deps.readAuthIdentity(uid), disabled: uid === 'member'})});
  expect(await run(request)).toMatchObject({status: 'revoked', outcome: 'blocked'});
});
it('serializes two sends and a competing send/dismiss into exactly one decision', async () => {
  for (const action of ['send', 'dismiss']) {
    const {store, request, run} = await fixture();
    const results = await Promise.allSettled([run(request), run({...request, data: {...request.data, action, commandId: 'competitor', reason: action === 'dismiss' ? 'Reviewed and dismissed.' : null}})]);
    expect(results.filter(result => result.status === 'fulfilled')).toHaveLength(1);
    expect([...store.documents.keys()].filter(path => path.includes('/recommendationDecisionAudits/'))).toHaveLength(1);
    expect([...store.documents.keys()].filter(path => path.includes('/recommendationRecipients/')).length).toBeLessThanOrEqual(1);
  }
});
it('rejects coercible action, extra fields, delivery metadata and missing explicit fixture composition', async () => {
  const {store, request, run, deps} = await fixture(); const snapshot = JSON.stringify([...store.documents]);
  for (const data of [{...request.data, action: ['send']}, {...request.data, recipientId: 'other'}, {...request.data, reason: 'not permitted for send'}]) {
    await expect(run({...request, data})).rejects.toMatchObject({code: 'invalid-argument'});
  }
  await expect(createRecommendationLeadDecision({...deps, localFixture: undefined})(request)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(JSON.stringify([...store.documents])).toBe(snapshot);
});
it('binds the final lead to the protected pre-Auth read even if a source changes immutable fields without revising it', async () => {
  const {deps, request, store, lead} = await fixture();
  const run = createRecommendationLeadDecision({...deps, readAuthIdentity: async uid => {
    if (uid === 'member') store.documents.set(leadPath, {...lead, targetLabel: 'Changed outside revision'});
    return deps.readAuthIdentity(uid);
  }});
  await expect(run(request)).rejects.toMatchObject({code: 'aborted'});
  expect([...store.documents.keys()].some(path => path.includes('/recommendationRecipients/'))).toBe(false);
});
it('accepts meaningful local-language dismissal reasons', async () => {
  const {request, run} = await fixture();
  expect(await run({...request, data: {...request.data, action: 'dismiss', reason: '建议先查看当前训练目标'}})).toMatchObject({status: 'dismissed'});
});
it('never prepares the same logical recommendation twice through a second lead alias', async () => {
  const {store, request, run, lead} = await fixture(); await run(request);
  store.documents.set(`orgs/${org}/recommendationLeads/lead-alias`, {...lead, leadId: 'lead-alias'});
  const snapshot = JSON.stringify([...store.documents]);
  await expect(run({...request, data: {...request.data, leadId: 'lead-alias', commandId: 'alias-command'}})).rejects.toMatchObject({code: 'aborted'});
  expect(JSON.stringify([...store.documents])).toBe(snapshot);
});
it('replays an identical concurrent command once and binds command identity to its actor', async () => {
  const {store, request, run} = await fixture();
  const results = await Promise.all([run(request), run(request)]); expect(results[0]).toEqual(results[1]);
  store.documents.set('users/other-admin', {organizationId: org, role: 'admin'});
  store.documents.set(`orgs/${org}/members/other-admin`, {organizationId: org, role: 'admin', status: 'active', branchIds: []});
  const other = {...request, auth: {uid: 'other-admin', token: {...request.auth.token, email: 'other-admin@example.invalid'}}};
  await expect(run(other)).rejects.toMatchObject({code: 'aborted'});
  expect([...store.documents.keys()].filter(path => path.includes('/recommendationCommandReceipts/'))).toHaveLength(1);
});
it('rejects inconsistent stored receipt state and revisions', async () => {
  for (const tamper of [{status: 'pending', outcome: 'blocked', recipientRecommendationId: null, deliveryStatus: 'not_prepared'}, {revision: 99}]) {
    const {store, request, run} = await fixture(); await run(request);
    const [path, receipt] = [...store.documents].find(([path]) => path.includes('/recommendationCommandReceipts/'))!;
    store.documents.set(path, {...receipt, result: {...receipt.result as object, ...tamper}});
    const snapshot = JSON.stringify([...store.documents]);
    await expect(run(request)).rejects.toMatchObject({code: 'failed-precondition'});
    expect(JSON.stringify([...store.documents])).toBe(snapshot);
  }
});
