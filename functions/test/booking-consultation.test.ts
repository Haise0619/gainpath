import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now, start } from './booking-fixture';
import { bookingConsultationNotes } from '../src/modules/coaching/booking-consultation-service';

let store: MemoryStore;
const path = 'orgs/org-1/bookings/booking-1';
const input = { schemaVersion: 1, organizationId: 'org-1', bookingId: 'booking-1' };
const publish = { requestId: 'notes-1', text: 'Practised controlled squats. Continue the agreed technique cues.' };
const call = (uid = 'coach-1', extra = {}, time = start + 3600000) =>
  bookingConsultationNotes(store, { uid, token: { email_verified: true } }, { ...input, ...extra }, () => time);
beforeEach(() => {
  store = new MemoryStore();
  Object.entries(seeds).forEach(([p, d]) => store.documents.set(p, structuredClone(d)));
  store.documents.set(path, { ...input, memberId: 'member-1', coachId: 'coach-1', branchId: 'branch-1', requestId: 'hold-1',
    createdBy: 'member-1', createdAtMillis: now, startAtMillis: start, endAtMillis: start + 3600000,
    durationMinutes: 60, status: 'confirmed', holdExpiresAtMillis: now + 900000,
    localDate: '2026-10-02', timeZone: 'Asia/Kuala_Lumpur', policyVersion: 'booking-v1' });
});
it('atomically publishes once, completes and reopens for both participants without other writes', async () => {
  store.documents.set('orgs/org-1/transactions/booking-1', { sentinel: 'unchanged' });
  const before = structuredClone([...store.documents]);
  const result = await call('coach-1', publish);
  expect(result).toMatchObject({ bookingId: 'booking-1', status: 'completed', canPublish: false, note: { text: publish.text, publishedAtMillis: start + 3600000 } });
  expect(store.documents.get(path)?.status).toBe('completed');
  expect(await call('coach-1', publish)).toEqual(result);
  expect((await call('member-1')).note).toEqual(result.note);
  expect((await call('coach-1')).note).toEqual(result.note);
  for (const [p, d] of before) if (p !== path) expect(store.documents.get(p)).toEqual(d);
});
it('rejects unrelated roles, Member writes and revoked Coach branch access', async () => {
  await expect(call('member-1', publish)).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(call('staff-1')).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.get('orgs/org-1/members/coach-1')!.branchIds = [];
  await expect(call()).rejects.toMatchObject({ code: 'permission-denied' });
  expect(store.documents.get(path)?.status).toBe('confirmed');
});
it('rejects early, unpaid, cancelled sessions and invalid text without mutations', async () => {
  const before = structuredClone([...store.documents]);
  await expect(call('coach-1', publish, start)).rejects.toMatchObject({ code: 'failed-precondition' });
  for (const text of [' ', 'x'.repeat(5001)]) await expect(call('coach-1', { ...publish, text })).rejects.toThrow('Enter notes');
  expect([...store.documents]).toEqual(before);
  for (const status of ['pending_hold', 'cancelled']) {
    store.documents.get(path)!.status = status;
    await expect(call('coach-1', publish)).rejects.toThrow();
  }
});
it('rejects changed retry payload and another attempt to overwrite published notes', async () => {
  await call('coach-1', publish);
  await expect(call('coach-1', { ...publish, text: 'Different' })).rejects.toMatchObject({ code: 'already-exists' });
  await expect(call('coach-1', { ...publish, requestId: 'notes-2' })).rejects.toMatchObject({ code: 'failed-precondition' });
});
