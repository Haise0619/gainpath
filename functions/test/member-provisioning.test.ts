import { beforeEach, expect, it } from 'vitest';
import { provisionMember } from '../src/modules/identity/member-provisioning';
import { MemoryStore } from './memory-store';

const now = Date.parse('2026-09-20T00:00:00Z');
let store: MemoryStore;

beforeEach(() => {
  store = new MemoryStore();
});

it('creates the fixed organization, branch, user, and member scope', async () => {
  const result = await provisionMember(store, {
    userId: 'user-1',
    email: 'member@example.com',
    displayName: 'New Member',
  }, () => now);

  expect(result).toEqual({
    schemaVersion: 1,
    organizationId: 'gainpath',
    branchIds: ['main'],
    role: 'member',
    status: 'active',
  });
  expect(store.documents.get('orgs/gainpath')).toMatchObject({
    organizationId: 'gainpath',
    displayName: 'GainPath',
  });
  expect(store.documents.get('orgs/gainpath/branches/main')).toMatchObject({
    branchId: 'main',
    displayName: 'Main Branch',
  });
  expect(store.documents.get('users/user-1')).toMatchObject({
    organizationId: 'gainpath',
    primaryBranchId: 'main',
  });
  expect(store.documents.get('orgs/gainpath/members/user-1')).toMatchObject({
    role: 'member',
    status: 'active',
    branchIds: ['main'],
    email: 'member@example.com',
    displayName: 'New Member',
  });
});

it('is idempotent and preserves editable display names', async () => {
  await provisionMember(store, {
    userId: 'user-1', email: 'member@example.com', displayName: 'New Member',
  }, () => now);
  store.documents.set('orgs/gainpath', {
    ...store.documents.get('orgs/gainpath'), displayName: 'GainPath Fitness',
  });
  store.documents.set('orgs/gainpath/branches/main', {
    ...store.documents.get('orgs/gainpath/branches/main'), displayName: 'KL Main',
  });

  await provisionMember(store, {
    userId: 'user-1', email: 'member@example.com', displayName: 'Ignored Retry',
  }, () => now + 1000);

  expect(store.documents.get('orgs/gainpath')).toMatchObject({ displayName: 'GainPath Fitness' });
  expect(store.documents.get('orgs/gainpath/branches/main')).toMatchObject({ displayName: 'KL Main' });
  expect(store.documents.get('orgs/gainpath/members/user-1')).toMatchObject({ displayName: 'New Member' });
});

it.each([
  ['users/user-1', { organizationId: 'other-org' }],
  ['orgs/gainpath/members/user-1', { role: 'coach', status: 'active', branchIds: ['main'] }],
  ['orgs/gainpath/members/user-1', { role: 'member', status: 'active', branchIds: ['other'] }],
] as const)('rejects conflicting authority at %s', async (path, document) => {
  store.documents.set(path, document);

  await expect(provisionMember(store, {
    userId: 'user-1', email: 'member@example.com', displayName: 'New Member',
  }, () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
});

it('rejects invalid server identity data before writing', async () => {
  await expect(provisionMember(store, {
    userId: '../user', email: 'not-an-email', displayName: '',
  }, () => now)).rejects.toThrow();
  expect(store.documents.size).toBe(0);
});
