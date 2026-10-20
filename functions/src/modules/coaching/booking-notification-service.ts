import type { DocumentStore } from '../../platform/firestore/store';

export interface BookingNotificationEventData {
  schemaVersion: 1;
  type: string;
  bookingId: string;
  actorId: string;
  recipientId: string;
  atMillis: number;
  reason?: string;
  delivered?: boolean;
}

export async function deliverNotificationEvent(
  store: DocumentStore,
  org: string,
  eventId: string,
  clock = Date.now
): Promise<{ delivered: boolean }> {
  const eventPath = `orgs/${org}/bookingNotificationEvents/${eventId}`;
  const now = clock();

  return store.transact(async tx => {
    // 1. ALL READS FIRST
    const event = await tx.get(eventPath);
    if (!event || event.schemaVersion !== 1 || event.delivered === true) {
      return { delivered: false };
    }

    const memberId = String(event.recipientId);
    const bookingId = String(event.bookingId);
    const reason = typeof event.reason === 'string' ? event.reason : 'No reason provided';

    const root = `orgs/${org}/bookings/${bookingId}`;
    const statePath = `${root}/communicationState/current`;
    const state = await tx.get(statePath);

    // 2. ALL WRITES AFTER READS
    // Mark event as delivered
    tx.set(eventPath, {
      ...event,
      delivered: true,
      deliveredAtMillis: now,
    });

    // Deliver in-app notification to member's inbox
    const notificationPath = `orgs/${org}/members/${memberId}/notifications/${eventId}`;
    tx.set(notificationPath, {
      schemaVersion: 1,
      type: event.type,
      title: 'Session Cancelled by Coach',
      message: `Your coach has cancelled the session: ${reason}`,
      bookingId,
      createdAtMillis: now,
      read: false,
    });

    // Post notification update message into booking conversation thread if initialized
    if (state && state.schemaVersion === 1) {
      const nextSequence = Number(state.count || 0) + 1;
      tx.set(`${root}/messages/${nextSequence}`, {
        schemaVersion: 1,
        sequence: nextSequence,
        senderRole: 'coach',
        text: `[Automated Notice]: Session cancelled by coach. Reason: ${reason}`,
        sentAtMillis: now,
      });
      tx.set(statePath, {
        ...state,
        count: nextSequence,
        updatedAtMillis: now,
      });
    }

    return { delivered: true };
  });
}
