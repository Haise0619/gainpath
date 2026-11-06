import {MemoryStore} from './memory-store';
import type {QueueSecurityDependencies} from '../src/modules/recommendation/recommendation-queue-security';
import {createRecommendationConsentV2Command, type RecommendationPurpose, type ReviewedConsentNoticePolicy} from '../src/modules/recommendation/recommendation-consent-v2';
const org = 'synthetic-org';
const notice: ReviewedConsentNoticePolicy = {policyId: 'fixture-notice', noticeVersion: 'v1', contentVersion: 'v1', history: {mode: 'from_grant'}};
export async function queueSecurityFixture(purposes: readonly RecommendationPurpose[] = ['exerciseInsights', 'recommendationGeneration', 'recommendationDelivery']) {
  const store = new MemoryStore();
  store.documents.set(`orgs/${org}`, {status: 'active'});
  for (const [uid, role] of [['admin', 'admin'], ['member', 'member']]) {
    store.documents.set(`users/${uid}`, {organizationId: org, role});
    store.documents.set(`orgs/${org}/members/${uid}`, {organizationId: org, userId: uid, role, status: 'active', branchIds: []});
  }
  const deps: QueueSecurityDependencies = {store, localFixture: {fixtureSetId: 'module13-c-v1', organizationId: org},
    noticePolicies: [notice], clock: () => 200000,
    readAuthIdentity: async uid => ({uid, email: `${uid}@example.invalid`, emailVerified: true, disabled: false, tokensValidAfterMillis: 0})};
  const auth = {uid: 'admin', token: {email_verified: true, email: 'admin@example.invalid', auth_time: 100}};
  const request = {app: {appId: 'synthetic-app'}, auth, data: {schemaVersion: 1, organizationId: org}};
  const grant = createRecommendationConsentV2Command(deps);
  let revision = 0;
  for (const purpose of purposes) {
    await grant({...request, auth: {uid: 'member', token: {...auth.token, email: 'member@example.invalid'}}, data: {
      schemaVersion: 2, organizationId: org, commandId: `grant-${purpose}`, expectedRevision: revision++, purpose,
      action: 'grant', noticePolicyId: notice.policyId, acceptedNoticeVersion: notice.noticeVersion, acceptedContentVersion: notice.contentVersion}});
  }
  return {store, deps, request};
}

