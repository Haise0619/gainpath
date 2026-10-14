import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { allowed, dateEpoch, dateGrid, integer, localDate, object, plusDate, SLOT } from './coach-availability-contracts';
import { currentBookingMembership, currentBookingPolicy, requireBookingOrganization, validBookingId, validBookingTime } from './booking-validation';
export interface BookingCursor { startAtMillis: number; bookingId: string }
export interface BookingQuery { organizationId: string; ownerField: 'memberId' | 'coachId'; ownerId: string; branchIds?: readonly string[]; firstStartAtMillis: number; throughStartAtMillis: number; cursor?: BookingCursor; limit: 21 }
export interface BookingQueryReader { read(query: BookingQuery): Promise<{ path: string; data: DocumentData }[]> }
export interface PersistedBookingRecord {
  schemaVersion: 1; bookingId: string; organizationId: string; memberId: string; coachId: string; branchId: string; requestId: string;
  startAtMillis: number; endAtMillis: number; durationMinutes: 30 | 60; status: 'pending_hold' | 'confirmed' | 'cancelled' | 'completed' | 'refunded';
  holdExpiresAtMillis: number; localDate: string; timeZone: string; policyVersion: string; createdAtMillis: number;
  startLabel: string; endLabel: string; expiryLabel: string;
}
export interface BookingPage { schemaVersion: 1; serverNowMillis: number; timeZone: string; firstLocalDate: string; throughLocalDate: string; records: PersistedBookingRecord[]; nextCursor?: BookingCursor }
const storedFields = ['schemaVersion', 'bookingId', 'organizationId', 'memberId', 'coachId', 'branchId', 'requestId', 'startAtMillis', 'endAtMillis', 'durationMinutes', 'status', 'holdExpiresAtMillis', 'localDate', 'timeZone', 'policyVersion', 'createdAtMillis', 'createdBy'] as const;
const review = () => new DomainError('failed-precondition', 'Stored bookings need authorized review.');
function after(a: BookingCursor, b: BookingCursor) { return a.startAtMillis > b.startAtMillis || (a.startAtMillis === b.startAtMillis && a.bookingId > b.bookingId); }
function project(row: { path: string; data: DocumentData }, q: BookingQuery): PersistedBookingRecord {
  const d = row.data;
  try {
    allowed(d, storedFields);
    if (d.schemaVersion !== 1 || !validBookingId(d.bookingId) || row.path !== `orgs/${q.organizationId}/bookings/${d.bookingId}` || d.organizationId !== q.organizationId
      || d[q.ownerField] !== q.ownerId || (q.branchIds && !q.branchIds.includes(String(d.branchId)))
      || !['organizationId', 'memberId', 'coachId', 'branchId', 'requestId', 'createdBy'].every(k => validBookingId(d[k]))
      || !['startAtMillis', 'endAtMillis', 'holdExpiresAtMillis', 'createdAtMillis'].every(k => validBookingTime(d[k]))
      || (d.durationMinutes !== 30 && d.durationMinutes !== 60)
      || Number(d.startAtMillis) % SLOT || Number(d.endAtMillis) - Number(d.startAtMillis) !== Number(d.durationMinutes) * 60000
      || Number(d.createdAtMillis) > Number(d.holdExpiresAtMillis) || Number(d.holdExpiresAtMillis) > Number(d.startAtMillis)
      || Number(d.startAtMillis) < q.firstStartAtMillis || Number(d.startAtMillis) >= q.throughStartAtMillis
      || typeof d.status !== 'string' || !['pending_hold', 'confirmed', 'cancelled', 'completed', 'refunded'].includes(d.status)
      || typeof d.timeZone !== 'string' || !d.timeZone || d.timeZone.length > 100
      || typeof d.policyVersion !== 'string' || !d.policyVersion.trim() || d.policyVersion.length > 128) throw review();
    dateEpoch(d.localDate);
    if (localDate(Number(d.startAtMillis), d.timeZone) !== d.localDate || localDate(Number(d.endAtMillis) - 1, d.timeZone) !== d.localDate) throw review();
    const formatter = new Intl.DateTimeFormat('en-GB', { timeZone: d.timeZone, hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZoneName: 'shortOffset' });
    const { createdBy: _private, ...publicData } = d;
    return { ...publicData, startLabel: formatter.format(Number(d.startAtMillis)), endLabel: formatter.format(Number(d.endAtMillis)),
      expiryLabel: `${localDate(Number(d.holdExpiresAtMillis), d.timeZone)} ${formatter.format(Number(d.holdExpiresAtMillis))}` } as unknown as PersistedBookingRecord;
  } catch { throw review(); }
}
export async function getBookingListService(store: DocumentStore, auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, reader: BookingQueryReader, clock = Date.now): Promise<BookingPage> {
  requireVerifiedEmail(auth);
  const input = object(raw); allowed(input, ['schemaVersion', 'organizationId', 'coachId', 'firstLocalDate', 'dayCount', 'cursor']);
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
    const actor = await currentBookingMembership(tx, org, uid);
    await requireBookingOrganization(tx, org);
    const policy = currentBookingPolicy(await tx.get(`orgs/${org}/settings/booking`));
    let ownerField: 'memberId' | 'coachId', ownerId: string, activeBranches: string[] | undefined;
    if (actor.role === 'member') { ownerField = 'memberId'; ownerId = uid; if (selectedCoach !== undefined) throw new DomainError('permission-denied', 'Member scope uses the authenticated owner.'); }
    else if (actor.role === 'coach') {
      ownerField = 'coachId'; ownerId = uid;
      if (selectedCoach !== undefined && selectedCoach !== uid) throw new DomainError('permission-denied', 'Coach scope uses the authenticated owner.');
      activeBranches = [];
      for (const b of actor.branchIds) if ((await tx.get(`orgs/${org}/branches/${b}`))?.status === 'active') activeBranches.push(b);
    } else if (actor.role === 'admin' && selectedCoach !== undefined) { ownerField = 'coachId'; ownerId = selectedCoach; }
    else throw new DomainError('permission-denied', 'A supported booking owner or selected Admin Coach is required.');
    return { role: actor.role, assignments: actor.branchIds, policy, ownerField, ownerId, activeBranches };
  };
  const before = await store.transact(scope), today = localDate(serverNowMillis, before.policy.timeZone), horizon = plusDate(today, 30);
  const firstLocalDate = input.firstLocalDate === undefined ? today : input.firstLocalDate as string;
  if (firstLocalDate < today || firstLocalDate > horizon) throw new InputValidationError('Choose today through 30 days ahead.');
  const throughLocalDate = [plusDate(firstLocalDate, dayCount - 1), horizon].sort()[0];
  const firstStartAtMillis = dateGrid(firstLocalDate, before.policy.timeZone).slots[0], lastGrid = dateGrid(throughLocalDate, before.policy.timeZone);
  const throughStartAtMillis = lastGrid.slots.at(-1)! + SLOT;
  if (cursor && (cursor.startAtMillis < firstStartAtMillis || cursor.startAtMillis >= throughStartAtMillis)) throw new InputValidationError('Cursor is outside the requested range.');
  const q: BookingQuery = { organizationId: org, ownerField: before.ownerField, ownerId: before.ownerId, ...(before.activeBranches === undefined ? {} : { branchIds: before.activeBranches }), firstStartAtMillis, throughStartAtMillis, ...(cursor ? { cursor } : {}), limit: 21 };
  const rows = before.activeBranches?.length === 0 ? [] : await reader.read(q);
  const current = await store.transact(scope);
  if (JSON.stringify(before) !== JSON.stringify(current)) throw new DomainError('permission-denied', 'Booking access changed. Refresh the current account scope.');
  if (!Array.isArray(rows) || rows.length > 21) throw review();
  const projected = rows.map(r => project(r, q));
  const ids = new Set<string>();
  let previous = cursor;
  for (const r of projected) {
    if (ids.has(r.bookingId) || (previous && !after(r, previous))) throw review();
    ids.add(r.bookingId); previous = r;
  }
  const records = projected.slice(0, 20), last = records.at(-1);
  return { schemaVersion: 1, serverNowMillis, timeZone: before.policy.timeZone, firstLocalDate, throughLocalDate, records,
    ...(projected.length > 20 && last ? { nextCursor: { startAtMillis: last.startAtMillis, bookingId: last.bookingId } } : {}) };
}
