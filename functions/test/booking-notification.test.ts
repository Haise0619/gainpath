import { describe, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { deliverNotificationEvent } from '../src/modules/coaching/booking-notification-service';

describe('booking notification delivery service', () => {
  const org = 'org-1';
  const eventId = 'coachCancellation-booking-1-req-1';

  it('delivers notification to member inbox and updates communication thread', async () => {
    const store = new MemoryStore();
    const eventPath = `orgs/${org}/bookingNotificationEvents/${eventId}`;

    store.documents.set(eventPath, {
      schemaVersion: 1,
      type: 'coach_cancellation',
      bookingId: 'booking-1',
      actorId: 'coach-1',
      recipientId: 'member-1',
      atMillis: 1000,
      reason: 'Medical emergency',
    });

    // Communication thread initialized
    store.documents.set(`orgs/${org}/bookings/booking-1/communicationState/current`, {
      schemaVersion: 1,
      count: 2,
      updatedAtMillis: 900,
    });

    const result = await deliverNotificationEvent(store, org, eventId, () => 2000);
    expect(result.delivered).toBe(true);

    // Event marked delivered
    const updatedEvent = store.documents.get(eventPath);
    expect(updatedEvent?.delivered).toBe(true);
    expect(updatedEvent?.deliveredAtMillis).toBe(2000);

    // Member inbox receives notification
    const notification = store.documents.get(`orgs/${org}/members/member-1/notifications/${eventId}`);
    expect(notification).toMatchObject({
      schemaVersion: 1,
      type: 'coach_cancellation',
      title: 'Session Cancelled by Coach',
      message: 'Your coach has cancelled the session: Medical emergency',
      bookingId: 'booking-1',
      createdAtMillis: 2000,
      read: false,
    });

    // Communication thread receives notice
    const threadMsg = store.documents.get(`orgs/${org}/bookings/booking-1/messages/3`);
    expect(threadMsg).toMatchObject({
      schemaVersion: 1,
      sequence: 3,
      senderRole: 'coach',
      sentAtMillis: 2000,
    });
    expect(threadMsg?.text).toContain('Medical emergency');
  });

  it('ignores already delivered events idempotently', async () => {
    const store = new MemoryStore();
    const eventPath = `orgs/${org}/bookingNotificationEvents/${eventId}`;

    store.documents.set(eventPath, {
      schemaVersion: 1,
      type: 'coach_cancellation',
      bookingId: 'booking-1',
      actorId: 'coach-1',
      recipientId: 'member-1',
      atMillis: 1000,
      reason: 'Medical emergency',
      delivered: true,
      deliveredAtMillis: 1500,
    });

    const result = await deliverNotificationEvent(store, org, eventId, () => 2000);
    expect(result.delivered).toBe(false);
  });
});
