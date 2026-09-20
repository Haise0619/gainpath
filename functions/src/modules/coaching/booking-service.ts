import { randomUUID } from 'node:crypto';
import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { parseCreateBookingHold, requiredIdentifier } from '../../platform/validation';
import { requireActiveMembership, requireBranchAccess } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { keyOf } from '../../platform/idempotency';

const SLOT_MILLIS = 30 * 60 * 1000;
export interface CreateBookingHoldResult {
  schemaVersion: 1;
  bookingId: string;
  requestId: string;
  status: 'pending_hold';
  holdExpiresAtMillis: number;
}
interface Reservation { bookingId: string; status: 'pending_hold' | 'confirmed'; expiresAtMillis: number }

function policyFrom(data: DocumentData | undefined) {
  if (data?.schemaVersion !== 1 || typeof data.policyVersion !== 'string' || !data.policyVersion
    || typeof data.timeZone !== 'string' || !Number.isInteger(data.maxActiveBookingsPerMemberPerDay)
    || Number(data.maxActiveBookingsPerMemberPerDay) < 1 || Number(data.maxActiveBookingsPerMemberPerDay) > 32
    || !Number.isInteger(data.holdMinutes) || Number(data.holdMinutes) < 1 || Number(data.holdMinutes) > 30) {
    throw new DomainError('failed-precondition', 'Booking policy has not been configured.');
  }
  try { new Intl.DateTimeFormat('en', { timeZone: data.timeZone }).format(); }
  catch { throw new DomainError('failed-precondition', 'Invalid organization timezone.'); }
  return { policyVersion: data.policyVersion, timeZone: data.timeZone,
    cap: Number(data.maxActiveBookingsPerMemberPerDay), holdMillis: Number(data.holdMinutes) * 60000 };
}
function localDate(millis: number, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(millis);
  const part = (type: string) => parts.find(p => p.type === type)!.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}
function activeReservations(data: DocumentData | undefined, now: number): Reservation[] {
  if (!data) return [];
  if (data.schemaVersion !== 1 || !Array.isArray(data.reservations) || data.reservations.length > 32) {
    throw new DomainError('failed-precondition', 'Invalid daily booking accounting.');
  }
  const reservations = data.reservations as Reservation[];
  if (reservations.some(r => !r || typeof r.bookingId !== 'string' || !Number.isSafeInteger(r.expiresAtMillis)
    || !['confirmed', 'pending_hold'].includes(r.status))) {
    throw new DomainError('failed-precondition', 'Invalid daily reservation.');
  }
  return reservations.filter(r => r.status === 'confirmed' || r.expiresAtMillis > now);
}

export async function createBookingHoldService(store: DocumentStore, actorId: string, rawInput: unknown,
  clock: () => number = Date.now): Promise<CreateBookingHoldResult> {
  const input = parseCreateBookingHold(rawInput);
  requiredIdentifier(actorId, 'actorId');
  const root = `orgs/${input.organizationId}`;
  const receiptPath = `${root}/commandReceipts/${keyOf('createBookingHold', actorId, input.requestId)}`;
  const fingerprint = keyOf(input); // Parsed field order is canonical, unknown fields rejected.
  const bookingId = randomUUID(); // Stable even if Firestore retries this transaction.

  return store.transact(async tx => {
    const now = clock(); // Re-evaluate expiration on each transaction attempt.
    const actor = requireActiveMembership(await tx.get(`${root}/members/${actorId}`));
    requireBranchAccess(actor, input.branchId);
    if (!['member', 'staff', 'admin'].includes(actor.role) || (actor.role === 'member' && actorId !== input.memberId)) {
      throw new DomainError('permission-denied', 'Cannot book for this member.');
    }
    const member = requireActiveMembership(await tx.get(`${root}/members/${input.memberId}`));
    requireBranchAccess(member, input.branchId);
    if (member.role !== 'member') throw new DomainError('permission-denied', 'The booking recipient must be a member.');
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.fingerprint !== fingerprint) throw new DomainError('already-exists', 'requestId was used with a different payload.');
      return receipt.result as unknown as CreateBookingHoldResult;
    }
    if (input.startAtMillis <= now || input.startAtMillis % SLOT_MILLIS !== 0) {
      throw new DomainError('invalid-argument', 'Start must be a future half-hour boundary.');
    }
    const policy = policyFrom(await tx.get(`${root}/settings/booking`));
    const date = localDate(input.startAtMillis, policy.timeZone);
    const endAtMillis = input.startAtMillis + input.durationMinutes * 60000;
    if (localDate(endAtMillis - 1, policy.timeZone) !== date) {
      throw new DomainError('invalid-argument', 'A booking must stay within one organization-local date.');
    }
    const branch = await tx.get(`${root}/branches/${input.branchId}`);
    const coach = await tx.get(`${root}/coaches/${input.coachId}`);
    const coachMember = requireActiveMembership(await tx.get(`${root}/members/${input.coachId}`));
    requireBranchAccess(coachMember, input.branchId);
    if (branch?.status !== 'active' || coachMember.role !== 'coach' || coach?.status !== 'published'
      || !Array.isArray(coach.branchIds) || !coach.branchIds.includes(input.branchId)) {
      throw new DomainError('failed-precondition', 'Coach or branch unavailable.');
    }
    const availability = await tx.get(`${root}/coachAvailability/${input.coachId}/days/${date}`);
    const available = availability?.schemaVersion === 1 && Array.isArray(availability.windows)
      && availability.windows.some((w: DocumentData) => w && w.branchId === input.branchId
        && Number.isSafeInteger(w.startAtMillis) && Number.isSafeInteger(w.endAtMillis)
        && Number(w.startAtMillis) <= input.startAtMillis && Number(w.endAtMillis) >= endAtMillis);
    if (!available) throw new DomainError('failed-precondition', 'No published availability covers the entire booking.');
    const dayPath = `${root}/bookingDays/${keyOf(input.memberId, date)}`;
    const day = await tx.get(dayPath);
    if (day && day.timeZone !== policy.timeZone) throw new DomainError('failed-precondition', 'Timezone accounting needs migration.');
    const reservations = activeReservations(day, now);
    const slotPaths = Array.from({ length: input.durationMinutes / 30 }, (_, i) =>
      `${root}/slotLocks/${keyOf(input.coachId, input.startAtMillis + i * SLOT_MILLIS)}`);
    for (const path of slotPaths) {
      const lock = await tx.get(path);
      // Only known expired holds can be replaced. Confirmed/malformed locks fail closed.
      if (lock && (lock.status !== 'pending_hold' || !Number.isSafeInteger(lock.expiresAtMillis) || Number(lock.expiresAtMillis) > now)) {
        throw new DomainError('aborted', 'The selected time is no longer available.');
      }
    }
    if (reservations.length >= policy.cap) throw new DomainError('resource-exhausted', 'Daily booking limit reached.');
    const holdExpiresAtMillis = Math.min(now + policy.holdMillis, input.startAtMillis);
    const result: CreateBookingHoldResult = { schemaVersion: 1, bookingId, requestId: input.requestId,
      status: 'pending_hold', holdExpiresAtMillis };
    tx.create(`${root}/bookings/${bookingId}`, { ...input, ...result, createdBy: actorId, createdAtMillis: now,
      endAtMillis, localDate: date, timeZone: policy.timeZone, policyVersion: policy.policyVersion });
    slotPaths.forEach(path => tx.set(path, { schemaVersion: 1, bookingId, branchId: input.branchId,
      coachId: input.coachId, status: 'pending_hold', expiresAtMillis: holdExpiresAtMillis }));
    tx.set(dayPath, { schemaVersion: 1, memberId: input.memberId, localDate: date, timeZone: policy.timeZone,
      reservations: [...reservations, { bookingId, status: 'pending_hold', expiresAtMillis: holdExpiresAtMillis }] });
    tx.create(receiptPath, { schemaVersion: 1, command: 'createBookingHold', actorId, fingerprint, createdAtMillis: now, result });
    tx.create(`${root}/jobs/${keyOf('expireBookingHold', bookingId)}`, { schemaVersion: 1, type: 'expireBookingHold',
      bookingId, status: 'pending', dueAtMillis: holdExpiresAtMillis, attempts: 0 });
    return result;
  });
}
