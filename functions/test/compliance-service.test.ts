import { expect, it } from 'vitest';
import { manageCompliance } from '../src/modules/compliance/compliance-service';
import { MemoryStore } from './memory-store';

function setup() {
  const store = new MemoryStore();
  store.documents.set('orgs/gym', { status: 'active' });
  for (const [uid, role] of [['admin', 'admin'], ['member', 'member'], ['new-member', 'member']]) {
    store.documents.set('users/' + uid, { organizationId: 'gym' });
    store.documents.set('orgs/gym/members/' + uid, {
      organizationId: 'gym', branchIds: [], status: 'active', role,
    });
  }
  const call = (uid: string, action: string, input = {}) =>
    manageCompliance(store, { uid, token: { email_verified: true } },
      { schemaVersion: 1, organizationId: 'gym', action, ...input }, () => 123456);
  const save = (text: string, baseRevision: number) =>
    call('admin', 'saveDraft', { kind: 'privacy', text, baseRevision, isArchived: false });
  const publish = (baseRevision: number, requireConsent: boolean) =>
    call('admin', 'publish', { kind: 'privacy', baseRevision, requireConsent });
  const accept = (revision: number) =>
    call('member', 'accept', { agreed: true, documents: [{ kind: 'privacy', revision }] });
  return { store, call, save, publish, accept };
}

it('keeps draft edits private and separates routine updates from re-consent', async () => {
  const { store, call, save, publish, accept } = setup();
  await save('First fixture', 0);
  expect(await call('member', 'memberOverview')).toEqual({ documents: [] });
  expect(await publish(1, false)).toEqual({ version: 'v1.0' });
  expect(await call('member', 'memberOverview')).toMatchObject({
    documents: [{ version: 'v1.0', requiresConsent: true }],
  });
  await Promise.all([accept(1), accept(1)]);
  await save('Routine fixture', 1);
  expect(await call('member', 'memberOverview')).toMatchObject({
    documents: [{ version: 'v1.0', requiresConsent: false }],
  });
  expect(await publish(2, false)).toEqual({ version: 'v1.1' });
  expect(await call('member', 'memberOverview')).toMatchObject({
    documents: [{ version: 'v1.1', acceptedVersion: 'v1.0', requiresConsent: false }],
  });
  expect(await call('new-member', 'memberOverview')).toMatchObject({
    documents: [{ version: 'v1.1', requiresConsent: true }],
  });
  await save('Major fixture', 2);
  expect(await publish(3, true)).toEqual({ version: 'v2.0' });
  await expect(accept(2)).rejects.toMatchObject({ code: 'aborted' });
  expect(await call('member', 'memberOverview')).toMatchObject({
    documents: [{ version: 'v2.0', acceptedVersion: 'v1.0', requiresConsent: true }],
  });
  await accept(3);
  const path = 'orgs/gym/members/member/legalConsents/privacy';
  expect(store.documents.get(path + '/versions/1')).toMatchObject({
    uid: 'member', version: 'v1.0', acceptedAtMillis: 123456,
  });
  expect(store.documents.get(path + '/versions/3')).toMatchObject({ version: 'v2.0' });
  expect(await call('admin', 'adminOverview', { kind: 'privacy' })).toMatchObject({
    history: [{ text: 'Major fixture' }, { text: 'Routine fixture' }, { text: 'First fixture' }],
  });
});

it('rejects unauthorized actions and records consent only for the authenticated member', async () => {
  const { store, call, save, publish } = setup();
  await save('Fixture', 0);
  await expect(call('member', 'publish', { kind: 'privacy', baseRevision: 1, requireConsent: true }))
    .rejects.toMatchObject({ code: 'permission-denied' });
  await publish(1, true);
  await expect(call('admin', 'accept', { agreed: true, documents: [{ kind: 'privacy', revision: 1 }] }))
    .rejects.toMatchObject({ code: 'permission-denied' });
  await call('member', 'accept', {
    uid: 'new-member', agreed: true, documents: [{ kind: 'privacy', revision: 1 }],
  });
  expect(store.documents.has('orgs/gym/members/new-member/legalConsents/privacy')).toBe(false);
  expect(store.documents.get('orgs/gym/members/member/legalConsents/privacy')?.uid).toBe('member');
});

it('cannot publish stale drafts or overwrite an existing release', async () => {
  const { store, save, publish } = setup();
  await save('First fixture', 0);
  await save('Second fixture', 1);
  await expect(publish(1, true)).rejects.toMatchObject({ code: 'aborted' });
  await publish(2, true);
  await expect(publish(2, true)).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(store.documents.get('orgs/gym/legalDocuments/privacy/versions/1')?.text).toBe('Second fixture');
});
