import {expect, it} from 'vitest';
import {createRecommendationDelivery} from '../src/modules/recommendation/recommendation-delivery';
import {deliveryFixture} from './recommendation-delivery.fixture';

it('atomically delivers one existing-inbox notification, receipt and recipient revision, including concurrent lost-response retries', async () => {
  const f = await deliveryFixture();
  const run = createRecommendationDelivery(f.deps);
  const results = await Promise.all([run(f.request), run(f.request)]);
  expect(results[0]).toEqual(results[1]);
  expect(results[0]).toMatchObject({status: 'delivered', recommendationId: f.recommendationId, revision: 1, deliveredAtMillis: 200000});
  const snapshot = JSON.stringify([...f.store.documents]);
  expect(await run(f.request)).toEqual(results[0]);
  expect(JSON.stringify([...f.store.documents])).toBe(snapshot);
  expect([...f.store.documents.keys()].filter(p => p.includes('/notifications/'))).toHaveLength(1);
  expect([...f.store.documents.keys()].filter(p => p.includes('/recommendationDeliveryReceipts/'))).toHaveLength(1);
  expect(f.store.documents.get(f.recipientPath)).toMatchObject({status: 'delivered', revision: 1, memberReadAtMillis: null, acknowledgedAtMillis: null, dismissedAtMillis: null});
});
it.each(['consent', 'inactive', 'expired', 'target', 'auth'] as const)('blocks %s before delivery without any write', async reason => {
  const f = await deliveryFixture();
  if (reason === 'consent') f.store.documents.delete(`orgs/${f.org}/recommendationConsent/member`);
  if (reason === 'inactive') f.store.documents.get(`orgs/${f.org}/members/member`)!.status = 'inactive';
  const deps = {...f.deps, ...(reason === 'expired' ? {clock: () => 400000} : {}),
    ...(reason === 'target' ? {resolveTarget: async () => null} : {}),
    ...(reason === 'auth' ? {readAuthIdentity: async (uid: string) => ({...await f.deps.readAuthIdentity(uid), disabled: uid === 'member'})} : {})};
  const snapshot = JSON.stringify([...f.store.documents]);
  await expect(createRecommendationDelivery(deps)(f.request)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(JSON.stringify([...f.store.documents])).toBe(snapshot);
});
it('revalidates consent even for an existing successful delivery receipt', async () => {
  const f = await deliveryFixture(), run = createRecommendationDelivery(f.deps); await run(f.request);
  f.store.documents.delete(`orgs/${f.org}/recommendationConsent/member`);
  const snapshot = JSON.stringify([...f.store.documents]);
  await expect(run(f.request)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(JSON.stringify([...f.store.documents])).toBe(snapshot);
});
it.each(['resolver', 'auth'] as const)('does not commit partial success when %s throws private source details', async source => {
  const f = await deliveryFixture(), snapshot = JSON.stringify([...f.store.documents]);
  const deps = {...f.deps, ...(source === 'resolver' ? {resolveTarget: async () => {throw Error('private source');}} :
    {readAuthIdentity: async (uid: string) => {if (uid === 'member') throw Error('private identity'); return f.deps.readAuthIdentity(uid);}})};
  await expect(createRecommendationDelivery(deps)(f.request)).rejects.toMatchObject({code: 'unavailable', message: expect.not.stringContaining('private')});
  expect(JSON.stringify([...f.store.documents])).toBe(snapshot);
});
it('requires explicit D/C fixture composition and strict request shape', async () => {
  const f = await deliveryFixture();
  await expect(createRecommendationDelivery({...f.deps, localDelivery: undefined})(f.request)).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(createRecommendationDelivery({...f.deps, localFixture: undefined})(f.request)).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(createRecommendationDelivery(f.deps)({...f.request, data: {...f.request.data, memberId: 'member'}})).rejects.toMatchObject({code: 'invalid-argument'});
});
it.each(['target', 'memberId', 'draft', 'decision'] as const)('rejects tampered prepared %s bindings', async field => {
  const f = await deliveryFixture(), r = f.store.documents.get(f.recipientPath)!;
  if (field === 'target') (r.target as {coachId: string}).coachId = 'invented';
  if (field === 'memberId') r.memberId = 'other';
  if (field === 'draft') (r.notificationDraft as {title: string}).title = 'Arbitrary title';
  if (field === 'decision') (f.store.documents.get(`orgs/${f.org}/recommendationLeads/${f.lead.leadId}`)!.decision as {recipientRecommendationId: string}).recipientRecommendationId = 'other';
  const snapshot = JSON.stringify([...f.store.documents]);
  await expect(createRecommendationDelivery(f.deps)(f.request)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(JSON.stringify([...f.store.documents])).toBe(snapshot);
});
it('rechecks Admin authority after the external Member identity read and commits nothing on authority drift', async () => {
  const f = await deliveryFixture();
  const run = createRecommendationDelivery({...f.deps, readAuthIdentity: async uid => {
    if (uid === 'member') f.store.documents.get(`orgs/${f.org}/members/admin`)!.status = 'inactive';
    return f.deps.readAuthIdentity(uid);
  }});
  await expect(run(f.request)).rejects.toMatchObject({code: 'permission-denied'});
  expect([...f.store.documents.keys()].some(p => p.includes('/notifications/') || p.includes('/recommendationDeliveryReceipts/'))).toBe(false);
});
it.each(['receipt', 'notification', 'read_state'] as const)('refuses a corrupted durable %s rather than claiming delivery success', async corrupted => {
  const f = await deliveryFixture(), run = createRecommendationDelivery(f.deps); await run(f.request);
  if (corrupted === 'receipt') {
    const receipt = [...f.store.documents].find(([p]) => p.includes('/recommendationDeliveryReceipts/'))![1];
    (receipt.result as {recommendationId: string}).recommendationId = 'different';
  }
  if (corrupted === 'notification') f.store.documents.delete([...f.store.documents.keys()].find(p => p.includes('/notifications/'))!);
  if (corrupted === 'read_state') [...f.store.documents].find(([p]) => p.includes('/notifications/'))![1].read = true;
  const before = JSON.stringify([...f.store.documents]);
  await expect(run(f.request)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(JSON.stringify([...f.store.documents])).toBe(before);
});
it('discards all transaction writes when commit fails and retries without a phantom success', async () => {
  const f = await deliveryFixture(); let failCommit = true;
  const store = {transact: <T>(work: Parameters<typeof f.store.transact<T>>[0]) => f.store.transact(async tx => {
    const result = await work(tx);
    if (failCommit && [...f.store.documents.keys()].every(p => !p.includes('/notifications/'))) {
      // Fail only a transaction that attempted notification creation.
      if ((result as {status?: string})?.status === 'delivered') {failCommit = false; throw Error('synthetic commit failure');}
    }
    return result;
  })};
  const run = createRecommendationDelivery({...f.deps, store}), before = JSON.stringify([...f.store.documents]);
  await expect(run(f.request)).rejects.toMatchObject({code: 'unavailable'});
  expect(JSON.stringify([...f.store.documents])).toBe(before);
  expect(await run(f.request)).toMatchObject({status: 'delivered'});
  expect([...f.store.documents.keys()].filter(p => p.includes('/notifications/'))).toHaveLength(1);
});
it('accepts a current published tutorial label up to the existing 200-character limit', async () => {
  const f = await deliveryFixture(false, 'content');
  const resolve = f.deps.resolveTarget;
  expect(await createRecommendationDelivery({...f.deps, resolveTarget: async (tx, lead) => {
    const current = await resolve(tx, lead); if (!current) throw Error('Fixture target missing');
    return {...current, label: 'A'.repeat(200)};
  }})(f.request))
    .toMatchObject({status: 'delivered'});
});
