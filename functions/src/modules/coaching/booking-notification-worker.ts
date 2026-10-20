import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { deliverNotificationEvent } from './booking-notification-service';

export const deliverBookingNotifications = onSchedule(
  { schedule: 'every 1 minutes', timeZone: 'UTC', maxInstances: 1, timeoutSeconds: 120 },
  async () => {
    const db = getFirestore();
    const rows = await db
      .collectionGroup('bookingNotificationEvents')
      .where('schemaVersion', '==', 1)
      .where('delivered', '==', false)
      .limit(50)
      .get();

    const store = new FirestoreStore(db);
    for (const row of rows.docs) {
      const parts = row.ref.path.split('/');
      // path: orgs/{org}/bookingNotificationEvents/{eventId}
      if (parts[0] === 'orgs' && parts[1] && parts[3]) {
        try {
          await deliverNotificationEvent(store, parts[1], parts[3]);
        } catch (_) {}
      }
    }
  }
);
