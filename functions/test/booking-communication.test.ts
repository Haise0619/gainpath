import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now, start } from './booking-fixture';
import { bookingCommunication } from '../src/modules/coaching/booking-communication-service';
import { keyOf } from '../src/platform/idempotency';

let store: MemoryStore;
const input = { schemaVersion: 1, organizationId: 'org-1', bookingId: 'booking-1' };
const auth = (uid: string) => ({ uid, token: { email_verified: true } });
const call = (uid: string, extra = {}) => bookingCommunication(store, auth(uid), { ...input, ...extra }, () => now);
function seedMessage(uid: string, requestId: string, text: string) {
  const root = 'orgs/org-1/bookings/booking-1';
  const sequence = Number(store.documents.get(root + '/communicationState/current')?.count ?? 0) + 1;
  store.documents.set(root + '/messages/' + sequence, { sequence, senderRole: uid === 'coach-1' ? 'coach' : 'member', text, sentAtMillis: now });
  store.documents.set(root + '/communicationState/current', { schemaVersion: 1, count: sequence });
  store.documents.set('orgs/org-1/commandReceipts/' + keyOf('bookingMessage', uid, requestId), { schemaVersion: 1, command: 'bookingMessage', actorId: uid, fingerprint: keyOf('org-1', 'booking-1', text), bookingId: 'booking-1', sequence, createdAtMillis: now });
}
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
it('reads pre-upgrade questions and replies in server order; exact retry creates no duplicate', async () => {
  seedMessage('member-1', 'question-1', 'What should I bring?');
  seedMessage('coach-1', 'reply-1', 'Bring water.');
  const reply = await call('coach-1', { requestId: 'reply-1', text: 'Bring water.' });
  expect(reply.messages.map(m => m.senderRole)).toEqual(['member', 'coach']);
  expect(reply.messages.map(m => m.sequence)).toEqual([1, 2]);
  expect(await call('coach-1', { requestId: 'reply-1', text: 'Bring water.' })).toEqual(reply);
  expect((await call('member-1')).messages).toEqual(reply.messages);
  await expect(call('coach-1', { requestId: 'reply-1', text: 'Changed' })).rejects.toMatchObject({ code: 'already-exists' });
});
it('v1 production calls are history/reconciliation only and cannot bypass pair eligibility', async () => {
  const readOnly = (extra = {}) => bookingCommunication(store, auth('member-1'), { ...input, ...extra }, () => now);
  await expect(readOnly({ requestId: 'new-old-app', text: 'Bypass' })).rejects.toMatchObject({ code: 'failed-precondition' });
  seedMessage('member-1', 'old-accepted', 'Accepted before upgrade');
  expect((await readOnly()).messages).toHaveLength(1);
  expect((await readOnly({ requestId: 'old-accepted', text: 'Accepted before upgrade' })).messages).toHaveLength(1);
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
  seedMessage('member-1', 'a', 'Question');
  store.documents.get('orgs/org-1/bookings/booking-1')!.status = 'cancelled';
  expect((await call('coach-1')).messages).toHaveLength(1);
  await expect(call('coach-1', { requestId: 'b', text: 'Answer' })).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('pages immutable history without gaps and denies elapsed pending-hold sends', async () => {
  for (let i = 0; i < 55; i++) seedMessage('member-1', `m-${i}`, `Message ${i}`);
  const page = await call('coach-1');
  expect(page.messages).toHaveLength(50);
  const older = await call('coach-1', { beforeSequence: page.nextBeforeSequence });
  expect([...older.messages, ...page.messages].map(m => m.sequence)).toEqual(Array.from({ length: 55 }, (_, i) => i + 1));
  await expect(bookingCommunication(store, auth('member-1'), { ...input, requestId: 'late', text: 'Too late' }, () => now + 900000)).rejects.toMatchObject({ code: 'failed-precondition' });
});
