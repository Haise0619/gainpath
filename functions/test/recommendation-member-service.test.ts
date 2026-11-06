import {expect, it} from 'vitest';
import {createRecommendationDelivery} from '../src/modules/recommendation/recommendation-delivery';
import {createMemberRecommendationService} from '../src/modules/recommendation/recommendation-member-service';
import {deliveryFixture} from './recommendation-delivery.fixture';

it.each(['trainer', 'content'] as const)('projects a current %s detail with only approved public fields', async kind => {
  const f = await deliveryFixture(false, kind); await createRecommendationDelivery(f.deps)(f.request);
  const result = await createMemberRecommendationService(f.deps)(f.memberRequest);
  expect(result).toMatchObject({state: 'available', kind, exerciseLabel: 'Squat', objective: 'technique_foundations', target: f.lead.target,
    targetLabel: kind === 'trainer' ? 'Current Fictional Coach' : 'Current Squat Tutorial', readAtMillis: null, acknowledgedAtMillis: null, dismissedAtMillis: null});
  expect(Object.keys(result).sort()).toEqual(['schemaVersion', 'mode', 'organizationId', 'recommendationId', 'kind', 'revision', 'state', 'title', 'summary',
    'exerciseLabel', 'objective', 'explanations', 'target', 'targetLabel', 'specialization', 'imageUrl', 'photoPath', 'createdAtMillis', 'deliveredAtMillis',
    'expiresAtMillis', 'readAtMillis', 'acknowledgedAtMillis', 'dismissedAtMillis'].sort());
  expect(JSON.stringify(result)).not.toMatch(/Private fixture|memberFingerprint|estimatedFormScorePercent|sourceFingerprint|memberId/);
});
it('redacts a prepared Admin-approved recommendation and never creates an inbox entry from get or resolve', async () => {
  const f = await deliveryFixture(), service = createMemberRecommendationService(f.deps), before = JSON.stringify([...f.store.documents]);
  for (const action of ['get', 'resolve']) expect(await service({...f.memberRequest, data: {...f.memberRequest.data, action}})).toMatchObject({state: 'not_delivered',
    revision: 0, target: null, exerciseLabel: null, explanations: [], targetLabel: null, objective: null});
  expect(JSON.stringify([...f.store.documents])).toBe(before);
});
it('keeps read, acknowledgment and dismissal independent, with scoped retry-safe receipts', async () => {
  const f = await deliveryFixture(); await createRecommendationDelivery(f.deps)(f.request);
  const service = createMemberRecommendationService(f.deps);
  const command = (action: string, expectedRevision: number) => ({...f.memberRequest, data: {...f.memberRequest.data, action, commandId: `d-${action}`, expectedRevision}});
  const acknowledged = await service(command('acknowledge', 1));
  expect(acknowledged).toMatchObject({revision: 2, acknowledgedAtMillis: 200000, readAtMillis: null, dismissedAtMillis: null});
  expect(await service(command('acknowledge', 1))).toEqual(acknowledged);
  const notice = () => [...f.store.documents].find(([p]) => p.includes('/notifications/'))![1];
  expect(notice().read).toBe(false);
  expect(await service(command('read', 2))).toMatchObject({revision: 3, readAtMillis: 200000, acknowledgedAtMillis: 200000});
  expect(notice().read).toBe(true);
  expect(await service(command('dismiss', 3))).toMatchObject({revision: 4, state: 'dismissed', dismissedAtMillis: 200000, readAtMillis: 200000,
    acknowledgedAtMillis: 200000, target: null, explanations: []});
  expect([...f.store.documents.keys()].filter(p => p.includes('/recommendationMemberCommandReceipts/'))).toHaveLength(3);
  expect([...f.store.documents.keys()].some(p => /booking|payment|reward|actedUpon/.test(p))).toBe(false);
});
it.each(['consent', 'target', 'expired'] as const)('redacts delivered %s changes on get, resolve and old command replay', async reason => {
  const f = await deliveryFixture(); await createRecommendationDelivery(f.deps)(f.request);
  let deps = f.deps;
  const read = {...f.memberRequest, data: {...f.memberRequest.data, action: 'read', commandId: 'read-once', expectedRevision: 1}};
  await createMemberRecommendationService(deps)(read);
  if (reason === 'consent') f.store.documents.delete(`orgs/${f.org}/recommendationConsent/member`);
  if (reason === 'target') deps = {...deps, resolveTarget: async () => null};
  if (reason === 'expired') deps = {...deps, clock: () => 400000};
  const before = JSON.stringify([...f.store.documents]);
  for (const request of [f.memberRequest, {...f.memberRequest, data: {...f.memberRequest.data, action: 'resolve'}}, read]) {
    expect(await createMemberRecommendationService(deps)(request)).toMatchObject({state: reason === 'expired' ? 'expired' : 'unavailable',
      target: null, exerciseLabel: null, objective: null, targetLabel: null, specialization: null, imageUrl: null, photoPath: null, explanations: []});
  }
  expect(JSON.stringify([...f.store.documents])).toBe(before);
});
it('lets the owner dismiss a revoked delivered notice without implying a read or acceptance', async () => {
  const f = await deliveryFixture(); await createRecommendationDelivery(f.deps)(f.request);
  f.store.documents.delete(`orgs/${f.org}/recommendationConsent/member`);
  const result = await createMemberRecommendationService(f.deps)({...f.memberRequest, data: {...f.memberRequest.data, action: 'dismiss', commandId: 'dismiss-revoked', expectedRevision: 1}});
  expect(result).toMatchObject({state: 'dismissed', target: null, readAtMillis: null, acknowledgedAtMillis: null, dismissedAtMillis: 200000});
  expect([...f.store.documents].find(([p]) => p.includes('/notifications/'))![1].read).toBe(false);
});
it('blocks new acknowledgment and read after revocation without persisting command receipts', async () => {
  const f = await deliveryFixture(); await createRecommendationDelivery(f.deps)(f.request);
  f.store.documents.delete(`orgs/${f.org}/recommendationConsent/member`);
  const before = JSON.stringify([...f.store.documents]);
  for (const action of ['read', 'acknowledge']) await expect(createMemberRecommendationService(f.deps)({...f.memberRequest,
    data: {...f.memberRequest.data, action, commandId: action, expectedRevision: 1}})).rejects.toMatchObject({code: 'failed-precondition'});
  expect(JSON.stringify([...f.store.documents])).toBe(before);
});
it.each(['wrong_member', 'inactive', 'wrong_org', 'app', 'fresh_auth', 'lifecycle'] as const)('denies %s access before details and actions', async reason => {
  const f = await deliveryFixture(); await createRecommendationDelivery(f.deps)(f.request);
  let request = f.memberRequest, deps = f.deps;
  if (reason === 'wrong_member') request = {...request, auth: {uid: 'admin', token: {...request.auth.token, email: 'admin@example.invalid'}}};
  if (reason === 'inactive') f.store.documents.get(`orgs/${f.org}/members/member`)!.status = 'inactive';
  if (reason === 'wrong_org') f.store.documents.get('users/member')!.organizationId = 'other';
  if (reason === 'app') request = {...request, app: undefined as never};
  if (reason === 'fresh_auth') deps = {...deps, readAuthIdentity: async uid => ({...await f.deps.readAuthIdentity(uid), disabled: true})};
  if (reason === 'lifecycle') f.store.documents.get('users/member')!.accountLifecycle = {schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: 101};
  const before = JSON.stringify([...f.store.documents]);
  await expect(createMemberRecommendationService(deps)(request)).rejects.toMatchObject({code: expect.stringMatching(/permission-denied|unauthenticated/)});
  expect(JSON.stringify([...f.store.documents])).toBe(before);
});
it('enforces CAS for distinct commands and binds reused commands to the exact request', async () => {
  const f = await deliveryFixture(); await createRecommendationDelivery(f.deps)(f.request);
  const run = createMemberRecommendationService(f.deps);
  const command = {...f.memberRequest, data: {...f.memberRequest.data, action: 'acknowledge', commandId: 'one-command', expectedRevision: 1}};
  const results = await Promise.allSettled([run(command), run({...command, data: {...command.data, action: 'dismiss', commandId: 'competitor'}})]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  const before = JSON.stringify([...f.store.documents]);
  await expect(run({...command, data: {...command.data, action: 'dismiss'}})).rejects.toMatchObject({code: 'aborted'});
  expect(JSON.stringify([...f.store.documents])).toBe(before);
});
it('sanitizes source failure on detail and action and commits no writes', async () => {
  const f = await deliveryFixture(); await createRecommendationDelivery(f.deps)(f.request);
  const run = createMemberRecommendationService({...f.deps, resolveTarget: async () => {throw Error('private raw source');}}), before = JSON.stringify([...f.store.documents]);
  for (const request of [f.memberRequest, {...f.memberRequest, data: {...f.memberRequest.data, action: 'read', commandId: 'read', expectedRevision: 1}}]) {
    await expect(run(request)).rejects.toMatchObject({code: 'unavailable', message: expect.not.stringContaining('private')});
  }
  expect(JSON.stringify([...f.store.documents])).toBe(before);
});
it('checks inference purpose only when provenance required it', async () => {
  for (const ai of [false, true]) {
    const f = await deliveryFixture(ai); await createRecommendationDelivery(f.deps)(f.request);
    if (ai) {
      const c = f.store.documents.get(`orgs/${f.org}/recommendationConsent/member`)!;
      const purposes = c.purposes as Record<string, Record<string, unknown>>;
      purposes.externalAiInference = {...purposes.externalAiInference, granted: false, revision: 2, revokedAtMillis: 200000};
      c.revision = 5;
    }
    expect(await createMemberRecommendationService(f.deps)(f.memberRequest)).toMatchObject({state: ai ? 'unavailable' : 'available'});
  }
});
it('allows identical concurrent Member commands once and treats a repeated read as an idempotent no-op', async () => {
  const f = await deliveryFixture(); await createRecommendationDelivery(f.deps)(f.request);
  const run = createMemberRecommendationService(f.deps), read = {...f.memberRequest,
    data: {...f.memberRequest.data, action: 'read', commandId: 'concurrent-read', expectedRevision: 1}};
  const results = await Promise.all([run(read), run(read)]);
  expect(results[0]).toEqual(results[1]);
  expect(results[0]).toMatchObject({revision: 2, readAtMillis: 200000, acknowledgedAtMillis: null});
  expect(await run({...read, data: {...read.data, commandId: 'read-again', expectedRevision: 2}})).toEqual(results[0]);
  expect(f.store.documents.get(f.recipientPath)!.revision).toBe(2);
});
it('never requires external inference permission for a deterministic recommendation after an unrelated AI grant is revoked', async () => {
  const f = await deliveryFixture(true);
  const leadPath = `orgs/${f.org}/recommendationLeads/${f.lead.leadId}`;
  const lead = f.store.documents.get(leadPath)!;
  lead.ranking = {...lead.ranking as object, origin: 'deterministic_single_candidate', model: null};
  await createRecommendationDelivery(f.deps)(f.request);
  const c = f.store.documents.get(`orgs/${f.org}/recommendationConsent/member`)!;
  const purposes = c.purposes as Record<string, Record<string, unknown>>;
  purposes.externalAiInference = {...purposes.externalAiInference, granted: false, revision: 2, revokedAtMillis: 200000}; c.revision = 5;
  expect(await createMemberRecommendationService(f.deps)(f.memberRequest)).toMatchObject({state: 'available'});
});
it('redacts an explicitly withdrawn recommendation, retaining only minimal delivery and interaction state', async () => {
  const f = await deliveryFixture(); await createRecommendationDelivery(f.deps)(f.request);
  const r = f.store.documents.get(f.recipientPath)!;
  r.status = 'withdrawn'; r.withdrawnAtMillis = 200000; r.revision = 2;
  expect(await createMemberRecommendationService(f.deps)(f.memberRequest)).toMatchObject({state: 'withdrawn', target: null, exerciseLabel: null, explanations: [], revision: 2});
});
it.each([
  {action: 'get', commandId: 'unexpected', expectedRevision: null},
  {action: 'read', commandId: null, expectedRevision: 1},
  {action: 'read', commandId: 'command', expectedRevision: '1'},
  {action: ['get'], commandId: null, expectedRevision: null},
  {action: 'get', commandId: null, expectedRevision: null, memberId: 'other'},
])('rejects malformed Member command metadata %# with no writes', async data => {
  const f = await deliveryFixture(), before = JSON.stringify([...f.store.documents]);
  await expect(createMemberRecommendationService(f.deps)({...f.memberRequest, data: {...f.memberRequest.data, ...data}})).rejects.toMatchObject({code: 'invalid-argument'});
  expect(JSON.stringify([...f.store.documents])).toBe(before);
});
