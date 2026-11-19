import { expect, it } from 'vitest';
import { branchManagement, type BranchList } from '../src/modules/identity/branch-management';
import { MemoryStore } from './memory-store';

const list: BranchList = async (_org, activeOnly) => [
  { id: 'main', data: { displayName: 'Main', status: 'active' } },
  ...(!activeOnly ? [{ id: 'old', data: { displayName: 'Old', status: 'inactive' } }] : []),
];
const actor = (uid: string) => ({ uid, token: { email_verified: true } });
const request = (action: string, data: object = {}) => ({ organizationId: 'gym', action, ...data });

function fixture() {
  const store = new MemoryStore();
  store.documents.set('orgs/gym', { status: 'active' });
  for (const role of ['member', 'admin']) {
    store.documents.set(`users/${role}`, { organizationId: 'gym', primaryBranchId: 'main' });
    store.documents.set(`orgs/gym/members/${role}`, { organizationId: 'gym', role, status: 'active', branchIds: ['main'] });
  }
  store.documents.set('orgs/gym/branches/main', { status: 'active', displayName: 'Main', legacyField: true });
  store.documents.set('orgs/gym/branches/other', { status: 'active', displayName: 'Other' });
  return store;
}

it('hides inactive branches from members and keeps home preference separate from booking access', async () => {
  const store = fixture();
  expect(await branchManagement(store, list, actor('member'), request('list'))).toMatchObject({
    records: [{ branchId: 'main' }], homeBranchId: 'main',
  });
  expect(await branchManagement(store, list, actor('member'), request('setHome', { branchId: 'other' }))).toEqual({ homeBranchId: 'other' });
  expect(store.documents.get('orgs/gym/members/member')?.branchIds).toEqual(['main']);
  expect(store.documents.get('users/member')?.primaryBranchId).toBe('main');
  expect(await branchManagement(store, list, actor('member'), request('setSelected', { branchId: 'main' }))).toEqual({ selectedBranchId: 'main' });
  expect(await branchManagement(store, list, actor('member'), request('list'))).toMatchObject({
    selectedBranchId: 'main', homeBranchId: 'other',
  });
  store.documents.set('orgs/gym/branches/main', { status: 'inactive' });
  expect(await branchManagement(store, list, actor('member'), request('list'))).not.toHaveProperty('selectedBranchId');
  await expect(branchManagement(store, list, actor('member'), request('save', {
    branchId: 'main', branch: { displayName: 'Changed', status: 'active' },
  }))).rejects.toMatchObject({ code: 'permission-denied' });
});

it('validates coordinates and preserves existing branch fields on an Admin edit', async () => {
  const store = fixture();
  const save = (branch: object) => branchManagement(store, list, actor('admin'), request('save', { branchId: 'main', branch }));
  await expect(save({ displayName: 'Main', status: 'active', latitude: 91, longitude: 101 }))
    .rejects.toMatchObject({ code: 'invalid-argument' });
  await expect(save({ displayName: 'Main', status: 'active', latitude: 3.12, longitude: 101.65,
    openingHours: Array(7).fill({ open: '20:00', close: '02:00' }),
  })).resolves.toMatchObject({ branch: { latitude: 3.12, timeZone: 'Asia/Kuala_Lumpur' } });
  expect(store.documents.get('orgs/gym/branches/main')?.legacyField).toBe(true);
});

it('returns the booking owner’s historical location even after a branch change', async () => {
  const store = fixture();
  store.documents.set('orgs/gym/branches/old', {
    status: 'inactive', displayName: 'Old', address: 'Recorded address',
  });
  store.documents.set('orgs/gym/bookings/owned', { memberId: 'member', branchId: 'old' });
  store.documents.set('orgs/gym/bookings/private', { memberId: 'someone-else', branchId: 'old' });
  const lookup = (bookingId: string) =>
    branchManagement(store, list, actor('member'), request('bookingLocation', { bookingId }));
  await expect(lookup('owned')).resolves.toEqual({
    branch: { branchId: 'old', displayName: 'Old', address: 'Recorded address' },
  });
  await expect(lookup('private')).rejects.toMatchObject({ code: 'permission-denied' });
});
