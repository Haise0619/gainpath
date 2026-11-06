import {expect, it} from 'vitest';
import {MemoryStore} from './memory-store';
import {createRecommendationConsentV2Command, evaluateRecommendationConsentV2, type ReviewedConsentNoticePolicy} from '../src/modules/recommendation/recommendation-consent-v2';
import {exerciseInsightsHandler} from '../src/modules/recommendation/exercise-insights';
import type {ExerciseInsightsDependencies} from '../src/modules/recommendation/exercise-insights-contracts';
const scope = {organizationId: 'gainpath', memberId: 'member'};
const notice: ReviewedConsentNoticePolicy = {policyId: 'reviewed', noticeVersion: 'notice-v2', contentVersion: 'content-v2', history: {mode: 'from_grant'}};
it('rejects a nonliteral action without silently revoking consent', async () => {
  const {run, request, store} = fixture();
  const {noticePolicyId: _policy, acceptedNoticeVersion: _notice, acceptedContentVersion: _content, ...base} = request.data;
  await expect(run({...request, data: {...base, action: ['revoke']}})).rejects.toMatchObject({code: 'invalid-argument'});
  expect(store.documents.has('orgs/gainpath/recommendationConsent/member')).toBe(false);
});
function fixture(noticePolicy: ReviewedConsentNoticePolicy = notice) {
  const store = new MemoryStore();
  store.documents.set('orgs/gainpath', {status: 'active'});
  store.documents.set('users/member', {organizationId: 'gainpath', role: 'member'});
  store.documents.set('orgs/gainpath/members/member', {organizationId: 'gainpath', role: 'member', status: 'active', branchIds: []});
  const run = createRecommendationConsentV2Command({store, clock: () => 200000,
    noticePolicies: [noticePolicy], readAuthIdentity: async uid => ({uid, email: 'member@example.invalid', emailVerified: true, disabled: false, tokensValidAfterMillis: 0})});
  const request = {app: {appId: 'test'}, auth: {uid: 'member', token: {email_verified: true, email: 'member@example.invalid', auth_time: 100}},
    data: {schemaVersion: 2, organizationId: 'gainpath', commandId: 'grant', expectedRevision: 0,
      purpose: 'exerciseInsights', action: 'grant', noticePolicyId: 'reviewed', acceptedNoticeVersion: 'notice-v2', acceptedContentVersion: 'content-v2'}};
  return {store, run, request};
}
it('grants one independent purpose and enforces history boundary and trusted notice', async () => {
  const {store, run, request} = fixture(); const result = await run(request);
  expect(JSON.stringify(result)).not.toContain('memberId');
  const raw = store.documents.get('orgs/gainpath/recommendationConsent/member');
  expect(evaluateRecommendationConsentV2(raw, scope, 200000, [notice])).toMatchObject({allowed: true, revision: 1, historyStartAtMillis: 200000});
  expect(evaluateRecommendationConsentV2(raw, scope, 200000)).toMatchObject({allowed: false});
  expect((raw!.purposes as Record<string, {granted: boolean}>).externalAiInference.granted).toBe(false);
  expect(await run(request)).toEqual(result);
});
it('allows retained history only when the matched injected reviewed notice defines the exact lower boundary', async () => {
  const retained: ReviewedConsentNoticePolicy = {...notice, history: {mode: 'retained', earliestAtMillis: 100000}};
  const {run, request, store} = fixture(retained); await run(request);
  const raw = store.documents.get('orgs/gainpath/recommendationConsent/member');
  expect(evaluateRecommendationConsentV2(raw, scope, 200000, [retained])).toMatchObject({allowed: true, historyStartAtMillis: 100000});
  expect(evaluateRecommendationConsentV2(raw, scope, 200000, [notice])).toMatchObject({allowed: false});
});
it('does not infer any grant from camera or backup flags or accept another Member identity', () => {
  expect(evaluateRecommendationConsentV2({cameraConsent: true, backupConsent: true}, scope, 200000, [notice])).toMatchObject({allowed: false});
});
it.each(['exerciseInsights', 'recommendationGeneration', 'externalAiInference', 'recommendationDelivery'])(
  'records %s as an independent explicit grant without enabling the other purposes', async purpose => {
    const {run, request, store} = fixture();
    await run({...request, data: {...request.data, purpose}});
    const raw = store.documents.get('orgs/gainpath/recommendationConsent/member')!;
    const states = raw.purposes as Record<string, {granted: boolean; revision: number}>;
    for (const [name, state] of Object.entries(states)) expect(state).toMatchObject({granted: name === purpose, revision: name === purpose ? 1 : 0});
    expect(evaluateRecommendationConsentV2(raw, {...scope, memberId: 'foreign'}, 200000, [notice])).toMatchObject({allowed: false});
    expect(evaluateRecommendationConsentV2(raw, {...scope, organizationId: 'foreign'}, 200000, [notice])).toMatchObject({allowed: false});
  });
it('requires current verified Auth, App Check, current canonical Member role and organization', async () => {
  const {run, request, store} = fixture();
  await expect(run({...request, app: undefined})).rejects.toMatchObject({code: 'unauthenticated'});
  await expect(run({...request, auth: {...request.auth, token: {...request.auth.token, email: 'changed@example.invalid'}}})).rejects.toMatchObject({code: 'unauthenticated'});
  store.documents.set('orgs/gainpath/members/member', {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});
  await expect(run(request)).rejects.toMatchObject({code: 'permission-denied'});
  expect(store.documents.has('orgs/gainpath/recommendationConsent/member')).toBe(false);
});
it('records immutable audit receipts once, rejects stale concurrent revisions and does not migrate v1', async () => {
  const {run, request, store} = fixture();
  const concurrent = await Promise.allSettled([run(request), run({...request, data: {...request.data, commandId: 'other'}})]);
  expect(concurrent.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect([...store.documents.keys()].filter(p => p.includes('/recommendationConsentAudit/'))).toHaveLength(1);
  await expect(run({...request, data: {...request.data, expectedRevision: 1}})).rejects.toMatchObject({code: 'aborted'});
  store.documents.set('orgs/gainpath/recommendationConsent/member', {schemaVersion: 1, revision: 1});
  await expect(run({...request, data: {...request.data, commandId: 'new-command', expectedRevision: 1}})).rejects.toMatchObject({code: 'failed-precondition'});
});
it('fails closed before broad history reads for pre-grant queries or missing scoped adapter', async () => {
  const {run, request, store} = fixture(); await run(request);
  store.documents.set('users/admin', {organizationId: 'gainpath', role: 'admin'});
  store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});
  let broadReads = 0, scopedReads = 0;
  const deps: ExerciseInsightsDependencies & {consentNoticePolicies: readonly ReviewedConsentNoticePolicy[]} = {store, clock: () => 300000,
    consentNoticePolicies: [notice], readAuthIdentity: async uid => ({uid, email: 'admin@example.invalid', emailVerified: true, disabled: false, tokensValidAfterMillis: 0}),
    reader: {members: async () => [{id: 'member', data: store.documents.get('orgs/gainpath/members/member')!}],
      backups: async () => {broadReads++; return [];}}};
  const insightRequest = {app: {appId: 'test'}, auth: {uid: 'admin', token: {email_verified: true, email: 'admin@example.invalid', auth_time: 100}},
    data: {schemaVersion: 1, organizationId: 'gainpath', startAtMillis: 100000, endAtMillis: 250000}};
  expect(await exerciseInsightsHandler(insightRequest, deps)).toMatchObject({status: 'no_consented_members'});
  expect(broadReads).toBe(0);
  insightRequest.data.startAtMillis = 200000;
  await expect(exerciseInsightsHandler(insightRequest, deps)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(broadReads).toBe(0);
  deps.reader.consentScopedBackups = async (s, window) => {
    scopedReads++; expect(s).toEqual(scope); expect(window).toEqual({startAtMillis: 200000, endAtMillis: 250000}); return [];
  };
  expect(await exerciseInsightsHandler(insightRequest, deps)).toMatchObject({coverage: {consentedMembers: 1}});
  expect(scopedReads).toBe(1); expect(broadReads).toBe(0);
  deps.reader.consentScopedBackups = async () => {
    scopedReads++;
    const c = store.documents.get('orgs/gainpath/recommendationConsent/member')!;
    const purposes = c.purposes as Record<string, object>;
    store.documents.set('orgs/gainpath/recommendationConsent/member', {...c, revision: 2,
      purposes: {...purposes, exerciseInsights: {...purposes.exerciseInsights, granted: false, revision: 2, revokedAtMillis: 200000}}});
    return [];
  };
  await expect(exerciseInsightsHandler(insightRequest, deps)).rejects.toMatchObject({code: 'aborted'});
});
it('explicit revoke is revisioned, idempotent and does not grant another purpose', async () => {
  const {store, run, request} = fixture(); await run(request);
  const revoke = {...request, data: {schemaVersion: 2, organizationId: 'gainpath', commandId: 'revoke', expectedRevision: 1, purpose: 'exerciseInsights', action: 'revoke'}};
  expect(await run(revoke)).toMatchObject({revision: 2, granted: false});
  expect(await run(revoke)).toMatchObject({revision: 2});
  expect(evaluateRecommendationConsentV2(store.documents.get('orgs/gainpath/recommendationConsent/member'), scope, 200000, [notice])).toMatchObject({allowed: false, reason: 'revoked'});
});
it('rejects request asserted historical approval, stale notices, foreign ownership and stale session', async () => {
  const {store, run, request} = fixture();
  await expect(run({...request, data: {...request.data, retainedHistoryApproved: true}})).rejects.toMatchObject({code: 'invalid-argument'});
  await expect(run({...request, data: {...request.data, acceptedContentVersion: 'old'}})).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(run({...request, data: {...request.data, memberId: 'another'}})).rejects.toMatchObject({code: 'invalid-argument'});
  store.documents.set('users/member', {organizationId: 'gainpath', role: 'member', accountLifecycle: {schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: 101}});
  await expect(run(request)).rejects.toMatchObject({code: 'permission-denied'});
});

it.each(['exerciseInsights', 'recommendationGeneration', 'externalAiInference', 'recommendationDelivery'] as const)(
  'evaluates the selected %s purpose independently while retaining default insight behavior', async purpose => {
    const {run, request, store} = fixture();
    await run({...request, data: {...request.data, purpose}});
    const raw = store.documents.get('orgs/gainpath/recommendationConsent/member');
    expect(evaluateRecommendationConsentV2(raw, scope, 200000, [notice], purpose)).toMatchObject({allowed: true});
    expect(evaluateRecommendationConsentV2(raw, scope, 200000, [notice])).toMatchObject({allowed: purpose === 'exerciseInsights'});
  });
it('still validates all purpose states when checking a different selected grant', async () => {
  const {run, request, store} = fixture();
  await run({...request, data: {...request.data, purpose: 'recommendationDelivery'}});
  const raw = structuredClone(store.documents.get('orgs/gainpath/recommendationConsent/member')!);
  (raw.purposes as Record<string, Record<string, unknown>>).exerciseInsights.granted = 'yes';
  expect(evaluateRecommendationConsentV2(raw, scope, 200000, [notice], 'recommendationDelivery')).toMatchObject({allowed: false, reason: 'invalid'});
});
it('fails closed for a nonliteral selected purpose', async () => {
  const {run, request, store} = fixture(); await run(request);
  const raw = store.documents.get('orgs/gainpath/recommendationConsent/member');
  expect(evaluateRecommendationConsentV2(raw, scope, 200000, [notice], ['exerciseInsights'] as never)).toMatchObject({allowed: false, reason: 'invalid'});
});
