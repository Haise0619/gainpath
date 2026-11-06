import {expect, it} from 'vitest';
import {authorizeQueue, readRecommendationMemberState, requireSyntheticQueue} from '../src/modules/recommendation/recommendation-queue-security';
import {queueSecurityFixture} from './recommendation-queue-fixture';
const org = 'synthetic-org', scope = {organizationId: org, memberId: 'member'};
it('fails closed unless the trusted fixture dependency and synthetic organization match exactly', async () => {
  const {deps} = await queueSecurityFixture();
  expect(() => requireSyntheticQueue({...deps, localFixture: undefined}, org)).toThrow();
  expect(() => requireSyntheticQueue(deps, 'production-org')).toThrow();
  expect(() => requireSyntheticQueue({...deps, localFixture: {...deps.localFixture!, fixtureSetId: ['module13-c-v1'] as never}}, org)).toThrow();
  expect(() => requireSyntheticQueue(deps, org)).not.toThrow();
});
it('requires verified current Auth, App Check and canonical current Admin membership', async () => {
  const {deps, request, store} = await queueSecurityFixture();
  expect(await authorizeQueue(request, deps)).toMatchObject({auth: request.auth, organizationId: org, now: 200000});
  await expect(authorizeQueue({...request, app: undefined}, deps)).rejects.toMatchObject({code: 'unauthenticated'});
  await expect(authorizeQueue(request, {...deps, readAuthIdentity: async uid => ({uid, email: 'admin@example.invalid', disabled: true, emailVerified: true, tokensValidAfterMillis: 0})})).rejects.toMatchObject({code: 'unauthenticated'});
  store.documents.set('users/admin', {organizationId: org, role: 'admin', accountLifecycle: {schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: 101}});
  await expect(authorizeQueue(request, deps)).rejects.toMatchObject({code: 'permission-denied'});
});
it('reads canonical Member and full v2 purpose consent without writing or exposing raw records', async () => {
  const {deps, store} = await queueSecurityFixture();
  const snapshot = JSON.stringify([...store.documents]);
  const state = await store.transact(tx => readRecommendationMemberState(tx, scope, 200000, deps.noticePolicies!, ['exerciseInsights', 'recommendationGeneration']));
  expect(state).toEqual({eligible: true, fingerprint: expect.stringMatching(/^[0-9a-f]{64}$/), consentRevision: 3});
  expect(JSON.stringify([...store.documents])).toBe(snapshot);
  expect(await store.transact(tx => readRecommendationMemberState(tx, scope, 200000, deps.noticePolicies!, ['externalAiInference']))).toMatchObject({eligible: false});
});
it.each([
  ['users/member', {organizationId: 'foreign', role: 'member'}],
  ['users/member', {organizationId: org, role: 'coach'}],
  ['users/member', {organizationId: org, role: 'member', accountLifecycle: {schemaVersion: 1, state: 'disabled', revocationPending: false, sessionNotBeforeSeconds: 0}}],
  [`orgs/${org}/members/member`, {organizationId: org, role: 'member', status: 'inactive', branchIds: []}],
  [`orgs/${org}/members/member`, {organizationId: org, role: 'member', status: 'active', userId: 'other', branchIds: []}],
] as const)('rejects invalid canonical Member identity %s', async (path, raw) => {
  const {deps, store} = await queueSecurityFixture(); store.documents.set(path, raw);
  expect(await store.transact(tx => readRecommendationMemberState(tx, scope, 200000, deps.noticePolicies!, ['exerciseInsights']))).toMatchObject({eligible: false});
});

it('rejects array-coerced membership roles even where legacy generic membership parsing is permissive', async () => {
  const {deps, request, store} = await queueSecurityFixture();
  store.documents.set('users/admin', {organizationId: org});
  store.documents.set(`orgs/${org}/members/admin`, {organizationId: org, role: ['admin'], status: 'active', branchIds: []});
  await expect(authorizeQueue(request, deps)).rejects.toMatchObject({code: 'permission-denied'});
  store.documents.set('users/member', {organizationId: org});
  store.documents.set(`orgs/${org}/members/member`, {organizationId: org, role: ['member'], status: 'active', branchIds: []});
  expect(await store.transact(tx => readRecommendationMemberState(tx, scope, 200000, deps.noticePolicies!, ['exerciseInsights']))).toMatchObject({eligible: false});
});
