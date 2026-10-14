import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { command, now, start, seeds, eligibleCoach } from './booking-fixture';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { cancelBookingHoldService, expireBookingHoldService } from '../src/modules/coaching/booking-lifecycle-service';
import { keyOf } from '../src/platform/idempotency';
import { readFileSync } from 'node:fs';
import Ajv from 'ajv';

let store: MemoryStore, clock: number, id: string;
const root = 'orgs/org-1';
const cancel = (requestId = 'cancel-1', uid = 'member-1') => cancelBookingHoldService(store,
  { uid, token: { email_verified: true } }, { schemaVersion: 1, organizationId: 'org-1', bookingId: id, requestId }, () => clock);
const expire = () => expireBookingHoldService(store, `${root}/jobs/${keyOf('expireBookingHold', id)}`, () => clock);
beforeEach(async () => {
  store = new MemoryStore(); clock = now;
  Object.entries(seeds).forEach(([p, d]) => store.documents.set(p, structuredClone(d)));
  id = (await createBookingHoldService(store, 'member-1', command, eligibleCoach, () => clock)).bookingId;
});
it('cancels only its pending resources, retains history and creation receipt, then permits replacement', async () => {
  const original = structuredClone(store.documents.get(`${root}/bookings/${id}`)!);
  clock++;
  const result = await cancel();
  expect(result).toMatchObject({ status: 'cancelled', outcome: 'cancelled', resolvedAtMillis: clock });
  expect(store.documents.get(`${root}/bookings/${id}`)).toEqual({ ...original, status: 'cancelled', resolvedAtMillis: clock, resolution: 'member_cancelled' });
  expect([...store.documents].filter(([p]) => p.includes('/slotLocks/')).every(([, d]) => d.expiresAtMillis === clock)).toBe(true);
  expect(store.documents.get(`${root}/bookingDays/${keyOf('member-1', '2026-10-02')}`)?.reservations).toEqual([]);
  expect(await cancel()).toEqual(result);
  expect((await createBookingHoldService(store, 'member-1', command, eligibleCoach, () => clock)).bookingId).toBe(id);
  const next = await createBookingHoldService(store, 'member-1', { ...command, requestId: 'new' }, eligibleCoach, () => ++clock);
  await expire();
  expect([...store.documents].filter(([p]) => p.includes('/slotLocks/')).every(([, d]) => d.bookingId === next.bookingId)).toBe(true);
});
it('uses the server deadline; early workers do nothing and cancellation at deadline expires', async () => {
  const before = structuredClone([...store.documents]);
  expect(await expire()).toBe('not_due'); expect([...store.documents]).toEqual(before);
  clock += 900000;
  expect(await cancel()).toMatchObject({ status: 'expired', outcome: 'expired' });
  expect(await expire()).toBe('already_processed');
});
it('late expiry preserves replacement locks and reservations even when policy/Coach eligibility changed', async () => {
  clock += 900000;
  const next = await createBookingHoldService(store, 'member-1', { ...command, requestId: 'new' }, eligibleCoach, () => clock);
  const resources = structuredClone([...store.documents].filter(([p]) => p.includes('/slotLocks/') || p.includes('/bookingDays/')));
  store.documents.set(`${root}/settings/booking`, {}); store.documents.set(`${root}/coaches/coach-1`, { status: 'inactive' });
  expect(await expire()).toBe('expired');
  expect([...store.documents].filter(([p]) => p.includes('/slotLocks/') || p.includes('/bookingDays/'))).toEqual(resources);
  expect(store.documents.get(`${root}/bookings/${next.bookingId}`)?.status).toBe('pending_hold');
});
it.each(['confirmed', 'completed', 'refunded'])('never cancels or releases %s bookings', async status => {
  Object.assign(store.documents.get(`${root}/bookings/${id}`)!, { status });
  await expect(cancel()).rejects.toMatchObject({ code: 'failed-precondition' });
  const resources = structuredClone([...store.documents].filter(([p]) => p.includes('/slotLocks/') || p.includes('/bookingDays/')));
  clock += 900000; expect(await expire()).toBe('not_pending');
  expect([...store.documents].filter(([p]) => p.includes('/slotLocks/') || p.includes('/bookingDays/'))).toEqual(resources);
});
it('preserves other reservations verbatim and fails closed on owned confirmed locks', async () => {
  const day = store.documents.get(`${root}/bookingDays/${keyOf('member-1', '2026-10-02')}`)!;
  const other = { bookingId: 'other', status: 'confirmed', expiresAtMillis: start };
  (day.reservations as unknown[]).push(other);
  const lock = [...store.documents].find(([p]) => p.includes('/slotLocks/'))![1]; lock.status = 'confirmed';
  const before = structuredClone([...store.documents]); await expect(cancel()).rejects.toMatchObject({ code: 'failed-precondition' }); expect([...store.documents]).toEqual(before);
  lock.status = 'pending_hold'; await cancel();
  expect(store.documents.get(`${root}/bookingDays/${keyOf('member-1', '2026-10-02')}`)?.reservations).toEqual([other]);
});
it.each(['coach-1', 'staff-1', 'other'])('denies cancellation by %s', async uid => {
  const before = structuredClone([...store.documents]); await expect(cancel('c', uid)).rejects.toThrow(); expect([...store.documents]).toEqual(before);
});
it('rechecks account scope before receipt replay and rejects changed intent or missing record', async () => {
  await cancel();
  await expect(cancelBookingHoldService(store, { uid: 'member-1', token: { email_verified: true } }, { schemaVersion: 1, organizationId: 'org-1', bookingId: 'different', requestId: 'cancel-1' }, () => clock)).rejects.toMatchObject({ code: 'already-exists' });
  store.documents.set('users/member-1', { organizationId: 'other' });
  await expect(cancel()).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.set('users/member-1', { organizationId: 'org-1' }); store.documents.delete(`${root}/bookings/${id}`);
  await expect(cancel('new')).rejects.toMatchObject({ code: 'not-found' });
});
it('concurrent cancellation and expiry converge once without touching unrelated data', async () => {
  clock += 900000;
  await Promise.all([cancel(), expire(), cancel()]);
  expect(store.documents.get(`${root}/bookings/${id}`)?.status).toBe('expired');
  expect(store.documents.get(`${root}/jobs/${keyOf('expireBookingHold', id)}`)?.status).toBe('completed');
});
it('shared JSON schemas agree with callable cancellation and terminal list contracts', async () => {
  const ajv = new Ajv();
  const request = ajv.compile(JSON.parse(readFileSync('../contracts/v1/cancel-booking-hold.request.schema.json', 'utf8')));
  const response = ajv.compile(JSON.parse(readFileSync('../contracts/v1/cancel-booking-hold.response.schema.json', 'utf8')));
  expect(request({ schemaVersion: 1, organizationId: 'org-1', bookingId: id, requestId: 'cancel' })).toBe(true);
  expect(request({ schemaVersion: 1, organizationId: 'org-1', bookingId: id, requestId: 'cancel', status: 'cancelled' })).toBe(false);
  const result = await cancel(); expect(response(result)).toBe(true);
  expect(response({ ...result, status: 'expired' })).toBe(false);
});
