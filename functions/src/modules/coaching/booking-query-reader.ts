import { FieldPath, type Firestore, type Query } from 'firebase-admin/firestore';
import type { BookingQuery, BookingQueryReader } from './booking-list-service';
import { DomainError } from '../../platform/errors';

// Admin queries bypass Rules. Only call through the pre/post-authorized service.
export class FirestoreBookingQueryReader implements BookingQueryReader {
  constructor(private readonly db: Firestore) {}
  async read(input: BookingQuery) {
    let q: Query = this.db.collection(`orgs/${input.organizationId}/bookings`).where(input.ownerField, '==', input.ownerId);
    if (input.ownerField === 'branchId') {
      const snapshot = await q.limit(1501).get();
      if (snapshot.size > 1500) throw new DomainError('resource-exhausted', 'Branch booking history exceeds the review limit.');
      const rows = snapshot.docs.map(doc => ({ path: doc.ref.path, id: doc.id, data: doc.data() }));
      return rows.filter(row => typeof row.data.startAtMillis === 'number'
        && row.data.startAtMillis >= input.firstStartAtMillis
        && row.data.startAtMillis < input.throughStartAtMillis
        && (!input.cursor || row.data.startAtMillis > input.cursor.startAtMillis
          || (row.data.startAtMillis === input.cursor.startAtMillis && row.id > input.cursor.bookingId)))
        .sort((a, b) => a.data.startAtMillis - b.data.startAtMillis || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
        .slice(0, input.limit);
    }
    if (input.branchIds !== undefined) q = q.where('branchId', 'in', [...input.branchIds]);
    q = q.where('startAtMillis', '>=', input.firstStartAtMillis).where('startAtMillis', '<', input.throughStartAtMillis)
      .orderBy('startAtMillis', 'asc').orderBy(FieldPath.documentId(), 'asc');
    if (input.cursor) q = q.startAfter(input.cursor.startAtMillis, input.cursor.bookingId);
    const result = await q.limit(input.limit).get();
    return result.docs.map(doc => ({ path: doc.ref.path, data: doc.data() }));
  }
}
