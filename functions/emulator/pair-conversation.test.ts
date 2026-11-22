import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it, vi } from 'vitest';
import { FirestoreConversationStore } from '../src/modules/coaching/pair-conversation-store';
import { pairConversation, type PairResponse } from '../src/modules/coaching/pair-conversation-service';
import { seeds, now, start } from '../test/booking-fixture';

let app: App, db: Firestore;
const input = { schemaVersion: 2, organizationId: 'org-1', bookingId: 'pair-booking-1' };
const auth = (uid: string) => ({ uid, token: { email_verified: true } });
const call = (uid = 'member-1', fields = {}, time = now) => pairConversation(new FirestoreConversationStore(db), auth(uid), { ...input, ...fields }, () => time);
const sendQuestion = () => call('member-1', { requestId: 'same', text: 'Shared question' });

async function completeDuplicateSends(
  attempts: readonly PromiseSettledResult<PairResponse>[],
  resend: () => Promise<PairResponse>,
): Promise<PairResponse[]> {
  const responses: PairResponse[] = [];
  for (const attempt of attempts) {
    if (attempt.status === 'fulfilled') {
      responses.push(attempt.value);
      continue;
    }
    const error: unknown = attempt.reason;
    // The emulator may close a contending transaction before the SDK re-sends
    // its read (googleapis/google-cloud-node#9693). Replay the same request once
    // here, after all concurrent attempts have settled.
    if (!(error instanceof Error) || !('code' in error) || error.code !== 3 ||
        !('details' in error) || error.details !== 'Transaction is invalid or closed.') {
      throw error;
    }
    responses.push(await resend());
  }
  return responses;
}

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
  const attempts = await Promise.allSettled(Array.from({ length: 4 }, sendQuestion));
  expect(attempts.some(attempt => attempt.status === 'fulfilled')).toBe(true);
  const responses = await completeDuplicateSends(attempts, sendQuestion);
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
  const resend = vi.fn(sendQuestion);

  await expect(completeDuplicateSends([{ status: 'rejected', reason: closed }], resend)).resolves.toEqual([committed]);
  await expect(completeDuplicateSends([{ status: 'rejected', reason: invalid }], resend)).rejects.toBe(invalid);
  await expect(completeDuplicateSends([{ status: 'rejected', reason: otherCode }], resend)).rejects.toBe(otherCode);
  expect(resend).toHaveBeenCalledTimes(1);

  resend.mockRejectedValueOnce(closed);
  await expect(completeDuplicateSends([{ status: 'rejected', reason: closed }], resend)).rejects.toBe(closed);
  expect(resend).toHaveBeenCalledTimes(2);
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
