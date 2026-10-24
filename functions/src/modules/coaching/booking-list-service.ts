import { readAll } from '../../platform/firestore/store';
import { prefetchReads } from '../../platform/firestore/prefetch-reads';
import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { allowed, dateEpoch, dateGrid, integer, localDate, object, plusDate, SLOT } from './coach-availability-contracts';
import { storedBooking, type BookingResolution } from './booking-record';
import { currentBookingMembership, currentBookingPolicy, requireBookingOrganization } from './booking-validation';
export interface BookingCursor { startAtMillis: number; bookingId: string }
export interface BookingQuery { organizationId: string; ownerField: 'memberId' | 'coachId'; ownerId: string; branchIds?: readonly string[]; firstStartAtMillis: number; throughStartAtMillis: number; cursor?: BookingCursor; limit: 21 }
export interface BookingQueryReader { read(query: BookingQuery): Promise<{ path: string; data: DocumentData }[]> }
export interface PersistedBookingRecord {
  schemaVersion: 1; bookingId: string; organizationId: string; memberId: string; coachId: string; branchId: string; requestId: string;
  startAtMillis: number; endAtMillis: number; durationMinutes: 30 | 60; status: 'pending_hold' | 'confirmed' | 'cancelled' | 'expired' | 'completed' | 'refunded';
  holdExpiresAtMillis: number; localDate: string; timeZone: string; policyVersion: string; createdAtMillis: number;
  resolvedAtMillis?: number; resolution?: BookingResolution;
  startLabel: string; endLabel: string; expiryLabel: string;
  memberDisplayName?: string;
  cancellationReason?: string;
  cancelledBy?: string;
  feeMinor?: number;
  reviewStars?: number;
}
export interface BookingPage { schemaVersion: 1; serverNowMillis: number; timeZone: string; firstLocalDate: string; throughLocalDate: string; records: PersistedBookingRecord[]; nextCursor?: BookingCursor }
const review = () => new DomainError('failed-precondition', 'Stored bookings need authorized review.');
function after(a: BookingCursor, b: BookingCursor) { return a.startAtMillis > b.startAtMillis || (a.startAtMillis === b.startAtMillis && a.bookingId > b.bookingId); }
function project(row: { path: string; data: DocumentData }, q: BookingQuery, includeCancellationDetails = false, includeMemberChangeDetails = false): PersistedBookingRecord {
  try {
    const d = storedBooking(row.data, q.organizationId, String(row.data.bookingId));
    if (row.path !== `orgs/${q.organizationId}/bookings/${d.bookingId}` || d[q.ownerField] !== q.ownerId
      || (q.branchIds && !q.branchIds.includes(d.branchId)) || d.startAtMillis < q.firstStartAtMillis || d.startAtMillis >= q.throughStartAtMillis) throw review();
    const formatter = new Intl.DateTimeFormat('en-GB', { timeZone: d.timeZone, hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZoneName: 'shortOffset' });
    const { createdBy: _private, ...publicData } = d;
    if (d.status === 'cancelled' && ((d.resolution === 'coach_cancelled' && !includeCancellationDetails)
      || (d.resolution === 'member_confirmed_cancelled' && !includeMemberChangeDetails))) {
      delete (publicData as any).resolution;
      delete (publicData as any).resolvedAtMillis;
      delete (publicData as any).cancellationReason;
      delete (publicData as any).cancelledBy;
    }
    return { ...publicData, startLabel: formatter.format(Number(d.startAtMillis)), endLabel: formatter.format(Number(d.endAtMillis)),
      expiryLabel: `${localDate(Number(d.holdExpiresAtMillis), d.timeZone)} ${formatter.format(Number(d.holdExpiresAtMillis))}` } as unknown as PersistedBookingRecord;
  } catch { throw review(); }
}
export async function getBookingListService(store: DocumentStore, auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, reader: BookingQueryReader, clock = Date.now): Promise<BookingPage> {
  requireVerifiedEmail(auth);
  const input = object(raw); allowed(input, ['schemaVersion', 'organizationId', 'coachId', 'firstLocalDate', 'dayCount', 'cursor', 'includeParticipantNames', 'includeCancellationDetails', 'includeReviewDetails', 'includeMemberChangeDetails']);
  if (input.includeMemberChangeDetails !== undefined && typeof input.includeMemberChangeDetails !== 'boolean') throw new InputValidationError('includeMemberChangeDetails must be a boolean.');
  if (input.includeReviewDetails !== undefined && typeof input.includeReviewDetails !== 'boolean') throw new InputValidationError('includeReviewDetails must be a boolean.');
  if (input.includeParticipantNames !== undefined && typeof input.includeParticipantNames !== 'boolean') throw new InputValidationError('includeParticipantNames must be a boolean.');
  if (input.includeCancellationDetails !== undefined && typeof input.includeCancellationDetails !== 'boolean') throw new InputValidationError('includeCancellationDetails must be a boolean.');
  if (input.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(input.organizationId, 'organizationId'), uid = requiredIdentifier(auth!.uid, 'actorId');
  const selectedCoach = input.coachId === undefined ? undefined : requiredIdentifier(input.coachId, 'coachId');
  if (input.firstLocalDate !== undefined) dateEpoch(input.firstLocalDate);
  const dayCount = input.dayCount === undefined ? 31 : integer(input.dayCount, 1, 31);
  let cursor: BookingCursor | undefined;
  if (input.cursor !== undefined) {
    const c = object(input.cursor); allowed(c, ['startAtMillis', 'bookingId']);
    cursor = { startAtMillis: integer(c.startAtMillis, 1), bookingId: requiredIdentifier(c.bookingId, 'bookingId') };
    if (cursor.startAtMillis % SLOT) throw new InputValidationError('Cursor must use the UTC time grid.');
  }
  const serverNowMillis = integer(clock(), 1);
  const scope = async (tx: TransactionPort) => {
    const facts = await prefetchReads(tx, [
      `users/${uid}`, `orgs/${org}/members/${uid}`, `orgs/${org}`, `orgs/${org}/settings/booking`,
    ]);
    const actor = await currentBookingMembership(facts, org, uid);
    await requireBookingOrganization(facts, org);
    const policy = currentBookingPolicy(await facts.get(`orgs/${org}/settings/booking`));
    let ownerField: 'memberId' | 'coachId', ownerId: string, activeBranches: string[] | undefined;
    if (actor.role === 'member') { ownerField = 'memberId'; ownerId = uid; if (selectedCoach !== undefined) throw new DomainError('permission-denied', 'Member scope uses the authenticated owner.'); }
    else if (actor.role === 'coach') {
      ownerField = 'coachId'; ownerId = uid;
      if (selectedCoach !== undefined && selectedCoach !== uid) throw new DomainError('permission-denied', 'Coach scope uses the authenticated owner.');
      const branches = await readAll(tx, actor.branchIds.map(b => `orgs/${org}/branches/${b}`));
      activeBranches = actor.branchIds.filter((_b, i) => branches[i]?.status === 'active');
    } else if (actor.role === 'admin' && selectedCoach !== undefined) { ownerField = 'coachId'; ownerId = selectedCoach; }
    else throw new DomainError('permission-denied', 'A supported booking owner or selected Admin Coach is required.');
    return { role: actor.role, assignments: actor.branchIds, policy, ownerField, ownerId, activeBranches };
  };
  const before = await store.transact(scope), today = localDate(serverNowMillis, before.policy.timeZone), horizon = plusDate(today, 30);
  const firstLocalDate = input.firstLocalDate === undefined ? today : input.firstLocalDate as string;
  if (firstLocalDate < plusDate(today, -90) || firstLocalDate > horizon) throw new InputValidationError('Choose the past 90 days through 30 days ahead.');
  const throughLocalDate = [plusDate(firstLocalDate, dayCount - 1), horizon].sort()[0];
  const firstStartAtMillis = dateGrid(firstLocalDate, before.policy.timeZone).slots[0], lastGrid = dateGrid(throughLocalDate, before.policy.timeZone);
  const throughStartAtMillis = lastGrid.slots.at(-1)! + SLOT;
  if (cursor && (cursor.startAtMillis < firstStartAtMillis || cursor.startAtMillis >= throughStartAtMillis)) throw new InputValidationError('Cursor is outside the requested range.');
  const q: BookingQuery = { organizationId: org, ownerField: before.ownerField, ownerId: before.ownerId, ...(before.activeBranches === undefined ? {} : { branchIds: before.activeBranches }), firstStartAtMillis, throughStartAtMillis, ...(cursor ? { cursor } : {}), limit: 21 };
  const rows = before.activeBranches?.length === 0 ? [] : await reader.read(q);
  const current = await store.transact(scope);
  if (JSON.stringify(before) !== JSON.stringify(current)) throw new DomainError('permission-denied', 'Booking access changed. Refresh the current account scope.');
  if (!Array.isArray(rows) || rows.length > 21) throw review();
  const includeCancellationDetails = input.includeCancellationDetails === true;
  const projected = rows.map(r => project(r, q, includeCancellationDetails, input.includeMemberChangeDetails === true));
  const ids = new Set<string>();
  let previous = cursor;
  for (const r of projected) {
    if (ids.has(r.bookingId) || (previous && !after(r, previous))) throw review();
    ids.add(r.bookingId); previous = r;
  }
  const records = projected.slice(0, 20), last = records.at(-1);
  // Related names and transaction fees; private contact/account fields never enter the projection.
  await store.transact(async tx => {
    if (JSON.stringify(before) !== JSON.stringify(await scope(tx))) throw new DomainError('permission-denied', 'Booking access changed. Refresh the current account scope.');
    const memberIds = input.includeParticipantNames === true ? [...new Set(records.map(r => r.memberId))] : [];
    const paths = [...memberIds.map(id => `orgs/${org}/members/${id}`),
      ...records.map(r => `orgs/${org}/transactions/${r.bookingId}`),
      ...(input.includeReviewDetails === true ? records.map(r => `orgs/${org}/bookings/${r.bookingId}/review/current`) : [])];
    const values = await readAll(tx, paths);
    const members = new Map(memberIds.map((id, i) => [id, values[i]]));
    records.forEach((record, i) => {
      const member = members.get(record.memberId);
      const name = member?.organizationId === org ? member.displayName : undefined;
      if (typeof name === 'string' && name.trim() && name.trim().length <= 120) record.memberDisplayName = name.trim();
      const payment = values[memberIds.length + i];
      if (payment && Number.isSafeInteger(payment.amountMinor) && Number(payment.amountMinor) >= 0) record.feeMinor = Number(payment.amountMinor);
      const saved = input.includeReviewDetails === true ? values[memberIds.length + records.length + i] : undefined;
      if (saved?.schemaVersion === 1 && saved.bookingId === record.bookingId && saved.coachId === record.coachId && saved.memberId === record.memberId
          && Number.isInteger(saved.stars) && Number(saved.stars) >= 1 && Number(saved.stars) <= 5) record.reviewStars = Number(saved.stars);
    });
  });
  return { schemaVersion: 1, serverNowMillis, timeZone: before.policy.timeZone, firstLocalDate, throughLocalDate, records,
    ...(projected.length > 20 && last ? { nextCursor: { startAtMillis: last.startAtMillis, bookingId: last.bookingId } } : {}) };
}
