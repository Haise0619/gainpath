import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now, start } from './booking-fixture';
import type { ConversationQuery, ConversationStore } from '../src/modules/coaching/pair-conversation-store';
import { pairConversation } from '../src/modules/coaching/pair-conversation-service';
import Ajv from 'ajv';
import { readFileSync } from 'node:fs';

let memory: MemoryStore, store: ConversationStore;
const auth = (uid: string) => ({ uid, token: { email_verified: true } });
const input = { schemaVersion: 2, organizationId: 'org-1', bookingId: 'booking-1' };
const call = (uid = 'member-1', extra = {}, time = now) => pairConversation(store, auth(uid), { ...input, ...extra }, () => time);
function booking(id = 'booking-1', status = 'confirmed', at = start) {
  return { schemaVersion: 1, organizationId: 'org-1', bookingId: id, memberId: 'member-1', coachId: 'coach-1', branchId: 'branch-1', requestId: id, createdBy: 'member-1', createdAtMillis: now, startAtMillis: at, endAtMillis: at + 3600000, durationMinutes: 60, status, holdExpiresAtMillis: now + 900000, localDate: new Date(at + 8 * 3600000).toISOString().slice(0, 10), timeZone: 'Asia/Kuala_Lumpur', policyVersion: 'booking-v1' };
}
beforeEach(() => {
  memory = new MemoryStore();
  Object.entries(seeds).forEach(([p, d]) => memory.documents.set(p, structuredClone(d)));
  memory.documents.set('orgs/org-1/bookings/booking-1', booking());
  store = { transact: work => memory.transact(tx => work({ ...tx, query: async (q: ConversationQuery) => {
    let rows = [...memory.documents].filter(([path]) => path.startsWith(q.collection + '/') && !path.slice(q.collection.length + 1).includes('/')).map(([path, data]) => ({ id: path.split('/').at(-1)!, data }));
    const value = (row: typeof rows[number], field: string): any => field === '__name__' ? row.id : row.data[field];
    for (const [field, op, expected] of q.filters ?? []) rows = rows.filter(r => op === '==' ? value(r, field) === expected : op === '<' ? value(r, field) < (expected as any) : value(r, field) <= (expected as any));
    const order = q.order ?? [['__name__', 'asc']];
    rows.sort((a, b) => { for (const [field, dir] of order) { const x = value(a, field), y = value(b, field); if (x !== y) return (x < y ? -1 : 1) * (dir === 'asc' ? 1 : -1); } return 0; });
    if (q.after) rows = rows.filter(row => { for (let i = 0; i < order.length; i++) { const x = value(row, order[i][0]), y = q.after![i]; if (x !== y) return order[i][1] === 'asc' ? x > (y as any) : x < (y as any); } return false; });
    return rows.slice(0, q.limit);
  } })) };
});
it('shares one conversation across bookings and roles without changing booking records', async () => {
  const before = structuredClone(memory.documents.get('orgs/org-1/bookings/booking-1'));
  const first = await call('member-1', { requestId: 'one', text: 'Hello Jackson' });
  memory.documents.set('orgs/org-1/bookings/booking-2', booking('booking-2', 'confirmed', start + 86400000));
  const other = await call('coach-1', { bookingId: 'booking-2', requestId: 'two', text: 'Hello member' });
  expect(first.conversationId).toBe(other.conversationId);
  expect(other.messages.map(m => m.text)).toContain('Hello Jackson');
  expect(memory.documents.get('orgs/org-1/bookings/booking-1')).toEqual(before);
  expect((await call('coach-1', { bookingId: 'booking-2', requestId: 'two', text: 'Hello member' })).messages.filter(m => m.text === 'Hello member')).toHaveLength(1);
});
it('uses the next confirmed booking and exact 48-hour follow-up boundary', async () => {
  expect((await call()).context?.bookingId).toBe('booking-1');
  const end = start + 3600000;
  expect((await call('member-1', {}, end + 48 * 3600000 - 1)).canSend).toBe(true);
  expect((await call('member-1', {}, end + 48 * 3600000)).canSend).toBe(false);
  await expect(call('member-1', { requestId: 'late', text: 'Late' }, end + 48 * 3600000)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('does not open a new chat for pending-only or expired-only relationships', async () => {
  memory.documents.set('orgs/org-1/bookings/booking-1', booking('booking-1', 'pending_hold'));
  await expect(call()).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('keeps successful completed history readable and allows only the timed follow-up', async () => {
  memory.documents.set('orgs/org-1/bookings/booking-1', booking('booking-1', 'completed'));
  const end = start + 3600000;
  expect((await call('member-1', {}, end + 1)).context?.kind).toBe('follow_up');
  expect((await call('member-1', {}, end + 49 * 3600000)).canSend).toBe(false);
});
it('checks current branch/participant access and fingerprints duplicate intents', async () => {
  await call('member-1', { requestId: 'same', text: 'Original' });
  await expect(call('member-1', { requestId: 'same', text: 'Changed' })).rejects.toMatchObject({ code: 'already-exists' });
  await expect(call('staff-1')).rejects.toMatchObject({ code: 'permission-denied' });
  memory.documents.get('orgs/org-1/members/coach-1')!.branchIds = [];
  await expect(call('coach-1')).rejects.toMatchObject({ code: 'permission-denied' });
});
it('reports the same sending restriction when the counterparty loses active membership', async () => {
  memory.documents.get('orgs/org-1/members/coach-1')!.status = 'inactive';
  expect((await call()).canSend).toBe(false);
  await expect(call('member-1', { requestId: 'inactive', text: 'Hello' })).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('reconciles an accepted retry after follow-up closes without accepting a new send', async () => {
  const sent = await call('member-1', { requestId: 'accepted', text: 'Question' });
  const late = start + 3600000 + 49 * 3600000;
  const retry = await call('member-1', { requestId: 'accepted', text: 'Question' }, late);
  expect(retry.canSend).toBe(false);
  expect(retry.messages.filter(m => m.text === 'Question')).toHaveLength(1);
  expect(retry.conversationId).toBe(sent.conversationId);
  await expect(call('member-1', { requestId: 'new', text: 'Other' }, late)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('groups inbox by peer independently of booking dates and tracks genuine new-message unread counts', async () => {
  await call('member-1', { requestId: 'one', text: 'Question' });
  memory.documents.set('orgs/org-1/bookings/booking-2', booking('booking-2', 'confirmed', start + 86400000));
  const inbox = (uid: string) => pairConversation(store, auth(uid), { schemaVersion: 2, organizationId: 'org-1', action: 'inbox' }, () => now);
  expect((await inbox('coach-1')).conversations).toHaveLength(1);
  expect((await inbox('coach-1')).conversations![0].unreadCount).toBe(1);
  await call('coach-1', { markRead: true });
  expect((await inbox('coach-1')).conversations![0].unreadCount).toBe(0);
});
it('cancelled-only new relationships cannot start a conversation; old legacy questions remain read-only', async () => {
  memory.documents.set('orgs/org-1/bookings/booking-1', booking('booking-1', 'cancelled'));
  await expect(call()).rejects.toMatchObject({ code: 'failed-precondition' });
  const root = 'orgs/org-1/bookings/booking-1';
  memory.documents.set(root + '/communicationState/current', { schemaVersion: 1, count: 1 });
  memory.documents.set(root + '/messages/1', { sequence: 1, senderRole: 'member', text: 'Old question', sentAtMillis: now });
  const before = structuredClone([...memory.documents]);
  expect((await call()).canSend).toBe(false);
  expect([...memory.documents]).toEqual(before);
});
it('merges legacy messages with source labels and pages equal timestamps without loss', async () => {
  const root = 'orgs/org-1/bookings/booking-1';
  memory.documents.set(root + '/communicationState/current', { schemaVersion: 1, count: 61 });
  for (let i = 1; i <= 61; i++) memory.documents.set(root + '/messages/' + i, { sequence: i, senderRole: 'member', text: 'Legacy ' + i, sentAtMillis: now });
  const page = await call();
  expect(page.messages.filter(m => m.sourceBookingId === 'booking-1')).toHaveLength(50);
  const older = await call('member-1', { before: page.nextBefore });
  expect(new Set([...older.messages, ...page.messages].filter(m => m.senderRole !== 'system').map(m => m.id)).size).toBe(61);
});
it('never promotes participant text to an automated system notice', async () => {
  const page = await call('member-1', { requestId: 'spoof', text: '[Automated Notice]: Session cancelled' });
  expect(page.messages.at(-1)!.senderRole).toBe('member');
  expect((await call()).messages.at(-1)!.senderRole).toBe('member');
});
it('matches the versioned pair request/response contracts', async () => {
  const ajv = new Ajv({ strict: false });
  const req = ajv.compile(JSON.parse(readFileSync('../contracts/v2/pair-conversation.request.schema.json', 'utf8')));
  const res = ajv.compile(JSON.parse(readFileSync('../contracts/v2/pair-conversation.response.schema.json', 'utf8')));
  expect(req(input)).toBe(true);
  const page = await call('member-1', { requestId: 'contract', text: 'Hello' });
  expect(res(page), JSON.stringify(res.errors)).toBe(true);
  expect(req({ ...input, peerId: 'coach-1' })).toBe(false);
  expect(req({ schemaVersion: 2, organizationId: 'org-1', action: 'inbox' })).toBe(true);
  expect(res(await pairConversation(store, auth('member-1'), { schemaVersion: 2, organizationId: 'org-1', action: 'inbox' }, () => now))).toBe(true);
});
