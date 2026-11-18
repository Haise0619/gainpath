import { expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { now, seeds } from './booking-fixture';
import { branchOperations, type OperationsReader } from '../src/modules/identity/branch-operations';

const org = 'org-1';
const root = `orgs/${org}`;
const branchId = 'north';
const branch = `${root}/branches/${branchId}`;
const auth = (uid: string) => ({ uid, token: { email_verified: true, auth_time: Math.floor(now / 1000) } });

function fixture() {
  const store = new MemoryStore();
  for (const [path, data] of Object.entries(seeds)) store.documents.set(path, { ...data });
  store.documents.set('users/branch-admin', { organizationId: org });
  store.documents.set(`${root}/members/branch-admin`, { organizationId: org, role: 'admin', status: 'active', branchIds: [] });
  store.documents.set(branch, { displayName: 'North', status: 'active' });
  store.documents.set(`${root}/gymEquipment/press`, { isActive: true, name: 'Leg Press' });
  const read: OperationsReader = async path => Array.from(store.documents.entries())
    .filter(([key]) => key.startsWith(path + '/') && !key.slice(path.length + 1).includes('/'))
    .map(([key, data]) => ({ id: key.slice(path.length + 1), data }));
  const run = (uid: string, action: string, extra = {}, at = now) =>
    branchOperations(store, read, auth(uid), { organizationId: org, action, branchId, ...extra }, () => at);
  return { store, run };
}

it('tracks inventory without editing the organization catalog', async () => {
  const { store, run } = fixture();
  const input = { equipmentId: 'press', quantity: 4, maintenance: 1 };
  await expect(run('member-1', 'saveInventory', input)).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(run('branch-admin', 'saveInventory', { ...input, maintenance: 5 })).rejects.toMatchObject({ code: 'invalid-argument' });
  await run('branch-admin', 'saveInventory', input);
  expect(await run('member-1', 'inventory')).toMatchObject({ records: [{ name: 'Leg Press', quantity: 4, usable: 3, maintenance: 1 }] });
  const user = store.documents.get('users/member-1')!;
  store.documents.set('users/member-1', { ...user, selectedBranchId: branchId });
  expect(await run('member-1', 'equipmentAvailability', { equipmentId: 'press' }))
    .toMatchObject({ branchId, usable: 3, maintenance: 1, recorded: true });
  await run('branch-admin', 'removeInventory', input);
  expect(await run('member-1', 'inventory')).toEqual({ records: [] });
  expect(store.documents.get(`${root}/gymEquipment/press`)?.isActive).toBe(true);
});

it('binds signed-in visits to an active branch and deduplicates retries and refreshed QR scans', async () => {
  const { store, run } = fixture();
  const first = await run('branch-admin', 'issueVisitCode') as { qr: string };
  const token = first.qr.split(':')[2];
  await expect(run('member-1', 'checkIn', { token }, now + 300000))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  expect(await run('member-1', 'checkIn', { token })).toMatchObject({ duplicate: false });
  expect(await run('member-1', 'checkIn', { token })).toMatchObject({ duplicate: true });
  const fresh = await run('branch-admin', 'issueVisitCode', {}, now + 2000) as { qr: string };
  expect(await run('member-1', 'checkIn', { token: fresh.qr.split(':')[2] }, now + 3000)).toMatchObject({ duplicate: true });
  expect(await run('member-1', 'myVisits')).toMatchObject({ records: [{ branchName: 'North', branchId }] });
  expect(await run('branch-admin', 'branchVisits')).toMatchObject({ records: [{ memberId: 'member-1', branchId }] });
  expect([...store.documents.keys()].filter(key => key.startsWith(branch + '/gymVisits/'))).toHaveLength(1);
  await expect(run('member-1', 'branchVisits')).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.set(branch, { status: 'inactive' });
  await expect(run('member-1', 'checkIn', { token })).rejects.toMatchObject({ code: 'permission-denied' });
});
