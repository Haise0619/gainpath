import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it, vi } from 'vitest';
import { FirestoreConversationStore } from '../src/modules/coaching/pair-conversation-store';
import { pairConversation } from '../src/modules/coaching/pair-conversation-service';
import { seeds, now, start } from '../test/booking-fixture';
import { settleConcurrentEmulatorRequests } from './loopback-emulator';

let app: App, db: Firestore;
const input = { schemaVersion: 2, organizationId: 'org-1', bookingId: 'pair-booking-1' };
const auth = (uid: string) => ({ uid, token: { email_verified: true } });
const call = (uid = 'member-1', fields = {}, time = now) => pairConversation(new FirestoreConversationStore(db), auth(uid), { ...input, ...fields }, () => time);
const sendQuestion = () => call('member-1', { requestId: 'same', text: 'Shared question' });

async function expectSingleQuestion(conversationId: string) {
  const thread = db.doc('orgs/org-1/coachingConversations/' + conversationId);
  const [state, messages, receipts] = await Promise.all([
    thread.get(), thread.collection('messages').get(), thread.collection('receipts').get(),
  ]);
  expect(state.data()).toMatchObject({ count: 1, memberSent: 1, coachSent: 0 });
  expect(messages.docs.map(doc => doc.data())).toEqual([{ senderRole: 'member', text: 'Shared question', sentAtMillis: now }]);
  expect(receipts.docs.map(doc => doc.data())).toEqual([
    { fingerprint: expect.any(String), messageId: messages.docs[0].id, createdAtMillis: now },
  ]);
}

beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required; never target production.');
  app = initializeApp({ projectId: 'demo-gainpath' }, 'pair-conversation'); db = getFirestore(app);
});
beforeEach(async () => {
  await db.recursiveDelete(db.collection('orgs')); await db.recursiveDelete(db.collection('users'));
  const batch = db.batch(); Object.entries(seeds).forEach(([p, d]) => batch.set(db.doc(p), d));
  for (const id of ['pair-booking-1', 'pair-booking-2']) batch.set(db.doc('orgs/org-1/bookings/' + id), {
    schemaVersion: 1, organizationId: 'org-1', bookingId: id, memberId: 'member-1', coachId: 'coach-1', branchId: 'branch-1', requestId: id, createdBy: 'member-1', createdAtMillis: now, startAtMillis: start, endAtMillis: start + 3600000, durationMinutes: 60, status: 'confirmed', holdExpiresAtMillis: now + 900000, localDate: '2026-10-02', timeZone: 'Asia/Kuala_Lumpur', policyVersion: 'booking-v1',
  });
  await batch.commit();
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });
it('uses transactional compound queries, deduplicates simultaneous sends and preserves booking records', async () => {
  const before = (await db.doc('orgs/org-1/bookings/pair-booking-1').get()).data();
  const settled = await settleConcurrentEmulatorRequests(Array.from({ length: 4 }, () => sendQuestion));
  const responses = settled.map(result => {
    if (result.status === 'rejected') throw result.reason;
    return result.value;
  });
  expect(responses).toEqual(Array(4).fill(responses[0]));
  await expectSingleQuestion(responses[0].conversationId);
  await call('coach-1', { bookingId: 'pair-booking-2', requestId: 'reply', text: 'Shared reply' });
  const page = await call();
  expect(page.messages.map(m => m.text)).toEqual(['Shared question', 'Shared reply']);
  expect((await db.doc('orgs/org-1/bookings/pair-booking-1').get()).data()).toEqual(before);
  const inbox = await pairConversation(new FirestoreConversationStore(db), auth('coach-1'), { schemaVersion: 2, organizationId: 'org-1', action: 'inbox' }, () => now);
  expect(inbox.conversations).toHaveLength(1);
  expect(inbox.conversations![0].unreadCount).toBe(1);
});
it('replays only the emulator closed-transaction status, once, without duplicating a committed send', async () => {
  const closed = Object.assign(new Error('Closed transaction'), { code: 3, details: 'Transaction is invalid or closed.' });
  const invalid = Object.assign(new Error('Invalid argument'), { code: 3, details: 'Invalid query.' });
  const otherCode = Object.assign(new Error('Unrelated status'), { code: 7, details: closed.details });
  const committed = await sendQuestion();
  const winner = async () => committed;
  const resend = vi.fn(sendQuestion).mockRejectedValueOnce(closed);
  expect((await settleConcurrentEmulatorRequests([winner, resend]))[1])
    .toEqual({ status: 'fulfilled', value: committed });
  expect(resend).toHaveBeenCalledTimes(2);

  for (const error of [invalid, otherCode]) {
    const failed = vi.fn(sendQuestion).mockRejectedValue(error);
    expect((await settleConcurrentEmulatorRequests([winner, failed]))[1])
      .toEqual({ status: 'rejected', reason: error });
    expect(failed).toHaveBeenCalledTimes(1);
  }

  const closedAgain = vi.fn(sendQuestion).mockRejectedValue(closed);
  expect((await settleConcurrentEmulatorRequests([winner, closedAgain]))[1])
    .toEqual({ status: 'rejected', reason: closed });
  expect(closedAgain).toHaveBeenCalledTimes(2);

  const noWinner = vi.fn(sendQuestion).mockRejectedValue(closed);
  expect((await settleConcurrentEmulatorRequests([noWinner, noWinner]))[0])
    .toEqual({ status: 'rejected', reason: closed });
  expect(noWinner).toHaveBeenCalledTimes(2);
  await expectSingleQuestion(committed.conversationId);
});

it('pages equal-timestamp legacy history and never rewrites the source documents', async () => {
  const source = 'orgs/org-1/bookings/pair-booking-1';
  const batch = db.batch(); batch.set(db.doc(source + '/communicationState/current'), { schemaVersion: 1, count: 61 });
  for (let i = 1; i <= 61; i++) batch.set(db.doc(source + '/messages/' + i), { sequence: i, senderRole: 'member', text: 'Legacy ' + i, sentAtMillis: now });
  await batch.commit();
  const page = await call(); const older = await call('member-1', { before: page.nextBefore });
  expect(new Set([...older.messages, ...page.messages].map(m => m.id)).size).toBe(61);
  expect((await db.collection(source + '/messages').get()).size).toBe(61);
});
it('revoked coach branch access denies both reads and writes', async () => {
  await db.doc('orgs/org-1/members/coach-1').update({ branchIds: [] });
  await expect(call('coach-1')).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(call('coach-1', { requestId: 'bad', text: 'Forbidden' })).rejects.toMatchObject({ code: 'permission-denied' });
});
