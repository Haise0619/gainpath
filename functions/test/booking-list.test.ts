import { beforeEach, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import Ajv from 'ajv';
import { MemoryStore } from './memory-store';
import { now, start, seeds } from './booking-fixture';
import { getBookingListService, type BookingQuery, type BookingQueryReader } from '../src/modules/coaching/booking-list-service';

let store: MemoryStore;
let queries: BookingQuery[];
const input = { schemaVersion: 1, organizationId: 'org-1' };
export const record = { schemaVersion: 1, bookingId: 'booking-1', organizationId: 'org-1', memberId: 'member-1', coachId: 'coach-1', branchId: 'branch-1', requestId: 'request-1', startAtMillis: start, endAtMillis: start + 3600000, durationMinutes: 60, status: 'pending_hold', holdExpiresAtMillis: now + 900000, localDate: '2026-10-02', timeZone: 'Asia/Kuala_Lumpur', policyVersion: 'booking-v1', createdAtMillis: now, createdBy: 'member-1' };
const reader: BookingQueryReader = { read: async q => {
  queries.push(q);
  return [...store.documents].filter(([p, d]) => p.startsWith(`orgs/${q.organizationId}/bookings/`) && d[q.ownerField] === q.ownerId && (!q.branchIds || q.branchIds.includes(String(d.branchId))) && Number(d.startAtMillis) >= q.firstStartAtMillis && Number(d.startAtMillis) < q.throughStartAtMillis)
    .map(([path, data]) => ({ path, data })).sort((a, b) => Number(a.data.startAtMillis) - Number(b.data.startAtMillis) || (a.path < b.path ? -1 : 1))
    .filter(r => !q.cursor || Number(r.data.startAtMillis) > q.cursor.startAtMillis || (r.data.startAtMillis === q.cursor.startAtMillis && r.data.bookingId as string > q.cursor.bookingId)).slice(0, q.limit);
} };
const read = (uid = 'member-1', changes = {}, queryReader = reader, time = now) => getBookingListService(store, { uid, token: { email_verified: true } }, { ...input, ...changes }, queryReader, () => time);
beforeEach(() => {
  store = new MemoryStore(); queries = [];
  Object.entries(seeds).forEach(([p, d]) => store.documents.set(p, structuredClone(d)));
  store.documents.set('users/admin-1', { organizationId: 'org-1' });
  store.documents.set('orgs/org-1/members/admin-1', { organizationId: 'org-1', role: 'admin', status: 'active', branchIds: [] });
  store.documents.set('orgs/org-1/bookings/booking-1', structuredClone(record));
});
it('keeps cancelled records compatible with old readers unless the new resolution is requested', async () => {
  Object.assign(store.documents.get('orgs/org-1/bookings/booking-1')!, {
    status: 'cancelled', resolution: 'member_confirmed_cancelled', resolvedAtMillis: now,
    cancelledBy: 'member-1', cancellationReason: 'Cannot attend',
  });
  const legacy = (await read('member-1', { includeCancellationDetails: true })).records[0];
  expect(legacy.status).toBe('cancelled');
  expect(legacy).not.toHaveProperty('resolution');
  expect(legacy).not.toHaveProperty('resolvedAtMillis');
  expect((await read('member-1', { includeMemberChangeDetails: true })).records[0])
    .toMatchObject({ resolution: 'member_confirmed_cancelled', cancelledBy: 'member-1' });
  await expect(read('member-1', { includeMemberChangeDetails: 'yes' })).rejects.toThrow();
});
it('reads recent participant history while keeping a bounded history horizon', async () => {
  const later = now + 20 * 86400000;
  expect((await read('coach-1', { firstLocalDate: '2026-10-01' }, reader, later)).records).toHaveLength(1);
  await expect(read('coach-1', { firstLocalDate: '2026-01-01' }, reader, later)).rejects.toThrow();
});
it('exposes only the related client display name, never their private contact fields', async () => {
  Object.assign(store.documents.get('orgs/org-1/members/member-1')!, { displayName: 'Fixture Client', email: 'private@example.invalid' });
  const result = await read('coach-1', { includeParticipantNames: true });
  expect(result.records[0]).toMatchObject({ memberDisplayName: 'Fixture Client' });
  expect(result.records[0]).not.toHaveProperty('email');
  expect((await read('coach-1')).records[0]).not.toHaveProperty('memberDisplayName');
});
it('exposes feeMinor from transaction record when cleared or created', async () => {
  store.documents.set('orgs/org-1/transactions/booking-1', {
    schemaVersion: 1,
    bookingId: 'booking-1',
    amountMinor: 5000,
    currency: 'MYR',
    paymentStatus: 'cleared',
  });
  const result = await read('coach-1');
  expect(result.records[0].feeMinor).toBe(5000);
});
it('projects the same persisted record for Member, Coach and canonical Admin without mutations', async () => {
  const before = structuredClone([...store.documents]);
  for (const [uid, changes] of [['member-1', {}], ['coach-1', {}], ['admin-1', { coachId: 'coach-1' }]] as const) {
    const result = await read(uid, changes);
    expect(result.records).toHaveLength(1);
    expect(result.records[0]).toMatchObject({ bookingId: 'booking-1', status: 'pending_hold', startLabel: '10:00 GMT+8', endLabel: '11:00 GMT+8' });
    expect(result.records[0]).not.toHaveProperty('createdBy');
    expect(result).toMatchObject({ firstLocalDate: '2026-10-01', throughLocalDate: '2026-10-31' });
  }
  expect(queries.map(q => [q.ownerField, q.ownerId, q.branchIds, q.limit])).toEqual([['memberId', 'member-1', undefined, 21], ['coachId', 'coach-1', ['branch-1'], 21], ['coachId', 'coach-1', undefined, 21]]);
  expect([...store.documents]).toEqual(before);
});
it('labels expiry with its original calendar date when the appointment is tomorrow', async () => {
  const row = (await read()).records[0];
  expect(row.localDate).toBe('2026-10-02');
  expect(row.expiryLabel).toBe('2026-10-01 08:15 GMT+8');
  expect(row.expiryLabel.length).toBeLessThanOrEqual(80);
});
it.each([{ policyVersion: 'booking-v1\n' }, { timeZone: '+05:30' }])(
  'rejects stored metadata incompatible with the Member wire contract: %j', async change => {
    Object.assign(store.documents.get('orgs/org-1/bookings/booking-1')!, change);
    const before = structuredClone([...store.documents]);
    await expect(read()).rejects.toMatchObject({ code: 'failed-precondition' });
    expect([...store.documents]).toEqual(before);
  });
it('keeps Member reads after branch removal and Coach reads after publication withdrawal', async () => {
  store.documents.get('orgs/org-1/members/member-1')!.branchIds = [];
  store.documents.get('orgs/org-1/coaches/coach-1')!.status = 'inactive';
  expect((await read()).records).toHaveLength(1); expect((await read('coach-1')).records).toHaveLength(1);
  store.documents.get('orgs/org-1/members/coach-1')!.branchIds = [];
  expect((await read('coach-1')).records).toEqual([]); expect(queries).toHaveLength(2);
});
it.each(['staff-1', 'admin-1'])('denies missing selected Admin Coach or Staff alias before any query: %s', async uid => {
  await expect(read(uid)).rejects.toMatchObject({ code: 'permission-denied' }); expect(queries).toEqual([]);
});
it.each([
  ['users/member-1', { organizationId: 'elsewhere' }],
  ['orgs/org-1/members/member-1', { organizationId: 'elsewhere', role: 'member', status: 'active', branchIds: [] }],
  ['orgs/org-1/members/member-1', { organizationId: 'org-1', role: 'coach', status: 'active', branchIds: [] }],
  ['orgs/org-1', { status: 'inactive' }],
] as const)('rejects stale organization or non-owner role: %s', async (p, d) => {
  store.documents.set(p, d); await expect(read('member-1', { coachId: 'coach-1' })).rejects.toThrow(); expect(queries).toEqual([]);
});
it.each(['role', 'organization', 'assignment', 'branchStatus', 'policy'])('discards query data after current context changes: %s', async change => {
  const changing: BookingQueryReader = { read: async q => {
    const rows = await reader.read(q);
    if (change === 'role') store.documents.get('orgs/org-1/members/coach-1')!.role = 'member';
    if (change === 'organization') store.documents.get('users/coach-1')!.organizationId = 'elsewhere';
    if (change === 'assignment') store.documents.get('orgs/org-1/members/coach-1')!.branchIds = ['branch-2'];
    if (change === 'branchStatus') store.documents.get('orgs/org-1/branches/branch-1')!.status = 'inactive';
    if (change === 'policy') store.documents.get('orgs/org-1/settings/booking')!.timeZone = 'UTC';
    return rows;
  } };
  await expect(read('coach-1', {}, changing)).rejects.toThrow();
});
it('paginates 20+1 with document ID tie ordering and a stable last-row cursor', async () => {
  store.documents.delete('orgs/org-1/bookings/booking-1');
  for (let i = 0; i < 22; i++) { const bookingId = `b-${String(i).padStart(2, '0')}`; store.documents.set(`orgs/org-1/bookings/${bookingId}`, { ...record, bookingId }); }
  const page = await read(); expect(page.records).toHaveLength(20); expect(page.nextCursor).toEqual({ startAtMillis: start, bookingId: 'b-19' });
  const next = await read('member-1', { cursor: page.nextCursor }); expect(next.records.map(r => r.bookingId)).toEqual(['b-20', 'b-21']); expect(next.nextCursor).toBeUndefined();
});
it.each([{ memberId: 'other' }, { role: 'admin' }, { coachId: 'other' }, { schemaVersion: 2 }, { dayCount: 32 }, { firstLocalDate: '2026-06-01' }, { firstLocalDate: '2026-11-01' }, { cursor: { startAtMillis: start + 1, bookingId: 'x' } }, { cursor: { startAtMillis: now - 86400000, bookingId: 'x' } }, { cursor: { startAtMillis: start, bookingId: 'x', extra: true } }])('rejects invalid request/cursor before querying: %j', async change => {
  await expect(read('member-1', change)).rejects.toThrow(); expect(queries).toEqual([]);
});
it.each([{ status: 'expired' }, { status: ['confirmed'] }, { schemaVersion: 2 }, { memberId: 'other' }, { organizationId: 'other' }, { startAtMillis: start + 1 }, { endAtMillis: start + 1 }, { holdExpiresAtMillis: start + 1 }, { localDate: '2026-10-03' }, { timeZone: 'broken' }, { privateNotes: 'secret' }, { bookingId: 'different' }, { policyVersion: '' }])('fails closed on untrusted rows: %j', async change => {
  await expect(read('member-1', {}, { read: async () => [{ path: 'orgs/org-1/bookings/booking-1', data: { ...record, ...change } }] })).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('rejects wrong paths, unsorted results and cursor repeats', async () => {
  await expect(read('member-1', {}, { read: async () => [{ path: 'orgs/other/bookings/booking-1', data: record }] })).rejects.toThrow();
  await expect(read('member-1', { cursor: { startAtMillis: start, bookingId: 'booking-1' } }, { read: async () => [{ path: 'orgs/org-1/bookings/booking-1', data: record }] })).rejects.toThrow();
  await expect(read('member-1', {}, { read: async () => [{ path: 'orgs/org-1/bookings/z', data: { ...record, bookingId: 'z' } }, { path: 'orgs/org-1/bookings/a', data: { ...record, bookingId: 'a' } }] })).rejects.toThrow();
});
it('rejects duplicate persisted IDs even when timestamps increase', async () => {
  await expect(read('member-1', {}, { read: async () => [
    { path: 'orgs/org-1/bookings/booking-1', data: record },
    { path: 'orgs/org-1/bookings/booking-1', data: { ...record, startAtMillis: start + 1800000, endAtMillis: start + 5400000 } },
  ] })).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('limits Coach branches to current active assignments and rechecks row branch identity', async () => {
  store.documents.get('orgs/org-1/members/coach-1')!.branchIds = ['branch-1', 'branch-2'];
  store.documents.set('orgs/org-1/branches/branch-2', { status: 'inactive' });
  expect((await read('coach-1')).records).toHaveLength(1); expect(queries[0].branchIds).toEqual(['branch-1']);
  await expect(read('coach-1', {}, { read: async () => [{ path: 'orgs/org-1/bookings/booking-1', data: { ...record, branchId: 'branch-2' } }] })).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('allows canonical Admin to inspect an inactive/reassigned target’s existing records', async () => {
  store.documents.get('orgs/org-1/members/coach-1')!.status = 'inactive';
  store.documents.get('users/coach-1')!.organizationId = 'elsewhere';
  expect((await read('admin-1', { coachId: 'coach-1' })).records[0].bookingId).toBe('booking-1');
  await expect(read('coach-1')).rejects.toMatchObject({ code: 'permission-denied' });
});
it.each(['owner', 'organization', 'branch'])('rejects Member/Admin context drift during query: %s', async change => {
  const uid = change === 'branch' ? 'member-1' : 'admin-1';
  const changing: BookingQueryReader = { read: async q => {
    const rows = await reader.read(q);
    if (change === 'owner') store.documents.get('orgs/org-1/members/admin-1')!.role = 'staff';
    if (change === 'organization') store.documents.get('users/admin-1')!.organizationId = 'elsewhere';
    if (change === 'branch') store.documents.get('orgs/org-1/members/member-1')!.branchIds = [];
    return rows;
  } };
  await expect(read(uid, uid === 'admin-1' ? { coachId: 'coach-1' } : {}, changing)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('uses B2 UTC date boundaries across DST and clips at day 30', async () => {
  store.documents.get('orgs/org-1/settings/booking')!.timeZone = 'America/New_York';
  await read('member-1', { firstLocalDate: '2026-11-01', dayCount: 1 }, { read: async q => { queries.push(q); return []; } }, Date.parse('2026-10-31T12:00:00Z'));
  expect(queries[0].throughStartAtMillis - queries[0].firstStartAtMillis).toBe(25 * 3600000);
  const page = await read('member-1', { firstLocalDate: '2026-10-30', dayCount: 31 }, { read: async () => [] }); expect(page.throughLocalDate).toBe('2026-10-30');
});
it('preserves known statuses and original timezone labels after expiry/policy changes', async () => {
  store.documents.get('orgs/org-1/settings/booking')!.timeZone = 'UTC';
  for (const status of ['pending_hold', 'confirmed', 'cancelled', 'completed', 'refunded']) {
    store.documents.get('orgs/org-1/bookings/booking-1')!.status = status;
    expect((await read('member-1', {}, reader, now + 1800000)).records[0]).toMatchObject({ status, timeZone: 'Asia/Kuala_Lumpur', startLabel: '10:00 GMT+8' });
  }
});
it('requires verified Auth and strict schemas', async () => {
  await expect(getBookingListService(store, undefined, input, reader, () => now)).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(getBookingListService(store, { uid: 'member-1', token: {} }, input, reader, () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  const ajv = new Ajv(); const request = ajv.compile(JSON.parse(readFileSync('../contracts/v1/get-booking-list.request.schema.json', 'utf8'))); const response = ajv.compile(JSON.parse(readFileSync('../contracts/v1/get-booking-list.response.schema.json', 'utf8')));
  expect(request(input)).toBe(true); expect(request({ ...input, role: 'admin' })).toBe(false); expect(response(await read())).toBe(true); expect(response({ ...await read(), total: 1 })).toBe(false);
});
it('returns saved review stars only for opted-in participants', async () => {
  store.documents.set('orgs/org-1/bookings/booking-1/review/current', { schemaVersion: 1, bookingId: 'booking-1', coachId: 'coach-1', memberId: 'member-1', stars: 4 });
  expect((await read('member-1', { includeReviewDetails: true })).records[0]).toHaveProperty('reviewStars', 4);
  expect((await read()).records[0]).not.toHaveProperty('reviewStars');
});
