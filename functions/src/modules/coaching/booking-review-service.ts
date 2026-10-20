import type { DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { keyOf } from '../../platform/idempotency';
import { allowed, integer, object } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { storedBooking } from './booking-record';

export interface BookingReviewInput {
  schemaVersion: 1;
  organizationId: string;
  bookingId: string;
  requestId: string;
  stars: number;
  reviewText?: string;
}

export interface BookingReviewResult {
  schemaVersion: 1;
  bookingId: string;
  requestId: string;
  stars: number;
  reviewedAtMillis: number;
}

export async function submitBookingReview(
  store: DocumentStore,
  auth: { uid: string; token: Record<string, unknown> } | undefined,
  raw: unknown,
  clock: () => number = Date.now
): Promise<BookingReviewResult> {
  requireVerifiedEmail(auth);
  const input = object(raw);
  allowed(input, ['schemaVersion', 'organizationId', 'bookingId', 'requestId', 'stars', 'reviewText']);
  if (input.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const bookingId = requiredIdentifier(input.bookingId, 'bookingId');
  const requestId = requiredIdentifier(input.requestId, 'requestId');
  const uid = requiredIdentifier(auth!.uid, 'actorId');
  const stars = integer(input.stars, 1, 5);
  const reviewText = typeof input.reviewText === 'string' ? input.reviewText.trim() : '';
  if (reviewText.length > 500) throw new InputValidationError('Review text must be at most 500 characters.');

  const root = `orgs/${org}/bookings/${bookingId}`;
  const receiptPath = `orgs/${org}/commandReceipts/${keyOf('bookingReview', uid, requestId)}`;
  const fingerprint = keyOf(org, bookingId, stars, reviewText);
  const now = clock();

  return store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, uid);
    await requireBookingOrganization(tx, org);

    if (actor.role !== 'member') {
      throw new DomainError('permission-denied', 'Only members may submit session reviews.');
    }

    const b = storedBooking(await tx.get(root), org, bookingId);
    if (b.memberId !== uid) {
      throw new DomainError('permission-denied', 'Only the member who attended may review this session.');
    }

    if (b.status !== 'completed') {
      throw new DomainError('failed-precondition', 'Only completed sessions can be reviewed.');
    }

    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.fingerprint !== fingerprint) {
        throw new DomainError('already-exists', 'This request was already submitted with different review content.');
      }
      return {
        schemaVersion: 1,
        bookingId,
        requestId,
        stars,
        reviewedAtMillis: Number(receipt.createdAtMillis),
      };
    }

    const reviewPath = `${root}/review/current`;
    const existing = await tx.get(reviewPath);
    if (existing) {
      throw new DomainError('already-exists', 'This booking has already been reviewed.');
    }

    const reviewData = {
      schemaVersion: 1,
      bookingId,
      coachId: b.coachId,
      memberId: uid,
      stars,
      reviewText,
      reviewedAtMillis: now,
    };

    tx.create(reviewPath, reviewData);
    tx.create(`orgs/${org}/coaches/${b.coachId}/reviews/${bookingId}`, reviewData);
    tx.create(receiptPath, {
      schemaVersion: 1,
      command: 'bookingReview',
      actorId: uid,
      fingerprint,
      bookingId,
      createdAtMillis: now,
    });

    return {
      schemaVersion: 1,
      bookingId,
      requestId,
      stars,
      reviewedAtMillis: now,
    };
  });
}
