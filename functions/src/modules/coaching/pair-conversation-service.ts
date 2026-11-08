import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { requiredIdentifier, InputValidationError } from '../../platform/validation';
import { keyOf } from '../../platform/idempotency';
import { allowed, integer, object } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { storedBooking, type StoredBooking } from './booking-record';
import type { ConversationStore, ConversationTransaction } from './pair-conversation-store';

const FOLLOW_UP = 48 * 3600000;
const PAGE = 50;
const pairRoot = (org: string, member: string, coach: string) => `orgs/${org}/coachingConversations/${keyOf('memberCoach', member, coach)}`;
export interface ConversationContext {
  bookingId: string; kind: 'current' | 'next' | 'follow_up'; startAtMillis: number; endAtMillis: number;
  timeZone: string; durationMinutes: number; status: string; followUpUntilMillis?: number; dateLabel: string; followUpLabel?: string;
}
export interface PairMessage { id: string; orderKey: string; senderRole: 'member' | 'coach' | 'system'; text: string; sentAtMillis: number; sourceBookingId?: string; sourceBookingLabel?: string }
interface Cursor { at: number; source: string; doc: string }
export interface PairSummary { peerId: string; name: string; conversationId: string; preview?: string; updatedAtMillis?: number; unreadCount: number }
export interface PairResponse {
  schemaVersion: 2; conversationId: string; memberId: string; coachId: string; peerName: string; serverNowMillis: number;
  canSend: boolean; reason: string; context?: ConversationContext; messages: PairMessage[]; unreadCount: number;
  nextBefore?: string; conversations?: PairSummary[]; nextInboxCursor?: string;
}
function policy(bookings: StoredBooking[], now: number) {
  const confirmed = bookings.filter(b => b.status === 'confirmed');
  const current = confirmed.filter(b => b.startAtMillis <= now && b.endAtMillis > now).sort((a, b) => a.endAtMillis - b.endAtMillis)[0];
  const next = confirmed.filter(b => b.startAtMillis > now).sort((a, b) => a.startAtMillis - b.startAtMillis)[0];
  const recent = bookings.filter(b => ['confirmed', 'completed'].includes(b.status) && b.endAtMillis <= now)
    .sort((a, b) => b.endAtMillis - a.endAtMillis)[0];
  const b = current ?? next ?? recent;
  const kind = current ? 'current' : next ? 'next' : 'follow_up';
  const until = recent ? recent.endAtMillis + FOLLOW_UP : undefined;
  const canSend = !!(current || next || (until && now < until));
  const context: ConversationContext | undefined = b && (kind !== 'follow_up' || canSend)
    ? { bookingId: b.bookingId, kind, startAtMillis: b.startAtMillis, endAtMillis: b.endAtMillis, timeZone: b.timeZone,
      durationMinutes: b.durationMinutes, status: b.status,
      dateLabel: new Intl.DateTimeFormat('en-GB', { timeZone: b.timeZone, day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', timeZoneName: 'shortOffset', hourCycle: 'h23' }).format(b.startAtMillis),
      ...(kind === 'follow_up' ? { followUpUntilMillis: until, followUpLabel: new Intl.DateTimeFormat('en-GB', { timeZone: b.timeZone, day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZoneName: 'shortOffset', hourCycle: 'h23' }).format(until) } : {}) } : undefined;
  return { canSend, context, reason: canSend ? (kind === 'follow_up' ? 'Follow-up available for 48 hours after your session.' : 'Chat about your confirmed sessions.') : 'This conversation is read-only. Book another session to continue chatting.' };
}
function name(value: unknown, fallback: string) { return typeof value === 'string' && value.trim() && value.trim().length <= 120 ? value.trim() : fallback; }
function cursor(raw: unknown): Cursor | undefined {
  if (raw === undefined) return undefined;
  try {
    if (typeof raw !== 'string' || raw.length > 1800) throw Error();
    const c = JSON.parse(Buffer.from(raw, 'base64url').toString());
    if (!Number.isSafeInteger(c.at) || c.at < 1 || typeof c.source !== 'string' || c.source.length > 600 || typeof c.doc !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(c.doc)) throw Error();
    return c;
  } catch { throw new InputValidationError('Invalid message cursor.'); }
}
async function pairBookings(tx: ConversationTransaction, org: string, member: string, coach: string, branches?: string[]) {
  const rows = await tx.query({ collection: `orgs/${org}/bookings`, filters: [['memberId', '==', member], ['coachId', '==', coach]], limit: 101 });
  if (rows.length > 100) throw new DomainError('resource-exhausted', 'This conversation needs a larger history index. Contact support.');
  return rows.map(r => {
    const b = storedBooking(r.data, org, r.id);
    if (b.memberId !== member || b.coachId !== coach) throw new DomainError('permission-denied', 'Conversation scope changed.');
    return b;
  }).filter(b => !branches || branches.includes(b.branchId));
}
async function activeBranches(tx: ConversationTransaction, org: string, ids: readonly string[]) {
  const active = await Promise.all(ids.map(async id => (await tx.get(`orgs/${org}/branches/${id}`))?.status === 'active' ? id : null));
  return active.filter((id): id is string => id !== null);
}
export async function pairConversation(store: ConversationStore, auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, clock = Date.now): Promise<PairResponse> {
  requireVerifiedEmail(auth);
  const input = object(raw);
  allowed(input, ['schemaVersion', 'organizationId', 'bookingId', 'peerId', 'action', 'requestId', 'text', 'before', 'inboxCursor', 'markRead']);
  if (input.schemaVersion !== 2) throw new InputValidationError('schemaVersion 2 is required.');
  const org = requiredIdentifier(input.organizationId, 'organizationId'), uid = requiredIdentifier(auth!.uid, 'actorId');
  const action = input.action ?? 'thread';
  if (!['thread', 'inbox'].includes(String(action))) throw new InputValidationError('Unsupported conversation action.');
  if (input.markRead !== undefined && typeof input.markRead !== 'boolean') throw new InputValidationError('markRead must be boolean.');
  const sending = input.text !== undefined || input.requestId !== undefined;
  const request = sending ? requiredIdentifier(input.requestId, 'requestId') : undefined;
  const text = typeof input.text === 'string' ? input.text.trim() : '';
  if (sending && (!text || text.length > 500 || input.before !== undefined || action !== 'thread')) throw new InputValidationError('Enter a message of 1–500 characters.');
  const before = cursor(input.before);
  const now = integer(clock(), 1);
  return store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, uid);
    await requireBookingOrganization(tx, org);
    if (!['member', 'coach'].includes(actor.role)) throw new DomainError('permission-denied', 'Only consultation participants can access conversations.');
    const branches = actor.role === 'coach' ? await activeBranches(tx, org, actor.branchIds) : undefined;
    const empty: PairResponse = { schemaVersion: 2, conversationId: '', memberId: '', coachId: '', peerName: '', serverNowMillis: now, canSend: false, reason: '', messages: [], unreadCount: 0 };
    if (action === 'inbox') {
      if (sending || input.bookingId !== undefined || input.peerId !== undefined || before) throw new InputValidationError('Invalid inbox request.');
      const after = input.inboxCursor === undefined ? undefined : requiredIdentifier(input.inboxCursor, 'inboxCursor');
      const rows = await tx.query({ collection: `orgs/${org}/bookings`, filters: [[actor.role === 'member' ? 'memberId' : 'coachId', '==', uid]], order: [['__name__', 'asc']], ...(after ? { after: [after] } : {}), limit: 51 });
      const peers = new Map<string, PairSummary>();
      for (const row of rows.slice(0, 50)) {
        const b = storedBooking(row.data, org, row.id);
        if (b[actor.role === 'member' ? 'memberId' : 'coachId'] !== uid) throw new DomainError('permission-denied', 'Inbox scope changed.');
        if (branches && !branches.includes(b.branchId)) continue;
        const peer = actor.role === 'member' ? b.coachId : b.memberId;
        if (peers.has(peer)) continue;
        const root = pairRoot(org, b.memberId, b.coachId), state = await tx.get(root);
        const legacy = await tx.get(`orgs/${org}/bookings/${b.bookingId}/communicationState/current`);
        if (!['confirmed', 'completed'].includes(b.status) && !state?.count && !legacy?.count) continue;
        const person = actor.role === 'member' ? await tx.get(`orgs/${org}/coaches/${peer}`) : await tx.get(`orgs/${org}/members/${peer}`);
        const unread = Math.max(0, Number(state?.[actor.role === 'member' ? 'coachSent' : 'memberSent'] ?? 0) - Number(state?.[actor.role === 'member' ? 'memberRead' : 'coachRead'] ?? 0));
        peers.set(peer, { peerId: peer, name: name(person?.displayName ?? (person?.fields as any)?.displayName, actor.role === 'member' ? 'Coach' : 'Member'), conversationId: root.split('/').at(-1)!, unreadCount: unread,
          ...(typeof state?.preview === 'string' ? { preview: state.preview, updatedAtMillis: Number(state.updatedAtMillis) } : {}) });
      }
      return { ...empty, conversations: [...peers.values()], ...(rows.length > 50 ? { nextInboxCursor: rows[49].id } : {}) };
    }
    let member: string, coach: string;
    if (input.bookingId !== undefined) {
      if (input.peerId !== undefined) throw new InputValidationError('Choose bookingId or peerId.');
      const id = requiredIdentifier(input.bookingId, 'bookingId');
      const b = storedBooking(await tx.get(`orgs/${org}/bookings/${id}`), org, id);
      if ((actor.role === 'member' ? b.memberId : b.coachId) !== uid || (branches && !branches.includes(b.branchId))) throw new DomainError('permission-denied', 'Only this booking’s participants may access messages.');
      member = b.memberId; coach = b.coachId;
    } else {
      const peer = requiredIdentifier(input.peerId, 'peerId');
      member = actor.role === 'member' ? uid : peer; coach = actor.role === 'coach' ? uid : peer;
    }
    const bookings = await pairBookings(tx, org, member, coach, branches);
    if (!bookings.length) throw new DomainError('permission-denied', 'No authorized consultation relationship.');
    const root = pairRoot(org, member, coach), state = await tx.get(root);
    if (state && (state.schemaVersion !== 2 || state.memberId !== member || state.coachId !== coach)) throw new DomainError('failed-precondition', 'Conversation requires review.');
    const sources = [{ source: root + '/messages', booking: undefined as string | undefined, label: undefined as string | undefined }];
    for (const b of bookings) {
      const legacy = await tx.get(`orgs/${org}/bookings/${b.bookingId}/communicationState/current`);
      if (legacy?.count) sources.push({ source: `orgs/${org}/bookings/${b.bookingId}/messages`, booking: b.bookingId, label: new Intl.DateTimeFormat('en-GB', { timeZone: b.timeZone, day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(b.startAtMillis) });
    }
    if (!state?.count && sources.length === 1 && !bookings.some(b => ['confirmed', 'completed'].includes(b.status))) throw new DomainError('failed-precondition', 'Confirm a session before starting a conversation.');
    const peer = actor.role === 'member' ? coach : member;
    let access = policy(bookings, now);
    try {
      const other = await currentBookingMembership(tx, org, peer);
      if (other.role !== (actor.role === 'member' ? 'coach' : 'member')) throw new DomainError('permission-denied', 'Counterparty unavailable.');
      if (actor.role === 'member') {
        const coachBranches = await activeBranches(tx, org, other.branchIds);
        access = policy(bookings.filter(b => coachBranches.includes(b.branchId)), now);
      }
    } catch (error) {
      if (!(error instanceof DomainError) || error.code !== 'permission-denied') throw error;
      access = { canSend: false, context: undefined, reason: 'This conversation is read-only. The other participant is currently unavailable for messaging.' };
    }
    const person = actor.role === 'member' ? await tx.get(`orgs/${org}/coaches/${peer}`) : await tx.get(`orgs/${org}/members/${peer}`);
    const peerName = name(person?.displayName ?? (person?.fields as any)?.displayName, actor.role === 'member' ? 'Coach' : 'Member');
    const receiptPath = `${root}/receipts/${keyOf(uid, request ?? 'read')}`;
    const receipt = sending ? await tx.get(receiptPath) : undefined;
    const fingerprint = keyOf(org, member, coach, text);
    if (receipt && receipt.fingerprint !== fingerprint) throw new DomainError('already-exists', 'Request already used for another message.');
    if (sending && !receipt && !access.canSend) throw new DomainError('failed-precondition', access.reason);
    const candidates: { message: PairMessage; cursor: Cursor }[] = [];
    for (const source of sources) {
      const same = before?.source === source.source;
      const less = before && source.source < before.source;
      const rows = await tx.query({ collection: source.source,
        ...(before ? { filters: [['sentAtMillis', same || less ? '<=' : '<', before.at]] } : {}),
        order: [['sentAtMillis', 'desc'], ['__name__', 'desc']], ...(same ? { after: [before!.at, before!.doc] } : {}), limit: PAGE + 1 });
      for (const row of rows) {
        const m = row.data;
        if (!['member', 'coach'].includes(String(m.senderRole)) || typeof m.text !== 'string' || !m.text.trim() || m.text.length > 500 || !Number.isSafeInteger(m.sentAtMillis)) throw new DomainError('failed-precondition', 'Message history requires review.');
        candidates.push({ message: { id: keyOf(source.source, row.id), orderKey: source.source + '/' + row.id, senderRole: source.booking && m.schemaVersion === 1 && m.senderRole === 'coach' && m.text.startsWith('[Automated Notice]: Session cancelled by coach.') ? 'system' : m.senderRole as 'member' | 'coach', text: m.text, sentAtMillis: Number(m.sentAtMillis), ...(source.booking ? { sourceBookingId: source.booking, sourceBookingLabel: source.label } : {}) }, cursor: { at: Number(m.sentAtMillis), source: source.source, doc: row.id } });
      }
    }
    candidates.sort((a, b) => b.cursor.at - a.cursor.at || (a.cursor.source === b.cursor.source ? (a.cursor.doc === b.cursor.doc ? 0 : a.cursor.doc < b.cursor.doc ? 1 : -1) : a.cursor.source < b.cursor.source ? 1 : -1));
    const selected = candidates.slice(0, PAGE);
    const messages = selected.map(x => x.message).reverse();
    const count = integer(state?.count ?? 0, 0, 1000000);
    const next = { schemaVersion: 2, memberId: member, coachId: coach, count, memberSent: Number(state?.memberSent ?? 0), coachSent: Number(state?.coachSent ?? 0), memberRead: Number(state?.memberRead ?? 0), coachRead: Number(state?.coachRead ?? 0), ...state };
    if (sending && !receipt) {
      if (count >= 1000000) throw new DomainError('resource-exhausted', 'Message limit reached.');
      const id = String(count + 1).padStart(10, '0');
      const message = { senderRole: actor.role as 'member' | 'coach', text, sentAtMillis: now };
      tx.create(`${root}/messages/${id}`, message);
      tx.create(receiptPath, { fingerprint, messageId: id, createdAtMillis: now });
      next.count = count + 1;
      if (actor.role === 'member') next.memberSent++; else next.coachSent++;
      Object.assign(next, { preview: text, updatedAtMillis: now });
      messages.push({ ...message, id: keyOf(root + '/messages', id), orderKey: root + '/messages/' + id });
    }
    if (input.markRead === true && !before) {
      if (actor.role === 'member') next.memberRead = next.coachSent; else next.coachRead = next.memberSent;
    }
    if ((sending && !receipt) || (input.markRead === true && !before && state && (next.memberRead !== state.memberRead || next.coachRead !== state.coachRead))) tx.set(root, next);
    return { schemaVersion: 2, conversationId: root.split('/').at(-1)!, memberId: member, coachId: coach, peerName, serverNowMillis: now, ...access, messages, unreadCount: Math.max(0, actor.role === 'member' ? next.coachSent - next.memberRead : next.memberSent - next.coachRead),
      ...(candidates.length > PAGE ? { nextBefore: Buffer.from(JSON.stringify(selected.at(-1)!.cursor)).toString('base64url') } : {}) };
  });
}
