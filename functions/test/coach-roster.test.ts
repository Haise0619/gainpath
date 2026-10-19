import { expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { auth, date, now, org, read, root, save, seeds, start, windows } from './coach-availability.fixture';
import { eligibleCoach } from './booking-fixture';
import { getCoachRosterService, saveCoachRosterService, getCoachAvailabilityService, saveCoachAvailabilityDayService } from '../src/modules/coaching/coach-availability-service';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { getMemberBookingOptionsService } from '../src/modules/coaching/member-booking-options-service';
import { keyOf } from '../src/platform/idempotency';
import { weekly, rosterSave } from './coach-roster.fixture';
import { weeklyWindows } from '../src/modules/coaching/coach-roster-contracts';
import type { DocumentStore } from '../src/platform/firestore/store';
import Ajv from 'ajv';
import { readFileSync } from 'node:fs';

const rosterRead = { schemaVersion: 1, organizationId: org, coachId: 'coach' };
const parent = `${root}/coachAvailability/coach`;
const dayPath = `${parent}/days/${date}`;
function setup() { const store = new MemoryStore(); Object.entries(seeds()).forEach(([p, v]) => store.documents.set(p, v)); return store; }
const hold = (requestId = 'hold', at = start, durationMinutes = 60) => ({ schemaVersion: 1, organizationId: org, requestId, memberId: 'member', coachId: 'coach', branchId: 'main', startAtMillis: at, durationMinutes });
const block = (id = 'break', from = start, to = start + 1800000) => ({ id, type: 'breakTime', reason: 'Lunch', startAtMillis: from, endAtMillis: to });

it('reads missing roster privately, creates weekly fallback and retains explicit dated override priority', async () => {
  const store = setup();
  expect(await getCoachRosterService(store, auth('coach'), rosterRead, () => now)).toMatchObject({ revision: 0, weeklyAvailability: null, exceptions: [] });
  const saved = await saveCoachRosterService(store, auth('coach'), rosterSave(), () => now);
  expect(saved).toMatchObject({ revision: 1, weeklyAvailability: weekly, throughLocalDate: '2026-11-14' });
  const view = await getCoachAvailabilityService(store, auth('member'), read(), () => now);
  expect(view.days.find(d => d.localDate === date)?.windows).toEqual([{ branchId: 'main', startAtMillis: start, endAtMillis: start + 14400000 }]);
  await saveCoachAvailabilityDayService(store, auth('coach'), { ...save(), expectedRosterRevision: 1 }, () => now);
  expect((await getCoachAvailabilityService(store, auth('member'), read(), () => now)).days.find(d => d.localDate === date)?.windows).toEqual(windows);
  expect((await getCoachAvailabilityService(store, auth('coach'), read(), () => now))).toMatchObject({ rosterRevision: 1 });
});
it('masks multi-day overlapping exceptions, edits and removes atomically without leaking reasons', async () => {
  const store = setup();
  const blocks = [block('leave', start, start + 86400000 + 3600000), block('overlap', start + 86400000, start + 86400000 + 7200000)];
  await saveCoachRosterService(store, auth('coach'), rosterSave('create', 0, blocks), () => now);
  const privateView = await getCoachAvailabilityService(store, auth('coach'), read(), () => now);
  const publicView = await getCoachAvailabilityService(store, auth('member'), read(), () => now);
  expect(privateView.days.find(d => d.localDate === date)?.windows[0].startAtMillis).toBe(start);
  expect(publicView.days.find(d => d.localDate === date)?.windows).toEqual([]);
  expect(JSON.stringify(publicView)).not.toContain('Lunch');
  await saveCoachRosterService(store, auth('coach'), rosterSave('remove-first', 1, [blocks[1]]), () => now);
  const next = await getCoachAvailabilityService(store, auth('member'), read(), () => now);
  expect(next.days.find(d => d.localDate === '2026-10-17')?.windows[0].startAtMillis).toBe(start + 86400000 + 7200000);
  await saveCoachRosterService(store, auth('coach'), rosterSave('edit', 2, [block('overlap', start + 1800000, start + 3600000)]), () => now);
  expect((await getCoachAvailabilityService(store, auth('member'), read(), () => now)).days.find(d => d.localDate === date)?.windows).toHaveLength(2);
});
it.each(['confirmed', 'pending_hold'])('rejects exception collisions and pins old weekly hours for %s reservations', async status => {
  const store = setup(); await saveCoachRosterService(store, auth('coach'), rosterSave(), () => now);
  store.documents.set(`${root}/slotLocks/${keyOf('coach', start)}`, { schemaVersion: 1, coachId: 'coach', branchId: 'main', bookingId: 'reserved', status, expiresAtMillis: now + 60000 });
  await expect(saveCoachRosterService(store, auth('coach'), rosterSave('blocked', 1, [block()]), () => now)).rejects.toMatchObject({ code: 'aborted' });
  const inactive = { ...weekly, schedule: weekly.schedule.map(d => ({ ...d, isActive: false })) };
  await saveCoachRosterService(store, auth('coach'), { ...rosterSave('weekly', 1), weeklyAvailability: inactive }, () => now);
  expect(store.documents.get(dayPath)).toMatchObject({ revision: 1, windows: [{ branchId: 'main', startAtMillis: start, endAtMillis: start + 14400000 }] });
  expect((await getCoachAvailabilityService(store, auth('member'), read(), () => now)).days.find(d => d.localDate === date)?.windows).toHaveLength(1);
  expect((await getCoachAvailabilityService(store, auth('member'), read(), () => now)).days.find(d => d.localDate === '2026-10-17')?.windows).toEqual([]);
});
it('rejects orphan reservations and malformed parent data without changes', async () => {
  const store = setup(); await saveCoachRosterService(store, auth('coach'), rosterSave(), () => now);
  store.documents.set(`${root}/slotLocks/${keyOf('coach', start - 3600000)}`, { schemaVersion: 1, coachId: 'coach', branchId: 'main', bookingId: 'orphan', status: 'confirmed' });
  await expect(saveCoachRosterService(store, auth('coach'), { ...rosterSave('orphan', 1), weeklyAvailability: { ...weekly, schedule: weekly.schedule.map(d => ({ ...d, endMinute: 870 })) } }, () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
  store.documents.get(parent)!.exceptions = 'bad';
  await expect(getCoachRosterService(store, auth('coach'), rosterRead, () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('checks current authorization on replay, rejects stale saves and protects private roster', async () => {
  const store = setup(), saved = await saveCoachRosterService(store, auth('coach'), rosterSave(), () => now);
  expect(await saveCoachRosterService(store, auth('coach'), rosterSave(), () => now + 1)).toEqual(saved);
  await expect(saveCoachRosterService(store, auth('coach'), rosterSave('stale'), () => now)).rejects.toMatchObject({ code: 'aborted' });
  await expect(saveCoachRosterService(store, auth('coach'), { ...rosterSave(), exceptions: [block()] }, () => now)).rejects.toMatchObject({ code: 'already-exists' });
  for (const uid of ['member', 'staff', 'second-coach']) await expect(getCoachRosterService(store, auth(uid), rosterRead, () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  expect((await getCoachRosterService(store, auth('admin'), rosterRead, () => now)).revision).toBe(1);
  store.documents.get('users/coach')!.organizationId = 'elsewhere';
  await expect(saveCoachRosterService(store, auth('coach'), rosterSave(), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('requires roster revision for dated edits and validates changed future blocks while retaining historical blocks', async () => {
  const store = setup(); await saveCoachRosterService(store, auth('coach'), rosterSave('first', 0, [block()]), () => now);
  await expect(saveCoachAvailabilityDayService(store, auth('coach'), save(), () => now)).rejects.toMatchObject({ code: 'aborted' });
  await saveCoachAvailabilityDayService(store, auth('coach'), { ...save(), expectedRosterRevision: 1 }, () => now);
  await saveCoachRosterService(store, auth('coach'), rosterSave('later', 1, [block()]), () => start + 3600000);
  await expect(saveCoachRosterService(store, auth('coach'), rosterSave('historical-edit', 2, [{ ...block(), reason: 'changed' }]), () => start + 3600000)).rejects.toMatchObject({ name: 'InputValidationError' });
  await saveCoachRosterService(store, auth('coach'), rosterSave('historical-remove', 2), () => start + 3600000);
});
it('enforces HOURS for 60 minute holds, keeps member limits separate, and ignores expired locks', async () => {
  const store = setup(); await saveCoachRosterService(store, auth('coach'), { ...rosterSave(), weeklyAvailability: { ...weekly, dailyCapacityHours: 1 } }, () => now);
  const first = await createBookingHoldService(store, 'member', hold(), eligibleCoach, () => now);
  await expect(createBookingHoldService(store, 'member', hold('next', start + 3600000, 30), eligibleCoach, () => now)).rejects.toMatchObject({ code: 'resource-exhausted' });
  const options = await getMemberBookingOptionsService(store, auth('member'), { ...rosterRead, localDate: date, durationMinutes: 30 }, eligibleCoach, () => now);
  expect(options.options).toEqual([]);
  expect(await createBookingHoldService(store, 'member', hold(), eligibleCoach, () => first.holdExpiresAtMillis)).toMatchObject({ bookingId: first.bookingId });
  await createBookingHoldService(store, 'member', hold('after-expiry', start + 3600000), eligibleCoach, () => first.holdExpiresAtMillis);
});
it('enforces inclusive organization-local advance window in options and checkout', async () => {
  const store = setup(); await saveCoachRosterService(store, auth('coach'), { ...rosterSave(), weeklyAvailability: { ...weekly, advanceBookingWindowDays: 1 } }, () => now);
  await createBookingHoldService(store, 'member', hold(), eligibleCoach, () => now);
  await expect(createBookingHoldService(store, 'member', hold('late', start + 86400000), eligibleCoach, () => now)).rejects.toMatchObject({ code: 'invalid-argument' });
  const result = await getMemberBookingOptionsService(store, auth('member'), { ...rosterRead, localDate: date, durationMinutes: 30 }, eligibleCoach, () => now);
  expect(result.throughLocalDate).toBe('2026-10-16');
  expect((await getCoachAvailabilityService(store, auth('member'), read(), () => now)).days.find(d => d.localDate === '2026-10-17')?.windows).toEqual([]);
});
it('requires a complete weekly configuration when saving the roster', async () => {
  await expect(saveCoachRosterService(setup(), auth('coach'), { ...rosterSave(), weeklyAvailability: null }, () => now)).rejects.toMatchObject({ name: 'InputValidationError' });
});
it.each([
  { weeklyAvailability: { ...weekly, dailyCapacityHours: 0 } },
  { weeklyAvailability: { ...weekly, advanceBookingWindowDays: 31 } },
  { weeklyAvailability: { ...weekly, schedule: weekly.schedule.map(d => ({ ...d, dayOfWeek: 1 })) } },
  { weeklyAvailability: { ...weekly, schedule: weekly.schedule.map(d => ({ ...d, startMinute: 601 })) } },
  { weeklyAvailability: { ...weekly, schedule: weekly.schedule.map(d => ({ ...d, branchId: 'unassigned' })) } },
  { exceptions: [block(), block()] },
  { exceptions: [{ ...block(), reason: 'x'.repeat(201) }] },
  { exceptions: [{ ...block(), startLabel: 'client supplied' }] },
  { exceptions: [block('bad', now - 60000, start)] },
  { exceptions: [block('bad', start, start + 32 * 86400000)] },
  { unknown: true },
])('rejects malformed roster input without changing storage %#', async change => {
  const store = setup(), before = structuredClone([...store.documents]);
  await expect(saveCoachRosterService(store, auth('coach'), { ...rosterSave(), ...change }, () => now)).rejects.toBeDefined();
  expect([...store.documents]).toEqual(before);
});
it('returns local exception labels without persisting them and rejects current policy/scope drift', async () => {
  const store = setup(), saved = await saveCoachRosterService(store, auth('coach'), rosterSave('first', 0, [block()]), () => now);
  expect(saved.exceptions[0].startLabel).toContain('10:00');
  expect(saved.exceptions[0].startLabel).toContain('GMT+8');
  const validate = new Ajv().compile(JSON.parse(readFileSync('../contracts/v1/coach-roster.schema.json', 'utf8')));
  expect(validate(saved)).toBe(true);
  expect((store.documents.get(parent)?.exceptions as object[])[0]).not.toHaveProperty('startLabel');
  for (const uid of ['admin', 'member', 'staff']) await expect(saveCoachRosterService(store, auth(uid), rosterSave('unauthorized', 1), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(saveCoachRosterService(store, auth('coach', false), rosterSave('unverified', 1), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(saveCoachRosterService(store, auth('coach'), { ...rosterSave('drift', 1), expectedPolicyVersion: 'old' }, () => now)).rejects.toMatchObject({ code: 'aborted' });
});
it('replays the originally saved full snapshot after a later roster update', async () => {
  const store = setup(), initial = rosterSave('initial', 0, [block()]);
  const first = await saveCoachRosterService(store, auth('coach'), initial, () => now);
  await saveCoachRosterService(store, auth('coach'), rosterSave('later', 1), () => now + 1);
  expect(await saveCoachRosterService(store, auth('coach'), initial, () => now + 2)).toEqual(first);
  expect((await getCoachRosterService(store, auth('coach'), rosterRead, () => now + 2)).exceptions).toEqual([]);
});
it('retains existing holds when lowering capacity while blocking all additional hours', async () => {
  const store = setup(); await saveCoachRosterService(store, auth('coach'), rosterSave(), () => now);
  const first = await createBookingHoldService(store, 'member', hold(), eligibleCoach, () => now);
  await createBookingHoldService(store, 'member', hold('second', start + 3600000, 30), eligibleCoach, () => now);
  await saveCoachRosterService(store, auth('coach'), { ...rosterSave('lower', 1), weeklyAvailability: { ...weekly, dailyCapacityHours: 1 } }, () => now);
  expect(await createBookingHoldService(store, 'member', hold(), eligibleCoach, () => now)).toEqual(first);
  expect((await getMemberBookingOptionsService(store, auth('member'), { ...rosterRead, localDate: date, durationMinutes: 30 }, eligibleCoach, () => now)).options).toEqual([]);
  expect(store.documents.get(`${root}/slotLocks/${keyOf('coach', start)}`)?.bookingId).toBe(first.bookingId);
});
it('derives recurring wall times across DST without inventing or dropping repeated slots', () => {
  const allDay = { ...weekly, schedule: weekly.schedule.map(d => ({ ...d, startMinute: 0, endMinute: 1440 })) };
  const spring = weeklyWindows('2026-03-08', 'America/New_York', allDay);
  const fall = weeklyWindows('2026-11-01', 'America/New_York', allDay);
  expect(spring).toEqual([{ branchId: 'main', startAtMillis: Date.parse('2026-03-08T05:00:00Z'), endAtMillis: Date.parse('2026-03-09T04:00:00Z') }]);
  expect(fall).toEqual([{ branchId: 'main', startAtMillis: Date.parse('2026-11-01T04:00:00Z'), endAtMillis: Date.parse('2026-11-02T05:00:00Z') }]);
});
it('updates limits without reading reservation locks or mutating protected records', async () => {
  const store = setup(); await saveCoachRosterService(store, auth('coach'), rosterSave(), () => now);
  await createBookingHoldService(store, 'member', hold(), eligibleCoach, () => now);
  const protectedBefore = structuredClone([...store.documents].filter(([p]) => /\/(bookings|slotLocks|jobs|bookingDays)\//.test(p)));
  const reads: string[] = [];
  const counting: DocumentStore = { transact: work => store.transact(tx => work({ ...tx, get: async path => { reads.push(path); return tx.get(path); } })) };
  await saveCoachRosterService(counting, auth('coach'), { ...rosterSave('limits', 1), weeklyAvailability: { ...weekly, dailyCapacityHours: 1, advanceBookingWindowDays: 14 } }, () => now);
  expect(reads.some(path => path.includes('/slotLocks/'))).toBe(false);
  expect([...store.documents].filter(([p]) => /\/(bookings|slotLocks|jobs|bookingDays)\//.test(p))).toEqual(protectedBefore);
});
