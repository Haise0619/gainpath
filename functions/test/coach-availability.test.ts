import { eligibleCoach } from './booking-fixture';
import { expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { getCoachAvailabilityService, saveCoachAvailabilityDayService } from '../src/modules/coaching/coach-availability-service';
import { dateGrid, localDate } from '../src/modules/coaching/coach-availability-contracts';
import { keyOf } from '../src/platform/idempotency';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { readFileSync } from 'node:fs';
import Ajv from 'ajv';
import type { DocumentStore } from '../src/platform/firestore/store';

import { org, root, now, date, start, auth, windows, seeds, read, save } from './coach-availability.fixture';
function setup() { const store = new MemoryStore(); Object.entries(seeds()).forEach(([p, v]) => store.documents.set(p, v)); return store; }
const path = `${root}/coachAvailability/coach/days/${date}`;
it('creates/reads/edits/removes a dated day and replays receipts without changing protected data', async () => {
  const store = setup();
  const context = await getCoachAvailabilityService(store, auth('coach'), read(), () => now);
  expect(context.todayLocalDate).toBe('2026-10-15');
  expect(context.days[0]).toMatchObject({ localDate: '2026-10-15', editable: false });
  const first = await saveCoachAvailabilityDayService(store, auth('coach'), save(), () => now);
  expect(await saveCoachAvailabilityDayService(store, auth('coach'), save(), () => now + 1)).toEqual(first);
  await expect(saveCoachAvailabilityDayService(store, auth('coach'), save('save', 0, []), () => now)).rejects.toMatchObject({ code: 'already-exists' });
  await saveCoachAvailabilityDayService(store, auth('coach'), save('edit', 1, [...windows, { branchId: 'other', startAtMillis: start + 7200000, endAtMillis: start + 9000000 }]), () => now + 2);
  const member = await getCoachAvailabilityService(store, auth('member'), read(), () => now);
  expect(member.days.find(d => d.localDate === date)?.windows).toEqual(windows);
  expect(member.days.find(d => d.localDate === date)).not.toHaveProperty('revision');
  const admin = await getCoachAvailabilityService(store, auth('admin'), read(), () => now);
  expect(admin.days.find(d => d.localDate === date)?.windows).toHaveLength(2);
  await saveCoachAvailabilityDayService(store, auth('coach'), save('remove', 2, []), () => now + 3);
  expect(store.documents.get(path)).toMatchObject({ windows: [], revision: 3, createdAtMillis: now, updatedAtMillis: now + 3 });
  expect([...store.documents.keys()].some(p => /\/(bookings|slotLocks|jobs|workoutSessions)\//.test(p))).toBe(false);
});
it.each(['member', 'admin', 'staff', 'second-coach'])('denies unauthorized writer %s or another Coach reader', async uid => {
  const store = setup();
  if (uid === 'second-coach') await expect(getCoachAvailabilityService(store, auth(uid), read(), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  else await expect(saveCoachAvailabilityDayService(store, auth(uid), save(), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('rejects stale revisions, scope/policy/branch changes and unverification', async () => {
  const store = setup(); await saveCoachAvailabilityDayService(store, auth('coach'), save(), () => now);
  await expect(saveCoachAvailabilityDayService(store, auth('coach'), save('stale'), () => now)).rejects.toMatchObject({ code: 'aborted' });
  for (const change of [{ expectedPolicyVersion: 'old' }, { expectedTimeZone: 'UTC' }, { expectedCoachBranchIds: ['main'] }]) await expect(saveCoachAvailabilityDayService(store, auth('coach'), { ...save('changed', 1), ...change }, () => now)).rejects.toMatchObject({ code: 'aborted' });
  await expect(getCoachAvailabilityService(store, auth('coach', false), read(), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.get('users/coach')!.organizationId = 'elsewhere';
  await expect(saveCoachAvailabilityDayService(store, auth('coach'), save('drift', 1), () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(getCoachAvailabilityService(store, auth('member'), read(), () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('keeps legacy records read-only, rejects malformed stored days and withdrawn targets', async () => {
  const store = setup(); store.documents.set(path, { schemaVersion: 1, windows });
  expect((await getCoachAvailabilityService(store, auth('coach'), read(), () => now)).days.find(d => d.localDate === date)).toMatchObject({ editable: false, reviewRequired: true });
  await expect(saveCoachAvailabilityDayService(store, auth('coach'), save(), () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
  store.documents.set(path, { schemaVersion: 9, windows });
  await expect(getCoachAvailabilityService(store, auth('coach'), read(), () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
  store.documents.get(`${root}/coaches/coach`)!.status = 'inactive';
  await expect(getCoachAvailabilityService(store, auth('member'), read(), () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('normalizes adjacent windows and rejects overlaps, invalid branches and out-of-horizon dates', async () => {
  const store = setup();
  await saveCoachAvailabilityDayService(store, auth('coach'), save('touch', 0, [ { ...windows[0], endAtMillis: start + 1800000 }, { ...windows[0], startAtMillis: start + 1800000 } ]), () => now);
  expect(store.documents.get(path)?.windows).toEqual(windows);
  for (const change of [ { localDate: '2026-10-15' }, { localDate: '2026-11-15' }, { localDate: '2026-02-30' }, { windows: [{ ...windows[0], startAtMillis: -1 }] }, { windows: [windows[0], { ...windows[0], branchId: 'other' }] }, { windows: [{ ...windows[0], branchId: 'unknown' }] } ]) await expect(saveCoachAvailabilityDayService(store, auth('coach'), { ...save('bad', 1), ...change }, () => now)).rejects.toBeDefined();
});
it.each(['confirmed', 'pending_hold', 'unknown', 'malformed', 'orphan'])('preserves/fails closed on %s global Coach locks', async kind => {
  const store = setup(); await saveCoachAvailabilityDayService(store, auth('coach'), save(), () => now);
  const slot = kind === 'orphan' ? start + 7200000 : start;
  const lock = { schemaVersion: 1, coachId: 'coach', branchId: 'main', bookingId: 'b', status: kind === 'malformed' ? 'pending_hold' : kind === 'orphan' ? 'confirmed' : kind, expiresAtMillis: kind === 'malformed' ? 'bad' : now + 60000 };
  const lockPath = `${root}/slotLocks/${keyOf('coach', slot)}`; store.documents.set(lockPath, lock);
  await expect(saveCoachAvailabilityDayService(store, auth('coach'), save('remove', 1, []), () => now)).rejects.toBeDefined();
  await expect(saveCoachAvailabilityDayService(store, auth('coach'), save('move', 1, [{ ...windows[0], branchId: 'other' }]), () => now)).rejects.toBeDefined();
  if (['confirmed', 'pending_hold'].includes(kind)) await saveCoachAvailabilityDayService(store, auth('coach'), save('add', 1, [...windows, { branchId: 'other', startAtMillis: start + 7200000, endAtMillis: start + 9000000 }]), () => now);
  expect(store.documents.get(lockPath)).toEqual(lock);
});
it('allows removal past valid hold expiry and retains the existing booking consumer', async () => {
  const store = setup(); await saveCoachAvailabilityDayService(store, auth('coach'), save(), () => now);
  const hold = await createBookingHoldService(store, 'member', { schemaVersion: 1, organizationId: org, requestId: 'hold', memberId: 'member', coachId: 'coach', branchId: 'main', startAtMillis: start, durationMinutes: 60 }, eligibleCoach, () => now);
  const protectedBefore = [...store.documents].filter(([p]) => /\/(bookings|slotLocks|jobs)\//.test(p));
  await saveCoachAvailabilityDayService(store, auth('coach'), save('expired', 1, []), () => hold.holdExpiresAtMillis);
  expect([...store.documents].filter(([p]) => /\/(bookings|slotLocks|jobs)\//.test(p))).toEqual(protectedBefore);
});
it('generates UTC boundaries for rollover and DST without inventing wall times', () => {
  expect(localDate(now, 'Asia/Kuala_Lumpur')).toBe('2026-10-15');
  expect(dateGrid('2026-03-08', 'America/New_York').slots).toHaveLength(46);
  expect(dateGrid('2026-11-01', 'America/New_York').slots).toHaveLength(50);
  const repeated = dateGrid('2026-11-01', 'America/New_York').boundaries.filter(b => b.label.startsWith('01:00'));
  expect(repeated).toHaveLength(2); expect(repeated[0].label).not.toBe(repeated[1].label);
  expect(() => dateGrid('2011-12-30', 'Pacific/Apia')).toThrow();
});
it('allows organization Admin read without branch assignments and matches the optional JSON metadata contract', async () => {
  const store = setup(); store.documents.get(`${root}/members/admin`)!.branchIds = [];
  expect((await getCoachAvailabilityService(store, auth('admin'), read(), () => now)).coachId).toBe('coach');
  const validate = new Ajv().compile(JSON.parse(readFileSync('../contracts/v1/coach-availability.schema.json', 'utf8')));
  expect(validate({ schemaVersion: 1, windows })).toBe(true);
  await saveCoachAvailabilityDayService(store, auth('coach'), save(), () => now);
  expect(validate(store.documents.get(path))).toBe(true);
  expect(validate({ ...store.documents.get(path), privateNote: 'not permitted' })).toBe(false);
});
it('pins policy expectations outside transaction retries and enforces the inclusive horizon/window cap', async () => {
  const store = setup(), original = save();
  const changedInput: DocumentStore = { transact: work => store.transact(tx => work({ ...tx, get: async p => {
    if (p === 'users/coach') original.expectedPolicyVersion = 'changed';
    const value = await tx.get(p); return p.endsWith('/settings/booking') ? { ...value, policyVersion: 'changed' } : value;
  } })) };
  await expect(saveCoachAvailabilityDayService(changedInput, auth('coach'), original, () => now)).rejects.toMatchObject({ code: 'aborted' });
  const limit = Date.parse('2026-11-14T02:00:00Z');
  await saveCoachAvailabilityDayService(store, auth('coach'), { ...save('horizon'), localDate: '2026-11-14', windows: [{ branchId: 'main', startAtMillis: limit, endAtMillis: limit + 1800000 }] }, () => now);
  const midnight = Date.parse('2026-10-15T16:00:00Z');
  const many = Array.from({ length: 16 }, (_, i) => ({ branchId: 'main', startAtMillis: midnight + i * 3600000, endAtMillis: midnight + i * 3600000 + 1800000 }));
  await saveCoachAvailabilityDayService(store, auth('coach'), save('sixteen', 0, many), () => now);
  await expect(saveCoachAvailabilityDayService(store, auth('coach'), save('seventeen', 1, [...many, { branchId: 'main', startAtMillis: midnight + 16 * 3600000, endAtMillis: midnight + 16 * 3600000 + 1800000 }]), () => now)).rejects.toBeDefined();
});
