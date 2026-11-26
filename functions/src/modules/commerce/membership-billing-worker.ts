import { FieldPath, type Firestore } from 'firebase-admin/firestore';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { member } from './membership-payment-service';
import { materializeMembershipBill } from './membership-billing';

export async function runMembershipBillingBatch(db: Firestore, org: string, now: number) {
  const cursor = db.doc('orgs/' + org + '/billingWorkers/renewalSweep');
  const saved = (await cursor.get()).data();
  let query = db.collection('orgs/' + org + '/membershipAccounts')
    .where('expiresAtMillis', '>', 0).where('expiresAtMillis', '<=', now)
    .orderBy('expiresAtMillis').orderBy(FieldPath.documentId()).limit(50);
  if (typeof saved?.expiresAtMillis === 'number' && typeof saved.uid === 'string') {
    query = query.startAfter(saved.expiresAtMillis, saved.uid);
  }
  const rows = await query.get();
  const store = new FirestoreStore(db);
  for (const row of rows.docs) {
    try {
      await store.transact(async tx => {
        await member(tx, org, row.id, undefined, false);
        await materializeMembershipBill(tx, org, row.id, now);
      });
    } catch (error) {
      if (!(error instanceof DomainError && ['permission-denied', 'failed-precondition', 'not-found'].includes(error.code))) throw error;
    }
  }
  const last = rows.size === 50 ? rows.docs.at(-1) : undefined;
  await cursor.set(last ? { expiresAtMillis: last.get('expiresAtMillis'), uid: last.id } : {});
  return rows.size;
}
