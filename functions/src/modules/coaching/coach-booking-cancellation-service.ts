import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { keyOf } from '../../platform/idempotency';
import { allowed, integer, object, SLOT } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { storedBooking } from './booking-record';

export interface CancelAssignedBookingResult {
  schemaVersion: 1;
  bookingId: string;
  requestId: string;
  status: 'cancelled';
  outcome: 'cancelled' | 'already_cancelled';
  cancelledAtMillis: number;
  refundReviewRequired: boolean;
}

export function cancellationReasonText(value: unknown): string {
  if (typeof value !== 'string') throw new InputValidationError('Reason is required.');
  const trimmed = value.trim();
  if (trimmed.length < 1 || trimmed.length > 500) throw new InputValidationError('Enter a reason of 1–500 characters.');
  if (/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/.test(trimmed)) throw new InputValidationError('Reason contains invalid characters.');
  return trimmed;
}

export async function cancelAssignedBookingService(
  store: DocumentStore,
  auth: { uid: string; token: Record<string, unknown> } | undefined,
  raw: unknown,
  clock = Date.now
): Promise<CancelAssignedBookingResult> {
  requireVerifiedEmail(auth);
  const input = object(raw);
  allowed(input, ['schemaVersion', 'organizationId', 'bookingId', 'requestId', 'reason']);
  if (input.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const bookingId = requiredIdentifier(input.bookingId, 'bookingId');
  const requestId = requiredIdentifier(input.requestId, 'requestId');
  const reason = cancellationReasonText(input.reason);
  const uid = requiredIdentifier(auth!.uid, 'actorId');
  const now = integer(clock(), 1);

  const receiptPath = `orgs/${org}/commandReceipts/${keyOf('cancelAssignedBooking', uid, requestId)}`;
  const fingerprint = keyOf(org, bookingId, reason);

  return store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, uid);
    if (actor.role !== 'coach') {
      throw new DomainError('permission-denied', 'Only Coaches can cancel assigned sessions.');
    }
    await requireBookingOrganization(tx, org);

    const root = `orgs/${org}/bookings/${bookingId}`;
    const rawBooking = await tx.get(root);
    const booking = storedBooking(rawBooking, org, bookingId);

    if (booking.coachId !== uid) {
      throw new DomainError('permission-denied', 'Only the assigned Coach can cancel this session.');
    }

    if (!actor.branchIds.includes(booking.branchId) ||
        (await tx.get(`orgs/${org}/branches/${booking.branchId}`))?.status !== 'active') {
      throw new DomainError('permission-denied', 'Active branch access is required.');
    }

    // Idempotency check via receipt
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.fingerprint !== fingerprint || receipt.command !== 'cancelAssignedBooking' || receipt.actorId !== uid) {
        throw new DomainError('already-exists', 'This request was used for a different cancellation.');
      }
      if (booking.status !== 'cancelled' || booking.resolution !== 'coach_cancelled' || booking.cancellationReason !== reason) {
        throw new DomainError('failed-precondition', 'Cancellation receipt does not match stored booking state.');
      }
      const r = object(receipt.result);
      return {
        schemaVersion: 1,
        bookingId,
        requestId,
        status: 'cancelled',
        outcome: 'already_cancelled',
        cancelledAtMillis: Number(receipt.createdAtMillis ?? booking.resolvedAtMillis),
        refundReviewRequired: Boolean(r.refundReviewRequired),
      };
    }

    // State validation
    if (booking.status !== 'confirmed') {
      throw new DomainError('failed-precondition', 'Only confirmed sessions can be cancelled by the coach.');
    }

    // Time validation: Coach cancellation can only occur before the session starts
    if (now >= booking.startAtMillis) {
      throw new DomainError('failed-precondition', 'Cannot cancel a session that has already started or ended.');
    }

    // Read all slot locks first (read-before-write)
    const locksToRelease: { path: string; data: DocumentData }[] = [];
    for (let slot = booking.startAtMillis; slot < booking.endAtMillis; slot += SLOT) {
      const lockPath = `orgs/${org}/slotLocks/${keyOf(booking.coachId, slot)}`;
      const lock = await tx.get(lockPath);
      if (lock && lock.bookingId === bookingId && lock.status === 'confirmed') {
        locksToRelease.push({ path: lockPath, data: lock });
      }
    }

    // Read member's bookingDays first (read-before-write)
    const dayPath = `orgs/${org}/bookingDays/${keyOf(booking.memberId, booking.localDate)}`;
    const day = await tx.get(dayPath);

    // Read financial transaction first (read-before-write)
    const txDocPath = `orgs/${org}/transactions/${bookingId}`;
    const txData = await tx.get(txDocPath);

    // ALL READS ARE COMPLETE. NOW PERFORM WRITES.

    // 1. Release slot locks
    for (const { path: lockPath, data: lock } of locksToRelease) {
      tx.set(lockPath, { ...lock, status: 'cancelled', expiresAtMillis: now });
    }

    // 2. Prune reservation from member's bookingDays
    if (day && Array.isArray(day.reservations)) {
      const updatedReservations = (day.reservations as DocumentData[]).filter(r => r.bookingId !== bookingId);
      tx.set(dayPath, { ...day, reservations: updatedReservations });
    }

    // 3. Update financial transaction and route paid sessions to refund review
    let refundReviewRequired = false;
    if (txData && txData.schemaVersion === 1) {
      if (txData.paymentStatus === 'cleared') {
        refundReviewRequired = true;
        tx.set(txDocPath, {
          ...txData,
          fulfilmentStatus: 'reconciliation_required',
          resolutionReason: 'coach_cancelled',
          refundReviewRequired: true,
          reviewReason: reason,
          updatedAtMillis: now,
        });

        // Audit event for payment review
        const eventKey = keyOf('resolution_required', requestId);
        tx.create(`${txDocPath}/events/${eventKey}`, {
          schemaVersion: 1,
          environment: txData.environment ?? 'sandbox',
          event: 'resolution_required',
          atMillis: now,
          actorId: uid,
          reason: `Coach cancelled: ${reason}`,
        });
      }
    }

    // Update booking
    tx.set(root, {
      ...booking,
      status: 'cancelled',
      resolution: 'coach_cancelled',
      resolvedAtMillis: now,
      cancellationReason: reason,
      cancelledBy: uid,
    });

    // Emit deterministic notification event for Task 3
    const notificationKey = keyOf('coachCancellation', bookingId, requestId);
    tx.create(`orgs/${org}/bookingNotificationEvents/${notificationKey}`, {
      schemaVersion: 1,
      type: 'coach_cancellation',
      bookingId,
      actorId: uid,
      recipientId: booking.memberId,
      atMillis: now,
      reason,
    });

    const result: CancelAssignedBookingResult = {
      schemaVersion: 1,
      bookingId,
      requestId,
      status: 'cancelled',
      outcome: 'cancelled',
      cancelledAtMillis: now,
      refundReviewRequired,
    };

    tx.create(receiptPath, {
      schemaVersion: 1,
      command: 'cancelAssignedBooking',
      actorId: uid,
      fingerprint,
      createdAtMillis: now,
      result,
    });

    return result;
  });
}
