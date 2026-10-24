import { randomUUID } from 'node:crypto';
import { memberBusySlots } from './member-booking-conflicts';
import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { parseCreateBookingHold, requiredIdentifier } from '../../platform/validation';
import { DomainError } from '../../platform/errors';
import { keyOf } from '../../platform/idempotency';
import { localDate, SLOT } from './coach-availability-contracts';
import type { CoachIdentityReader } from './coach-profile-service';
import { authorizeBookingCreate, bookingCoachScope, bookingDaySnapshot, coachEligibilityFailure, currentBookingPolicy, validBookingId, validBookingTime } from './booking-validation';

export interface CreateBookingHoldResult {
  schemaVersion: 1;
  bookingId: string;
  requestId: string;
  status: 'pending_hold';
  holdExpiresAtMillis: number;
}
function replay(receipt: DocumentData | undefined, fingerprint: string, actorId: string, requestId: string, start: number): CreateBookingHoldResult | undefined {
  if (!receipt) return undefined;
  if (receipt.fingerprint !== fingerprint) throw new DomainError('already-exists', 'requestId was used with a different payload.');
  const result = receipt.result as CreateBookingHoldResult | undefined;
  if (receipt.schemaVersion !== 1 || receipt.command !== 'createBookingHold' || receipt.actorId !== actorId || !validBookingTime(receipt.createdAtMillis)
    || !result || typeof result !== 'object' || Array.isArray(result) || Object.keys(result).some(k => !['schemaVersion', 'bookingId', 'requestId', 'status', 'holdExpiresAtMillis'].includes(k))
    || result.schemaVersion !== 1 || !validBookingId(result.bookingId) || result.requestId !== requestId || result.status !== 'pending_hold'
    || !validBookingTime(result.holdExpiresAtMillis) || result.holdExpiresAtMillis > start || result.holdExpiresAtMillis <= receipt.createdAtMillis) throw new DomainError('failed-precondition', 'Booking receipt needs authorized review.');
  return { schemaVersion: 1, bookingId: result.bookingId, requestId, status: 'pending_hold', holdExpiresAtMillis: result.holdExpiresAtMillis };
}
export async function createBookingHoldService(store: DocumentStore, actorId: string, rawInput: unknown,
  readIdentity: CoachIdentityReader, clock: () => number = Date.now): Promise<CreateBookingHoldResult> {
  const input = parseCreateBookingHold(rawInput);
  requiredIdentifier(actorId, 'actorId');
  const root = `orgs/${input.organizationId}`;
  const receiptPath = `${root}/commandReceipts/${keyOf('createBookingHold', actorId, input.requestId)}`;
  const fingerprint = keyOf(input);
  const prior = async (tx: TransactionPort) => {
    await authorizeBookingCreate(tx, input.organizationId, actorId, input);
    return replay(await tx.get(receiptPath), fingerprint, actorId, input.requestId, input.startAtMillis);
  };
  const existing = await store.transact(prior);
  if (existing) return existing;
  const eligibilityFailure = await coachEligibilityFailure(readIdentity, input.coachId);
  const bookingId = randomUUID(); // Stable across retries; external Auth is never called in callbacks.
  return store.transact(async tx => {
    const existing = await prior(tx);
    if (existing) return existing; // A concurrent receipt wins even if the Auth lookup failed.
    if (eligibilityFailure) throw eligibilityFailure;
    const now = clock();
    if (input.startAtMillis <= now || input.startAtMillis % SLOT !== 0) throw new DomainError('invalid-argument', 'Start must be a future half-hour boundary.');
    const policy = currentBookingPolicy(await tx.get(`${root}/settings/booking`));
    const date = localDate(input.startAtMillis, policy.timeZone), endAtMillis = input.startAtMillis + input.durationMinutes * 60000;
    if (localDate(endAtMillis - 1, policy.timeZone) !== date) throw new DomainError('invalid-argument', 'A booking must stay within one organization-local date.');
    const coach = await bookingCoachScope(tx, input.organizationId, input.coachId, [input.branchId]);
    const day = await bookingDaySnapshot(tx, input.organizationId, input.coachId, input.memberId, date, policy, coach.assigned, now);
    if (!day.windows.some(w => w.branchId === input.branchId && w.startAtMillis <= input.startAtMillis && w.endAtMillis >= endAtMillis)) throw new DomainError('failed-precondition', 'No published availability covers the entire booking.');
    const slots = Array.from({ length: input.durationMinutes / 30 }, (_, i) => input.startAtMillis + i * SLOT);
    if (slots.some(slot => day.blocked.has(slot))) throw new DomainError('aborted', 'The selected time is no longer available.');
    if (day.reservations.length >= policy.cap) throw new DomainError('resource-exhausted', 'Daily booking limit reached.');
    const memberBlocked = await memberBusySlots(tx,input.organizationId,input.memberId,date,policy.timeZone,day.reservations);
    if (slots.some(slot=>memberBlocked.has(slot))) throw new DomainError('aborted','You already have a session or active hold at this time. Choose a nonoverlapping time.');
    if (day.dailyCapacityMinutes !== undefined && day.blocked.size * 30 + input.durationMinutes > day.dailyCapacityMinutes) throw new DomainError('resource-exhausted', 'Coach daily booking hours reached.');
    const holdExpiresAtMillis = Math.min(now + policy.holdMillis, input.startAtMillis);
    const result: CreateBookingHoldResult = { schemaVersion: 1, bookingId, requestId: input.requestId, status: 'pending_hold', holdExpiresAtMillis };
    tx.create(`${root}/bookings/${bookingId}`, { ...input, ...result, createdBy: actorId, createdAtMillis: now,
      endAtMillis, localDate: date, timeZone: policy.timeZone, policyVersion: policy.policyVersion });
    slots.forEach(slot => tx.set(`${root}/slotLocks/${keyOf(input.coachId, slot)}`, { schemaVersion: 1, bookingId, branchId: input.branchId,
      coachId: input.coachId, status: 'pending_hold', expiresAtMillis: holdExpiresAtMillis }));
    tx.set(day.dayPath, { schemaVersion: 1, memberId: input.memberId, localDate: date, timeZone: policy.timeZone,
      reservations: [...day.reservations, { bookingId, status: 'pending_hold', expiresAtMillis: holdExpiresAtMillis }] });
    tx.create(receiptPath, { schemaVersion: 1, command: 'createBookingHold', actorId, fingerprint, createdAtMillis: now, result });
    tx.create(`${root}/jobs/${keyOf('expireBookingHold', bookingId)}`, { schemaVersion: 1, type: 'expireBookingHold',
      bookingId, status: 'pending', dueAtMillis: holdExpiresAtMillis, attempts: 0 });
    return result;
  });
}
