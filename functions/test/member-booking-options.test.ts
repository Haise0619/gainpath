import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { command, now, start, seeds, eligibleCoach } from './booking-fixture';
import { getMemberBookingOptionsService } from '../src/modules/coaching/member-booking-options-service';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { keyOf } from '../src/platform/idempotency';
import { dateGrid } from '../src/modules/coaching/coach-availability-contracts';
import { readFileSync } from 'node:fs';
import Ajv from 'ajv';

let store: MemoryStore;
const auth = { uid: 'member-1', token: { email_verified: true } };
const input = { schemaVersion: 1, organizationId: 'org-1', coachId: 'coach-1', localDate: '2026-10-02', durationMinutes: 60 };
const read = (changes = {}, time = now) => getMemberBookingOptionsService(store, auth, { ...input, ...changes }, eligibleCoach, () => time);
beforeEach(() => { store = new MemoryStore(); Object.entries(seeds).forEach(([p, d]) => store.documents.set(p, structuredClone(d))); });
it('rejects numeric policy timezone metadata incompatible with the Member wire contract', async () => {
  store.documents.get('orgs/org-1/settings/booking')!.timeZone = '+05:30';
  const before = structuredClone([...store.documents]);
  await expect(read({ localDate: undefined })).rejects.toMatchObject({ code: 'failed-precondition' });
  expect([...store.documents]).toEqual(before);
});
it('returns bounded 30/60-minute options with authoritative epochs, branches and labels without writing', async () => {
  const before = structuredClone([...store.documents]);
  const result = await read();
  expect(result.options).toHaveLength(7);
  expect(result.options[0]).toMatchObject({ branchId: 'branch-1', startAtMillis: start, endAtMillis: start + 3600000, startLabel: '10:00 GMT+8', endLabel: '11:00 GMT+8' });
  expect(result).toMatchObject({ todayLocalDate: '2026-10-01', throughLocalDate: '2026-10-31', permittedBranchIds: ['branch-1'] });
  expect((await read({ durationMinutes: 30 })).options).toHaveLength(8);
  expect([...store.documents]).toEqual(before);
});
it('checks both slots for 60 minutes and ignores only known expired locks', async () => {
  const path = `orgs/org-1/slotLocks/${keyOf('coach-1', start + 1800000)}`;
  store.documents.set(path, { schemaVersion: 1, coachId: 'coach-1', branchId: 'branch-1', bookingId: 'other', status: 'pending_hold', expiresAtMillis: now + 1000 });
  expect((await read()).options[0].startAtMillis).toBe(start + 3600000);
  expect((await read({}, now + 1000)).options[0].startAtMillis).toBe(start);
});
it('reports the current daily limit, then recovers after hold expiry', async () => {
  const hold = await createBookingHoldService(store, auth.uid, command, eligibleCoach, () => now);
  expect(await read()).toMatchObject({ options: [], unavailableReason: 'daily_limit' });
  expect((await read({}, hold.holdExpiresAtMillis)).options).toHaveLength(7);
});
it('defaults to server-local today and distinguishes no open times', async () => {
  expect(await read({ localDate: undefined })).toMatchObject({ localDate: '2026-10-01', options: [], unavailableReason: 'no_open_times' });
});
it.each([{ localDate: '2026-11-01' }, { localDate: '2026-09-30' }, { localDate: '2026-02-30' }, { durationMinutes: 45 }, { memberId: 'other' }, { schemaVersion: 2 }])('rejects malformed/out-of-range input %j', async change => {
  await expect(read(change)).rejects.toThrow();
});
it.each([
  ['users/member-1', { organizationId: 'elsewhere' }],
  ['users/coach-1', { organizationId: 'elsewhere' }],
  ['orgs/org-1', { status: 'inactive' }],
  ['orgs/org-1/coaches/coach-1', { status: 'inactive', branchIds: ['branch-1'] }],
  ['orgs/org-1/coachAvailability/coach-1/days/2026-10-02', { schemaVersion: 1, windows: [] }],
  ['orgs/org-1/settings/booking', {}],
] as const)('fails safely on current scope/policy/legacy day: %s', async (path, value) => {
  store.documents.set(path, value); const before = structuredClone([...store.documents]);
  await expect(read()).rejects.toThrow(); expect([...store.documents]).toEqual(before);
});
it.each([
  { schemaVersion: 2 }, { coachId: 'wrong' }, { bookingId: '' }, { status: 'unknown' }, { expiresAtMillis: 0 }, { expiresAtMillis: start + 1 }, { branchId: 'branch-2', status: 'confirmed' },
])('never treats malformed or mismatched locks as empty: %j', async change => {
  store.documents.set(`orgs/org-1/slotLocks/${keyOf('coach-1', start)}`, { schemaVersion: 1, coachId: 'coach-1', branchId: 'branch-1', bookingId: 'other', status: 'pending_hold', expiresAtMillis: now, ...change });
  await expect(read()).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('denies unverified callers and disabled/unverified/missing Coach Auth', async () => {
  await expect(getMemberBookingOptionsService(store, { ...auth, token: { email_verified: false } }, input, eligibleCoach, () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  for (const state of [{ exists: false, disabled: false, emailVerified: true }, { exists: true, disabled: true, emailVerified: true }, { exists: true, disabled: false, emailVerified: false }]) {
    await expect(getMemberBookingOptionsService(store, auth, input, async () => state, () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
  }
});
it('uses same-day future starts and the inclusive day-30 horizon for options and creation', async () => {
  const first = await read({}, start - 1000);
  expect(first.todayLocalDate).toBe('2026-10-02'); expect(first.options[0].startAtMillis).toBe(start);
  expect((await read({}, start)).options[0].startAtMillis).toBe(start + 1800000);
  const day30 = Date.parse('2026-10-31T02:00:00Z');
  store.documents.set('orgs/org-1/coachAvailability/coach-1/days/2026-10-31', { ...seeds['orgs/org-1/coachAvailability/coach-1/days/2026-10-02'], windows: [{ branchId: 'branch-1', startAtMillis: day30, endAtMillis: day30 + 3600000 }] });
  expect((await read({ localDate: '2026-10-31' })).options).toHaveLength(1);
  const result = await createBookingHoldService(store, auth.uid, { ...command, startAtMillis: day30 }, eligibleCoach, () => now);
  expect(result.status).toBe('pending_hold');
});
it('produces distinct UTC-grid options across repeated DST hours and rejects a cross-local-date hold', async () => {
  const zone = 'America/New_York', date = '2026-11-01', time = Date.parse('2026-10-31T12:00:00Z'), grid = dateGrid(date, zone);
  store.documents.get('orgs/org-1/settings/booking')!.timeZone = zone;
  store.documents.set(`orgs/org-1/coachAvailability/coach-1/days/${date}`, { schemaVersion: 1, revision: 1, timeZone: zone, policyVersion: 'older-policy', createdAtMillis: time, updatedAtMillis: time,
    windows: [{ branchId: 'branch-1', startAtMillis: grid.slots[0], endAtMillis: grid.slots.at(-1)! + 1800000 }] });
  const result = await read({ localDate: date, durationMinutes: 30 }, time);
  expect(result.options).toHaveLength(50);
  const repeated = result.options.filter(o => o.startLabel.startsWith('01:00'));
  expect(repeated).toHaveLength(2); expect(repeated[0].startLabel).not.toBe(repeated[1].startLabel);
  await expect(createBookingHoldService(store, auth.uid, { ...command, startAtMillis: grid.slots.at(-1)! }, eligibleCoach, () => time)).rejects.toMatchObject({ code: 'invalid-argument' });
  const valid = repeated[1];
  await expect(createBookingHoldService(store, auth.uid, { ...command, startAtMillis: valid.startAtMillis, durationMinutes: 30 }, eligibleCoach, () => time)).resolves.toMatchObject({ status: 'pending_hold' });
});
it('parses the whole Coach day before filtering shared branches and accepts old compatible policy metadata', async () => {
  const coach = store.documents.get('orgs/org-1/members/coach-1')!; coach.branchIds = ['branch-1', 'branch-2'];
  store.documents.get('orgs/org-1/members/member-1')!.branchIds = ['branch-1'];
  const path = 'orgs/org-1/coachAvailability/coach-1/days/2026-10-02';
  store.documents.set(path, { ...seeds[path], policyVersion: 'old-compatible', windows: [...seeds[path].windows, { branchId: 'branch-2', startAtMillis: start + 5 * 3600000, endAtMillis: start + 6 * 3600000 }] });
  expect((await read()).options).toHaveLength(7);
  store.documents.get(path)!.windows = [...seeds[path].windows, { branchId: 'unassigned', startAtMillis: start + 5 * 3600000, endAtMillis: start + 6 * 3600000 }];
  await expect(read()).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('rejects malformed daily identity and rereads scope after the external Auth lookup', async () => {
  store.documents.set(`orgs/org-1/bookingDays/${keyOf('member-1', '2026-10-02')}`, { schemaVersion: 1, memberId: 'other', localDate: '2026-10-02', timeZone: 'Asia/Kuala_Lumpur', reservations: [] });
  await expect(read()).rejects.toMatchObject({ code: 'failed-precondition' });
  store.documents.delete(`orgs/org-1/bookingDays/${keyOf('member-1', '2026-10-02')}`);
  await expect(getMemberBookingOptionsService(store, auth, input, async () => {
    store.documents.get('orgs/org-1/members/member-1')!.branchIds = [];
    return eligibleCoach('coach-1');
  }, () => now)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('matches the strict request/response schemas', async () => {
  const ajv = new Ajv();
  const request = ajv.compile(JSON.parse(readFileSync('../contracts/v1/get-member-booking-options.request.schema.json', 'utf8')));
  const response = ajv.compile(JSON.parse(readFileSync('../contracts/v1/get-member-booking-options.response.schema.json', 'utf8')));
  expect(request(input)).toBe(true); expect(request({ ...input, memberId: 'other' })).toBe(false);
  expect(response(await read())).toBe(true); expect(response(await read({ localDate: undefined }))).toBe(true);
  expect(response({ ...await read(), receipt: 'private' })).toBe(false);
});
it.each([
  { status: ['confirmed'] }, { status: ['pending_hold'] },
  { status: ['confirmed'], expiresAtMillis: now }, { status: ['pending_hold'], expiresAtMillis: now },
])('rejects array lock status without exposing options or changing data: %j', async malformed => {
  store.documents.set(`orgs/org-1/slotLocks/${keyOf('coach-1', start)}`, {
    schemaVersion: 1, coachId: 'coach-1', branchId: 'branch-1', bookingId: 'other', ...malformed,
  });
  const before = structuredClone([...store.documents]);
  await expect(read()).rejects.toMatchObject({ code: 'failed-precondition' });
  expect([...store.documents]).toEqual(before);
});
