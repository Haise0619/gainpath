import { beforeEach, expect, it } from 'vitest';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { MemoryStore } from './memory-store';
import { command, now, start, seeds } from './booking-fixture';

let store: MemoryStore;
let clock: number;
const execute = (input = command, uid = 'member-1') => createBookingHoldService(store, uid, input, () => clock);
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
