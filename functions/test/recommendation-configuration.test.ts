import {expect, it} from 'vitest';
import {MemoryStore} from './memory-store';
import {createRecommendationConfigurationCommand, defaultRecommendationConfiguration, type ReviewedRecommendationPolicy} from '../src/modules/recommendation/recommendation-configuration';
import {DomainError} from '../src/platform/errors';

const auth = {uid: 'admin', token: {email_verified: true, email: 'admin@example.invalid', auth_time: 100}};
const reviewed: ReviewedRecommendationPolicy = {policyId: 'synthetic-only', reviewVersion: 'review-1',
  compatibility: {exerciseId: 'F3b8xIr8ynBDd3gEICKX', metricSchemaVersion: 1, scoringVersion: 'bodyweight-squat-side-v1',
    detectorId: 'blazepose-tflite', detectorVersion: 'mediapipe-full-e9a5c5cb-det-9ba9dd3d', cameraView: 'side', mode: 'not_applicable', scoreSupport: 'scored'},
  provisionalSamplePolicy: {schemaVersion: 1, revision: 'synthetic-1', minimumScoredSessions: 2, minimumDistinctDays: 2, minimumAssessedAttempts: 10, minimumTrackingCoverage: 0.8},
  attentionThreshold: {operator: 'score_below', estimatedFormScorePercent: 60}, cohortEligibility: {minimumMembersMeetingProvisionalMinimums: 3}};
function fixture(reviewedPolicies: readonly ReviewedRecommendationPolicy[] = []) {
  const store = new MemoryStore();
  store.documents.set('orgs/gainpath', {status: 'active'});
  store.documents.set('users/admin', {organizationId: 'gainpath', role: 'admin'});
  store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});
  const run = createRecommendationConfigurationCommand({store, reviewedPolicies, clock: () => 1000000,
    readAuthIdentity: async uid => ({uid, email: 'admin@example.invalid', emailVerified: true, disabled: false, tokensValidAfterMillis: 0})});
  const request = {app: {appId: 'test'}, auth, data: {schemaVersion: 1, organizationId: 'gainpath', commandId: 'one', expectedRevision: 0, policyIds: []}};
  return {store, run, request};
}
it('defaults every activation gate and policy off', () => {
  expect(defaultRecommendationConfiguration('gainpath')).toMatchObject({revision: 0, policies: [], activation: {
    generation: false, externalAi: false, matching: false, delivery: false}});
});
it('atomically records configuration, audit and idempotent receipt; rejects stale revisions', async () => {
  const {store, run, request} = fixture();
  const result = await run(request); expect(result.revision).toBe(1);
  const snapshot = JSON.stringify([...store.documents]);
  expect(await run(request)).toEqual(result); expect(JSON.stringify([...store.documents])).toBe(snapshot);
  await expect(run({...request, data: {...request.data, commandId: 'two'}})).rejects.toMatchObject({code: 'aborted'});
  expect([...store.documents.keys()].filter(p => p.includes('recommendationConfigurationAudit'))).toHaveLength(1);
});
it('does not let Admin self approve thresholds or unknown policies', async () => {
  const {run, request} = fixture();
  await expect(run({...request, data: {...request.data, policyIds: ['admin-approved']}})).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(run({...request, data: {...request.data, attentionThreshold: 90}})).rejects.toMatchObject({code: 'invalid-argument'});
});
it('rechecks current auth and canonical Admin organization with App Check', async () => {
  const {run, request, store} = fixture();
  await expect(run({...request, app: undefined})).rejects.toMatchObject({code: 'unauthenticated'});
  store.documents.set('users/admin', {organizationId: 'foreign', role: 'admin'});
  await expect(run(request)).rejects.toMatchObject({code: 'permission-denied'});
});
it('accepts only the exact injected group policy and leaves every activation gate off', async () => {
  const {run, request} = fixture([reviewed]);
  const result = await run({...request, data: {...request.data, policyIds: ['synthetic-only']}});
  expect(result.policies).toEqual([reviewed]);
  expect(Object.values(result.activation)).toEqual([false, false, false, false]);
});
it('rejects wildcard compatibility, duplicate groups and thresholds without provisional samples', async () => {
  for (const bad of [{...reviewed, compatibility: {...reviewed.compatibility, exerciseId: '*'}},
    {...reviewed, provisionalSamplePolicy: null}]) {
    const {run, request} = fixture([bad]);
    await expect(run({...request, data: {...request.data, policyIds: ['synthetic-only']}})).rejects.toMatchObject({code: 'invalid-argument'});
  }
  const {run, request} = fixture([reviewed, {...reviewed, policyId: 'same-group'}]);
  await expect(run({...request, data: {...request.data, policyIds: ['synthetic-only', 'same-group']}})).rejects.toMatchObject({code: 'invalid-argument'});
});
it('serializes competing revisions and rejects changed requests under an existing command ID', async () => {
  const {run, request, store} = fixture();
  const results = await Promise.allSettled([run(request), run({...request, data: {...request.data, commandId: 'two'}})]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect(store.documents.get('orgs/gainpath/recommendationConfiguration/current')?.revision).toBe(1);
  await expect(run({...request, data: {...request.data, expectedRevision: 1}})).rejects.toMatchObject({code: 'aborted'});
});
it('sanitizes typed provider failures without exposing provider text', async () => {
  const {store, request} = fixture();
  const run = createRecommendationConfigurationCommand({store, readAuthIdentity: async () => {throw new DomainError('permission-denied', 'private-member@example.invalid');}});
  await expect(run(request)).rejects.toMatchObject({code: 'permission-denied', message: 'Current organization access is required.'});
});
it('rejects coerced nonliteral compatibility fields in a reviewed policy', async () => {
  const malformed = structuredClone(reviewed);
  (malformed.compatibility as unknown as Record<string, unknown>).cameraView = ['side'];
  const {run, request} = fixture([malformed]);
  await expect(run({...request, data: {...request.data, policyIds: ['synthetic-only']}})).rejects.toMatchObject({code: 'invalid-argument'});
});
