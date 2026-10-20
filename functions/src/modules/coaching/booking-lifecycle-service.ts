import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { keyOf } from '../../platform/idempotency';
import { allowed, integer, object, SLOT } from './coach-availability-contracts';
import { activeBookingReservations, currentBookingMembership, requireBookingOrganization, validBookingId, validBookingTime } from './booking-validation';
import { bookingReview, storedBooking, type StoredBooking } from './booking-record';

export interface CancelBookingHoldResult {
  schemaVersion: 1; requestId: string; bookingId: string; status: 'cancelled' | 'expired';
  outcome: 'cancelled' | 'expired' | 'already_closed'; resolvedAtMillis?: number;
}
function jobData(data: DocumentData | undefined, id: string) {
  if (!data || data.schemaVersion !== 1 || data.type !== 'expireBookingHold' || data.bookingId !== id
    || typeof data.status !== 'string' || !['pending', 'completed', 'blocked'].includes(data.status)
    || !validBookingTime(data.dueAtMillis) || !Number.isSafeInteger(data.attempts) || Number(data.attempts) < 0) throw bookingReview();
  return data;
}
const jobPath = (org: string, id: string) => `orgs/${org}/jobs/${keyOf('expireBookingHold', id)}`;

// Read everything first. Never release another booking's replacement lock, or
// prune unrelated reservations. Existing allocators reclaim elapsed lock tombstones.
async function closePending(tx: TransactionPort, b: StoredBooking, job: DocumentData, now: number) {
  if (now < b.createdAtMillis || job.dueAtMillis !== b.holdExpiresAtMillis || job.status !== 'pending') throw bookingReview();
  const root = `orgs/${b.organizationId}`, dayPath = `${root}/bookingDays/${keyOf(b.memberId, b.localDate)}`;
  const day = await tx.get(dayPath);
  activeBookingReservations(day, b.memberId, b.localDate, b.timeZone, now); // Validate; do NOT persist this filtered result.
  const reservations = (day?.reservations ?? []) as DocumentData[];
  const own = reservations.find(r => r.bookingId === b.bookingId);
  if ((own && (own.status !== 'pending_hold' || own.expiresAtMillis !== b.holdExpiresAtMillis)) || (!own && now < b.holdExpiresAtMillis)) throw bookingReview();
  const locks = [];
  for (let slot = b.startAtMillis; slot < b.endAtMillis; slot += SLOT) {
    const path = `${root}/slotLocks/${keyOf(b.coachId, slot)}`, d = await tx.get(path);
    if (!d) { if (now < b.holdExpiresAtMillis) throw bookingReview(); continue; }
    if (!validBookingId(d.bookingId)) throw bookingReview();
    if (d.bookingId !== b.bookingId) { if (now < b.holdExpiresAtMillis) throw bookingReview(); continue; }
    if (d.schemaVersion !== 1 || d.coachId !== b.coachId || d.branchId !== b.branchId || d.status !== 'pending_hold' || d.expiresAtMillis !== b.holdExpiresAtMillis) throw bookingReview();
    locks.push({ path, data: d });
  }
  const status = now >= b.holdExpiresAtMillis ? 'expired' : 'cancelled';
  tx.set(`${root}/bookings/${b.bookingId}`, { ...b, status, resolvedAtMillis: now, resolution: status === 'expired' ? 'hold_expired' : 'member_cancelled' });
  if (own) tx.set(dayPath, { ...day, reservations: reservations.filter(r => r.bookingId !== b.bookingId) });
  if (status === 'cancelled') for (const lock of locks) tx.set(lock.path, { ...lock.data, expiresAtMillis: now });
  tx.set(jobPath(b.organizationId, b.bookingId), { ...job, status: 'completed', outcome: status, processedAtMillis: now, attempts: Number(job.attempts) + 1 });
  return status;
}
function replay(d: DocumentData, actor: string, fingerprint: string, requestId: string, bookingId: string): CancelBookingHoldResult {
  if (d.fingerprint !== fingerprint) throw new DomainError('already-exists', 'requestId was used with a different payload.');
  const r = object(d.result);
  allowed(r, ['schemaVersion', 'requestId', 'bookingId', 'status', 'outcome', 'resolvedAtMillis']);
  if (d.schemaVersion !== 1 || d.command !== 'cancelBookingHold' || d.actorId !== actor || !validBookingTime(d.createdAtMillis)
    || r.schemaVersion !== 1 || r.requestId !== requestId || r.bookingId !== bookingId || typeof r.status !== 'string' || !['cancelled', 'expired'].includes(r.status)
    || typeof r.outcome !== 'string' || !['cancelled', 'expired', 'already_closed'].includes(r.outcome)
    || (r.outcome !== 'already_closed' && r.outcome !== r.status)
    || (r.outcome !== 'already_closed' && r.resolvedAtMillis === undefined)
    || (r.resolvedAtMillis !== undefined && !validBookingTime(r.resolvedAtMillis))) throw bookingReview();
  return r as unknown as CancelBookingHoldResult;
}
export async function cancelBookingHoldService(store: DocumentStore, auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, clock = Date.now): Promise<CancelBookingHoldResult> {
  requireVerifiedEmail(auth);
  const input = object(raw); allowed(input, ['schemaVersion', 'organizationId', 'requestId', 'bookingId']);
  if (input.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(input.organizationId, 'organizationId'), requestId = requiredIdentifier(input.requestId, 'requestId');
  const id = requiredIdentifier(input.bookingId, 'bookingId'), uid = requiredIdentifier(auth!.uid, 'actorId');
  const receipt = `orgs/${org}/commandReceipts/${keyOf('cancelBookingHold', uid, requestId)}`, fingerprint = keyOf(org, id);
  return store.transact(async tx => {
    const member = await currentBookingMembership(tx, org, uid); await requireBookingOrganization(tx, org);
    if (member.role !== 'member') throw new DomainError('permission-denied', 'Only Members may cancel their own pending holds.');
    const prior = await tx.get(receipt);
    if (prior) return replay(prior, uid, fingerprint, requestId, id);
    const b = storedBooking(await tx.get(`orgs/${org}/bookings/${id}`), org, id);
    if (b.memberId !== uid) throw new DomainError('permission-denied', 'Only the booking owner may cancel.');
    if (!['pending_hold', 'cancelled', 'expired'].includes(b.status)) throw new DomainError('failed-precondition', 'Only pending holds can be cancelled.');
    const now = integer(clock(), 1), job = jobData(await tx.get(jobPath(org, id)), id);
    const status = b.status === 'pending_hold' ? await closePending(tx, b, job, now) : b.status as 'cancelled' | 'expired';
    const result: CancelBookingHoldResult = { schemaVersion: 1, requestId, bookingId: id, status, outcome: b.status === 'pending_hold' ? status : 'already_closed',
      ...((b.status === 'pending_hold' ? now : b.resolvedAtMillis) === undefined ? {} : { resolvedAtMillis: b.status === 'pending_hold' ? now : b.resolvedAtMillis }) };
    tx.create(receipt, { schemaVersion: 1, command: 'cancelBookingHold', actorId: uid, fingerprint, createdAtMillis: now, result });
    return result;
  });
}

export async function expireBookingHoldService(store: DocumentStore, path: string, clock = Date.now): Promise<string> {
  const parts = path.split('/');
  if (parts.length !== 4 || parts[0] !== 'orgs' || !validBookingId(parts[1]) || parts[2] !== 'jobs') throw bookingReview();
  return store.transact(async tx => {
    const raw = await tx.get(path);
    if (!raw || !validBookingId(raw.bookingId) || path !== jobPath(parts[1], raw.bookingId)) throw bookingReview();
    const job = jobData(raw, raw.bookingId), now = integer(clock(), 1);
    if (job.status !== 'pending') return 'already_processed';
    if (Number(job.dueAtMillis) > now) return 'not_due';
    const b = storedBooking(await tx.get(`orgs/${parts[1]}/bookings/${job.bookingId}`), parts[1], String(job.bookingId));
    if (job.dueAtMillis !== b.holdExpiresAtMillis) throw bookingReview();
    if (b.status !== 'pending_hold') {
      tx.set(path, { ...job, status: 'completed', outcome: 'not_pending', processedAtMillis: now, attempts: Number(job.attempts) + 1 });
      return 'not_pending';
    }
    return closePending(tx, b, job, now);
  });
}
