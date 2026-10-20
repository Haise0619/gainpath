import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now, start } from './booking-fixture';
import { bookingCommunication } from '../src/modules/coaching/booking-communication-service';

let store: MemoryStore;
const input = { schemaVersion: 1, organizationId: 'org-1', bookingId: 'booking-1' };
const auth = (uid: string) => ({ uid, token: { email_verified: true } });
const call = (uid: string, extra = {}) => bookingCommunication(store, auth(uid), { ...input, ...extra }, () => now);
beforeEach(() => {
  store = new MemoryStore();
  Object.entries(seeds).forEach(([p,d]) => store.documents.set(p, structuredClone(d)));
  store.documents.set('orgs/org-1/bookings/booking-1', {
    ...input, memberId: 'member-1', coachId: 'coach-1', branchId: 'branch-1', requestId: 'hold-1',
    createdBy: 'member-1', createdAtMillis: now, startAtMillis: start, endAtMillis: start + 3600000,
    durationMinutes: 60, status: 'pending_hold', holdExpiresAtMillis: now + 900000,
    localDate: '2026-10-02', timeZone: 'Asia/Kuala_Lumpur', policyVersion: 'booking-v1',
  });
});
it('persists questions and replies in server order; exact retry creates no duplicate', async () => {
  await call('member-1', { requestId: 'question-1', text: 'What should I bring?' });
  const reply = await call('coach-1', { requestId: 'reply-1', text: 'Bring water.' });
  expect(reply.messages.map(m => m.senderRole)).toEqual(['member', 'coach']);
  expect(reply.messages.map(m => m.sequence)).toEqual([1, 2]);
  expect(await call('coach-1', { requestId: 'reply-1', text: 'Bring water.' })).toEqual(reply);
  expect((await call('member-1')).messages).toEqual(reply.messages);
  await expect(call('coach-1', { requestId: 'reply-1', text: 'Changed' })).rejects.toMatchObject({ code: 'already-exists' });
});
it('denies unrelated roles and changed organization/branch access', async () => {
  await expect(call('staff-1')).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.get('orgs/org-1/members/coach-1')!.branchIds = [];
  await expect(call('coach-1')).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.get('users/member-1')!.organizationId = 'other';
  await expect(call('member-1')).rejects.toMatchObject({ code: 'permission-denied' });
});
it('rejects blank/oversized messages and forged participant fields without writes', async () => {
  const before = structuredClone([...store.documents]);
  for (const extra of [{ requestId: 'a', text: ' ' }, { requestId: 'a', text: 'x'.repeat(501) }, { senderRole: 'coach' }]) {
    await expect(call('member-1', extra)).rejects.toThrow();
  }
  expect([...store.documents]).toEqual(before);
});
it('closed bookings retain readable history but cannot receive new messages', async () => {
  await call('member-1', { requestId: 'a', text: 'Question' });
  store.documents.get('orgs/org-1/bookings/booking-1')!.status = 'cancelled';
  expect((await call('coach-1')).messages).toHaveLength(1);
  await expect(call('coach-1', { requestId: 'b', text: 'Answer' })).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('pages immutable history without gaps and denies elapsed pending-hold sends', async () => {
  for (let i = 0; i < 55; i++) await call('member-1', { requestId: `m-${i}`, text: `Message ${i}` });
  const page = await call('coach-1');
  expect(page.messages).toHaveLength(50);
  const older = await call('coach-1', { beforeSequence: page.nextBeforeSequence });
  expect([...older.messages, ...page.messages].map(m => m.sequence)).toEqual(Array.from({ length: 55 }, (_, i) => i + 1));
  await expect(bookingCommunication(store, auth('member-1'), { ...input, requestId: 'late', text: 'Too late' }, () => now + 900000)).rejects.toMatchObject({ code: 'failed-precondition' });
});
