import { FieldPath, type Firestore } from 'firebase-admin/firestore';
import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { expireBookingHoldService } from './booking-lifecycle-service';

// Internal scheduler only. Never expose a client-supplied clock or cleanup UID.
// Each job transaction is independently idempotent; maxInstances is not a lock.
export async function runBookingExpiryBatch(db: Firestore, clock = Date.now) {
  const rows = await db.collectionGroup('jobs').where('schemaVersion', '==', 1)
    .where('type', '==', 'expireBookingHold').where('status', '==', 'pending')
    .where('dueAtMillis', '>', 0).where('dueAtMillis', '<=', clock())
    .orderBy('dueAtMillis').orderBy(FieldPath.documentId()).limit(50).get();
  const results = { scanned: rows.size, processed: 0, blocked: 0, retry: 0 };
  const store = new FirestoreStore(db);
  for (const row of rows.docs) {
    try { await expireBookingHoldService(store, row.ref.path, clock); results.processed++; }
    catch (error) {
      if (error instanceof DomainError && ['failed-precondition', 'not-found'].includes(error.code)) {
        // Quarantine only an unchanged due job, never cleanup malformed resources
        // or overwrite a concurrent completion. Store no raw exception details.
        await db.runTransaction(async tx => {
          const current = (await tx.get(row.ref)).data();
          if (current && JSON.stringify(current) === JSON.stringify(row.data())) tx.set(row.ref, { ...current, status: 'blocked', failureCode: 'authorized_review_required', processedAtMillis: clock() });
        });
        results.blocked++;
      } else results.retry++; // Transient infrastructure failure: still pending.
    }
  }
  return results;
}
export const expireBookingHolds = onSchedule({ schedule: 'every 1 minutes', timeZone: 'UTC', maxInstances: 1, timeoutSeconds: 120 }, async () => {
  try { logger.info('Booking expiry batch', await runBookingExpiryBatch(getFirestore())); }
  catch { throw new Error('Booking expiry infrastructure unavailable.'); }
});
