import { FieldPath, type Firestore, type Query } from 'firebase-admin/firestore';
import type { BookingQuery, BookingQueryReader } from './booking-list-service';

// Admin queries bypass Rules. Only call through the pre/post-authorized service.
export class FirestoreBookingQueryReader implements BookingQueryReader {
  constructor(private readonly db: Firestore) {}
  async read(input: BookingQuery) {
    let q: Query = this.db.collection(`orgs/${input.organizationId}/bookings`).where(input.ownerField, '==', input.ownerId);
    if (input.branchIds !== undefined) q = q.where('branchId', 'in', [...input.branchIds]);
    q = q.where('startAtMillis', '>=', input.firstStartAtMillis).where('startAtMillis', '<', input.throughStartAtMillis)
      .orderBy('startAtMillis', 'asc').orderBy(FieldPath.documentId(), 'asc');
    if (input.cursor) q = q.startAfter(input.cursor.startAtMillis, input.cursor.bookingId);
    const result = await q.limit(input.limit).get();
    return result.docs.map(doc => ({ path: doc.ref.path, data: doc.data() }));
  }
}
