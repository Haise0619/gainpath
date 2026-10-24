import { FieldPath, getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { deliverNotificationEvent } from './booking-notification-service';

// Scan by document path, not delivered==false: legacy events omitted that field.
// A durable cursor ensures already delivered rows cannot starve older pending rows.
export const deliverBookingNotifications = onSchedule(
  { schedule: 'every 1 minutes', timeZone: 'UTC', maxInstances: 1, timeoutSeconds: 120 },
  async () => {
    const db = getFirestore(), cursorRef = db.doc('system/module9NotificationSweep');
    const cursor = (await cursorRef.get()).data()?.afterPath;
    let query = db.collectionGroup('bookingNotificationEvents').orderBy(FieldPath.documentId()).limit(100);
    if (typeof cursor === 'string') query = query.startAfter(db.doc(cursor));
    const rows = await query.get(), store = new FirestoreStore(db);
    for (const row of rows.docs) {
      const parts = row.ref.path.split('/');
      if (parts.length === 4 && parts[0] === 'orgs' && row.data().delivered !== true) {
        try { await deliverNotificationEvent(store, parts[1], parts[3]); }
        catch (error) { console.error('Booking notification delivery failed', row.ref.path, error); }
      }
    }
    await cursorRef.set({ afterPath: rows.size === 100 ? rows.docs.at(-1)!.ref.path : null });
  }
);
