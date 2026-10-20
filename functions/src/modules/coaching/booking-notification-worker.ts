import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { deliverNotificationEvent } from './booking-notification-service';

export const deliverBookingNotificationWorker = onDocumentCreated(
  'orgs/{organizationId}/bookingNotificationEvents/{eventId}',
  async event => {
    const org = event.params.organizationId;
    const eventId = event.params.eventId;
    if (!org || !eventId) return;

    const db = getFirestore();
    const store = new FirestoreStore(db);
    await deliverNotificationEvent(store, org, eventId);
  }
);
