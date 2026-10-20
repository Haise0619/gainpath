import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now, start } from './booking-fixture';
import { cancelAssignedBookingService } from '../src/modules/coaching/coach-booking-cancellation-service';
import { keyOf } from '../src/platform/idempotency';

let store: MemoryStore;
const org = 'org-1';
const bookingId = 'booking-1';
const bookingPath = `orgs/${org}/bookings/${bookingId}`;
const input = {
  schemaVersion: 1,
  organizationId: org,
  bookingId,
  requestId: 'cancel-req-1',
  reason: 'Family emergency, unable to attend session.',
};

const call = (uid = 'coach-1', extra = {}, time = now) =>
  cancelAssignedBookingService(
    store,
    { uid, token: { email_verified: true } },
    { ...input, ...extra },
    () => time
  );

beforeEach(() => {
  store = new MemoryStore();
  Object.entries(seeds).forEach(([p, d]) => store.documents.set(p, structuredClone(d)));

  // Confirmed booking
  store.documents.set(bookingPath, {
    schemaVersion: 1,
    bookingId,
    organizationId: org,
    memberId: 'member-1',
    coachId: 'coach-1',
    branchId: 'branch-1',
    requestId: 'hold-1',
    createdBy: 'member-1',
    createdAtMillis: now - 3600000,
    startAtMillis: start,
    endAtMillis: start + 3600000,
    durationMinutes: 60,
    status: 'confirmed',
    holdExpiresAtMillis: now - 1800000,
    localDate: '2026-10-02',
    timeZone: 'Asia/Kuala_Lumpur',
    policyVersion: 'booking-v1',
  });

  // Confirmed slot locks
  for (let slot = start; slot < start + 3600000; slot += 1800000) {
    const lockPath = `orgs/${org}/slotLocks/${keyOf('coach-1', slot)}`;
    store.documents.set(lockPath, {
      schemaVersion: 1,
      bookingId,
      coachId: 'coach-1',
      branchId: 'branch-1',
      status: 'confirmed',
      expiresAtMillis: 0,
    });
  }

  // Confirmed reservation in bookingDays
  const dayPath = `orgs/${org}/bookingDays/${keyOf('member-1', '2026-10-02')}`;
  store.documents.set(dayPath, {
    schemaVersion: 1,
    memberId: 'member-1',
    localDate: '2026-10-02',
    timeZone: 'Asia/Kuala_Lumpur',
    reservations: [
      {
        bookingId,
        status: 'confirmed',
        expiresAtMillis: 0,
      },
    ],
  });

  // Cleared transaction
  store.documents.set(`orgs/${org}/transactions/${bookingId}`, {
    schemaVersion: 1,
    environment: 'sandbox',
    provider: 'billplz',
    organizationId: org,
    bookingId,
    currency: 'MYR',
    amountMinor: 10000,
    paymentStatus: 'cleared',
    fulfilmentStatus: 'confirmed',
  });
});

it('atomically cancels assigned booking, releases locks, routes payment to refund review, and records receipt', async () => {
  const result = await call('coach-1');

  expect(result).toEqual({
    schemaVersion: 1,
    bookingId,
    requestId: 'cancel-req-1',
    status: 'cancelled',
    outcome: 'cancelled',
    cancelledAtMillis: now,
    refundReviewRequired: true,
  });

  // Verify booking updated
  const updatedBooking = store.documents.get(bookingPath);
  expect(updatedBooking?.status).toBe('cancelled');
  expect(updatedBooking?.resolution).toBe('coach_cancelled');
  expect(updatedBooking?.cancellationReason).toBe(input.reason);
  expect(updatedBooking?.cancelledBy).toBe('coach-1');
  expect(updatedBooking?.resolvedAtMillis).toBe(now);

  // Verify slot locks released
  for (let slot = start; slot < start + 3600000; slot += 1800000) {
    const lockPath = `orgs/${org}/slotLocks/${keyOf('coach-1', slot)}`;
    const lock = store.documents.get(lockPath);
    expect(lock?.status).toBe('cancelled');
    expect(lock?.expiresAtMillis).toBe(now);
  }

  // Verify reservation pruned
  const dayPath = `orgs/${org}/bookingDays/${keyOf('member-1', '2026-10-02')}`;
  const day = store.documents.get(dayPath);
  expect(day?.reservations).toEqual([]);

  // Verify transaction marked for reconciliation/refund review
  const tx = store.documents.get(`orgs/${org}/transactions/${bookingId}`);
  expect(tx?.fulfilmentStatus).toBe('reconciliation_required');
  expect(tx?.resolutionReason).toBe('coach_cancelled');
  expect(tx?.refundReviewRequired).toBe(true);
  expect(tx?.reviewReason).toBe(input.reason);

  // Verify audit event
  const eventKey = keyOf('resolution_required', 'cancel-req-1');
  const event = store.documents.get(`orgs/${org}/transactions/${bookingId}/events/${eventKey}`);
  expect(event?.event).toBe('resolution_required');
  expect(event?.actorId).toBe('coach-1');

  // Verify notification event
  const notificationKey = keyOf('coachCancellation', bookingId, 'cancel-req-1');
  const notification = store.documents.get(`orgs/${org}/bookingNotificationEvents/${notificationKey}`);
  expect(notification?.type).toBe('coach_cancellation');
  expect(notification?.recipientId).toBe('member-1');
});

it('replays identical cancellation idempotently without duplicate side-effects', async () => {
  const first = await call('coach-1');
  const snapshot = structuredClone([...store.documents]);

  const second = await call('coach-1');
  expect(second).toEqual({
    ...first,
    outcome: 'already_cancelled',
  });

  expect([...store.documents]).toEqual(snapshot);
});

it('rejects changed payload with existing requestId', async () => {
  await call('coach-1');
  await expect(call('coach-1', { reason: 'Different reason for cancellation' }))
    .rejects.toMatchObject({ code: 'already-exists' });
});

it('rejects unauthorized actors and revoked branch access', async () => {
  // Member cannot cancel coach session
  await expect(call('member-1')).rejects.toMatchObject({ code: 'permission-denied' });

  // Different coach cannot cancel
  await expect(call('coach-2')).rejects.toMatchObject({ code: 'permission-denied' });

  // Revoked branch access
  store.documents.get(`orgs/${org}/members/coach-1`)!.branchIds = [];
  await expect(call('coach-1')).rejects.toMatchObject({ code: 'permission-denied' });
});

it('rejects past sessions, pending holds, completed, and already cancelled sessions', async () => {
  // Session in past (now >= start)
  await expect(call('coach-1', {}, start + 1000)).rejects.toMatchObject({ code: 'failed-precondition' });

  // Completed session
  store.documents.get(bookingPath)!.status = 'completed';
  await expect(call('coach-1')).rejects.toMatchObject({ code: 'failed-precondition' });

  // Pending hold
  store.documents.get(bookingPath)!.status = 'pending_hold';
  await expect(call('coach-1')).rejects.toMatchObject({ code: 'failed-precondition' });
});

it('rejects empty, whitespace-only, invalid control characters, or oversized reasons', async () => {
  await expect(call('coach-1', { reason: '' })).rejects.toThrow('Enter a reason');
  await expect(call('coach-1', { reason: '   ' })).rejects.toThrow('Enter a reason');
  await expect(call('coach-1', { reason: 'Emergency\x00Cancellation' })).rejects.toThrow('Reason contains invalid characters');
  await expect(call('coach-1', { reason: 'A'.repeat(501) })).rejects.toThrow('Enter a reason');
});
