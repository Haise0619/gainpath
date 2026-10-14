import { beforeEach, expect, it, vi } from 'vitest';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { MemoryStore } from './memory-store';
import { command, now, start, seeds, eligibleCoach } from './booking-fixture';
import type { DocumentStore } from '../src/platform/firestore/store';
import { keyOf } from '../src/platform/idempotency';

let store: MemoryStore;
let clock: number;
const execute = (input = command, uid = 'member-1') => createBookingHoldService(store, uid, input, eligibleCoach, () => clock);
beforeEach(() => { store = new MemoryStore(); clock = now; Object.entries(seeds).forEach(([p, d]) => store.documents.set(p, structuredClone(d))); });

it('holds every occupied slot and returns the same receipt on retry', async () => {
  const first = await execute();
  expect(first.status).toBe('pending_hold');
  expect(first.holdExpiresAtMillis).toBe(now + 900000);
  expect(await execute()).toEqual(first);
  expect([...store.documents.keys()].filter(p => p.includes('/slotLocks/'))).toHaveLength(2);
  expect([...store.documents.keys()].filter(p => p.includes('/bookings/'))).toHaveLength(1);
});
it('rejects reuse of a command key with a different payload', async () => {
  await execute();
  await expect(execute({ ...command, startAtMillis: start + 3600000 })).rejects.toMatchObject({ code: 'already-exists' });
});
it('replaces expired lock documents and releases expired daily accounting without TTL cleanup', async () => {
  const first = await execute();
  clock = first.holdExpiresAtMillis;
  const second = await execute({ ...command, requestId: 'request-2' });
  expect(second.bookingId).not.toBe(first.bookingId);
  const locks = [...store.documents.entries()].filter(([p]) => p.includes('/slotLocks/')).map(([, d]) => d);
  expect(locks.every(d => d.bookingId === second.bookingId)).toBe(true);
});
it('does not renew an expired receipt on transport retry', async () => {
  const first = await execute(); clock = first.holdExpiresAtMillis + 1;
  expect(await execute()).toEqual(first);
});
it('atomically enforces the per-member organization-local daily cap for nonoverlapping holds', async () => {
  const results = await Promise.allSettled([execute(), execute({ ...command, requestId: 'request-2', startAtMillis: start + 3600000 })]);
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect([...store.documents.keys()].filter(p => p.includes('/bookings/'))).toHaveLength(1);
});
it('prevents overlap even when the start slot differs', async () => {
  store.documents.set('orgs/org-1/settings/booking', { ...seeds['orgs/org-1/settings/booking'], maxActiveBookingsPerMemberPerDay: 4 });
  await execute();
  await expect(execute({ ...command, requestId: 'r2', startAtMillis: start + 1800000 })).rejects.toMatchObject({ code: 'aborted' });
});
it('never reclaims confirmed locks even after their expiry timestamp', async () => {
  await execute();
  for (const [p, d] of store.documents) if (p.includes('/slotLocks/')) store.documents.set(p, { ...d, status: 'confirmed' });
  clock += 900000;
  await expect(execute({ ...command, requestId: 'r2' })).rejects.toMatchObject({ code: 'aborted' });
});
it.each([
  ['orgs/org-1/coaches/coach-1', { status: 'published', branchIds: ['branch-2'] }],
  ['orgs/org-1/members/coach-1', { role: 'coach', status: 'suspended', branchIds: ['branch-1'] }],
  ['orgs/org-1/coachAvailability/coach-1/days/2026-10-02', { schemaVersion: 1, windows: [] }],
  ['orgs/org-1/settings/booking', {}],
] as const)('fails closed on unavailable coach or missing policy: %s', async (path, data) => {
  store.documents.set(path, data);
  await expect(execute()).rejects.toThrow();
  expect([...store.documents.keys()].filter(p => p.includes('/bookings/'))).toHaveLength(0);
});
it('denies staff outside their branch and members booking for another member', async () => {
  await expect(execute(command, 'staff-1')).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(execute({ ...command, memberId: 'someone-else' })).rejects.toMatchObject({ code: 'permission-denied' });
});
it('rechecks current membership before returning a prior receipt', async () => {
  await execute(); store.documents.set('orgs/org-1/members/member-1', { role: 'member', status: 'suspended', branchIds: ['branch-1'] });
  await expect(execute()).rejects.toMatchObject({ code: 'permission-denied' });
});
it('rejects current user organization drift even before receipt replay', async () => {
  await execute(); store.documents.set('users/member-1', { organizationId: 'elsewhere' });
  await expect(execute()).rejects.toMatchObject({ code: 'permission-denied' });
});
it('rejects a legacy schedule for a new hold', async () => {
  const path = 'orgs/org-1/coachAvailability/coach-1/days/2026-10-02';
  store.documents.set(path, { schemaVersion: 1, windows: seeds[path].windows });
  await expect(execute()).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('rejects forged receipt result identity', async () => {
  await execute();
  for (const [path, data] of store.documents) if (path.includes('/commandReceipts/')) {
    store.documents.set(path, { ...data, result: { ...(data.result as object), requestId: 'wrong' } });
  }
  await expect(execute()).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('replays after Coach withdrawal, organization drift, Auth failure, policy deletion and elapsed expiry without an Auth call', async () => {
  const first = await execute();
  store.documents.get('users/coach-1')!.organizationId = 'elsewhere';
  store.documents.get('orgs/org-1/coaches/coach-1')!.status = 'inactive';
  store.documents.delete('orgs/org-1/settings/booking');
  const reader = vi.fn(async () => { throw Error('Auth unavailable'); });
  expect(await createBookingHoldService(store, 'member-1', command, reader, () => first.holdExpiresAtMillis + 1)).toEqual(first);
  expect(reader).not.toHaveBeenCalled();
});
it('returns a concurrent receipt before applying a captured Auth error', async () => {
  let first: unknown;
  const reader = vi.fn(async () => {
    first = await execute();
    throw Error('Auth unavailable after another attempt committed');
  });
  expect(await createBookingHoldService(store, 'member-1', command, reader, () => now)).toEqual(first);
  expect(reader).toHaveBeenCalledTimes(1);
  expect([...store.documents.keys()].filter(p => p.includes('/bookings/'))).toHaveLength(1);
});
it('captures eligibility outside retries, preserves allocated ID, and rechecks server time', async () => {
  const ids: string[] = []; let transactions = 0, attempts = 0, ticking = now;
  const retry: DocumentStore = { transact: async work => {
    transactions++;
    if (transactions === 1) return store.transact(work);
    await work({ get: async p => structuredClone(store.documents.get(p)), create: (p) => { if (p.includes('/bookings/')) ids.push(p); }, set: () => {} });
    ticking += 1000; attempts++;
    return store.transact(tx => work({ ...tx, create: (p, data) => { if (p.includes('/bookings/')) ids.push(p); tx.create(p, data); } }));
  } };
  const reader = vi.fn(eligibleCoach);
  const result = await createBookingHoldService(retry, 'member-1', command, reader, () => ticking);
  expect(attempts).toBe(1); expect(ids).toHaveLength(2); expect(ids[0]).toBe(ids[1]);
  expect(reader).toHaveBeenCalledTimes(1); expect(result.holdExpiresAtMillis).toBe(now + 901000);
});
it.each([
  ['users/member-1', { organizationId: 'elsewhere' }],
  ['orgs/org-1/members/member-1', { organizationId: 'elsewhere', role: 'member', status: 'active', branchIds: ['branch-1'] }],
  ['users/coach-1', { organizationId: 'elsewhere' }],
  ['orgs/org-1', { status: 'inactive' }],
  ['orgs/org-1/members/coach-1', { organizationId: 'org-1', role: 'coach', status: 'active', branchIds: ['branch-1', 'branch-1'] }],
] as const)('denies current scope drift without any writes: %s', async (path, value) => {
  store.documents.set(path, value); const before = structuredClone([...store.documents]);
  await expect(execute()).rejects.toThrow(); expect([...store.documents]).toEqual(before);
});
it.each([{ exists: true, disabled: true, emailVerified: true }, { exists: true, disabled: false, emailVerified: false }, { exists: false, disabled: false, emailVerified: false }])('rejects ineligible Coach Auth without writes: %j', async identity => {
  const before = structuredClone([...store.documents]);
  await expect(createBookingHoldService(store, 'member-1', command, async () => identity, () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
  expect([...store.documents]).toEqual(before);
});
it('denies a genuinely new hold on Auth lookup error and performs no lookup for an unauthorized actor', async () => {
  const reader = vi.fn(async () => { throw Error('not available'); });
  await expect(createBookingHoldService(store, 'staff-1', command, reader, () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  expect(reader).not.toHaveBeenCalled();
  await expect(createBookingHoldService(store, 'member-1', command, reader, () => now)).rejects.toMatchObject({ code: 'unavailable' });
  expect([...store.documents.keys()].some(p => p.includes('/bookings/'))).toBe(false);
});
it('preserves Admin and in-branch staff delegated create while rechecking recipient current scope', async () => {
  for (const [uid, role, branches] of [['admin', 'admin', []], ['staff', 'staff', ['branch-1']]] as const) {
    store.documents.set(`users/${uid}`, { organizationId: 'org-1' });
    store.documents.set(`orgs/org-1/members/${uid}`, { organizationId: 'org-1', role, status: 'active', branchIds: branches });
  }
  const first = await execute(command, 'admin');
  clock = first.holdExpiresAtMillis;
  await execute({ ...command, requestId: 'staff-request' }, 'staff');
  store.documents.get('users/member-1')!.organizationId = 'elsewhere';
  await expect(execute(command, 'admin')).rejects.toMatchObject({ code: 'permission-denied' });
});
it.each([{ schemaVersion: 2 }, { coachId: 'wrong' }, { bookingId: '' }, { expiresAtMillis: 0 }, { expiresAtMillis: start + 1 }, { status: 'unknown' }])('rejects malformed expired locks instead of reclaiming them: %j', async change => {
  store.documents.set(`orgs/org-1/slotLocks/${keyOf('coach-1', start)}`, { schemaVersion: 1, coachId: 'coach-1', branchId: 'branch-1', bookingId: 'other', status: 'pending_hold', expiresAtMillis: now, ...change });
  const before = structuredClone([...store.documents]);
  await expect(execute()).rejects.toMatchObject({ code: 'failed-precondition' }); expect([...store.documents]).toEqual(before);
});
it('rechecks actor scope after Auth lookup and rejects stale intent outside the horizon', async () => {
  const reader = async () => { store.documents.get('users/member-1')!.organizationId = 'elsewhere'; return eligibleCoach('coach-1'); };
  await expect(createBookingHoldService(store, 'member-1', command, reader, () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.get('users/member-1')!.organizationId = 'org-1';
  await expect(execute({ ...command, startAtMillis: Date.parse('2026-11-01T02:00:00Z') })).rejects.toMatchObject({ code: 'invalid-argument' });
});
