import { AggregateField, FieldPath, getFirestore } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { requiredIdentifier } from '../../platform/validation';
import { currentBookingMembership, requireBookingOrganization } from '../coaching/booking-validation';
import { FirebaseRewardCoverStore } from '../gamification/reward-cover-storage';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from '../coaching/coach-profile-callables';
import { branchManagement } from './branch-management';
import { branchOperations, branchOperationsActions } from './branch-operations';

export const branchManagementCommand = onCall({ region: 'asia-southeast1', enforceAppCheck: true }, async request => {
  try {
    const db = getFirestore();
    const input = request.data;
    if (input?.action === 'branchStats') {
      requireVerifiedEmail(request.auth);
      const org = requiredIdentifier(input.organizationId, 'organizationId');
      const branchId = requiredIdentifier(input.branchId, 'branchId');
      const root = `orgs/${org}`;
      const store = new FirestoreStore(db);
      const authorize = () => store.transact(async tx => {
        await requireBookingOrganization(tx, org);
        if ((await currentBookingMembership(tx, org, request.auth!.uid)).role !== 'admin') {
          throw new HttpsError('permission-denied', 'Admin access is required.');
        }
        if (!await tx.get(`${root}/branches/${branchId}`)) {
          throw new HttpsError('not-found', 'Branch not found.');
        }
      });
      await authorize();
      const path = `${root}/branches/${branchId}`;
      const [coaches, equipment, bookings, visits] = await Promise.all([
        db.collection(`${root}/coaches`).where('branchIds', 'array-contains', branchId).count().get(),
        db.collection(`${path}/equipmentInventory`).aggregate({ units: AggregateField.sum('quantity') }).get(),
        db.collection(`${root}/bookings`).where('branchId', '==', branchId).count().get(),
        db.collection(`${path}/gymVisits`).count().get(),
      ]);
      await authorize();
      return { coaches: coaches.data().count, equipment: equipment.data().units,
        bookings: bookings.data().count, visits: visits.data().count };
    }
    if (input?.action === 'uploadBranchCover') {
      requireVerifiedEmail(request.auth);
      const org = requiredIdentifier(input.organizationId, 'organizationId');
      const uid = request.auth!.uid;
      const store = new FirestoreStore(db);
      const authorize = () => store.transact(async tx => {
        await requireBookingOrganization(tx, org);
        if ((await currentBookingMembership(tx, org, uid)).role !== 'admin') {
          throw new HttpsError('permission-denied', 'Admin access is required.');
        }
      });
      await authorize();
      const encoded = input.dataBase64;
      if (typeof encoded !== 'string' || encoded.length > 2796204) {
        throw new HttpsError('invalid-argument', 'Choose a JPG or PNG up to 2 MB.');
      }
      const bytes = Buffer.from(encoded, 'base64');
      const type = bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
        ? 'image/png' : bytes.subarray(0, 3).equals(Buffer.from([255, 216, 255])) ? 'image/jpeg' : undefined;
      if (!type || bytes.length > 2 * 1024 * 1024 || bytes.toString('base64') !== encoded) {
        throw new HttpsError('invalid-argument', 'Choose a valid JPG or PNG.');
      }
      const digest = createHash('sha256').update(bytes).digest('hex');
      const url = await new FirebaseRewardCoverStore().upload(
        `orgs/${org}/branchCovers/${digest}`, bytes, type, digest);
      await authorize();
      return { url };
    }
    if (input && typeof input === 'object' && branchOperationsActions.has(input.action)) {
      return await branchOperations(new FirestoreStore(db), async (path, order, afterId) => {
        const collection = db.collection(path);
        let query = order === 'recent'
          ? collection.orderBy('checkedInAtMillis', 'desc').orderBy(FieldPath.documentId(), 'desc')
          : collection.orderBy(FieldPath.documentId());
        if (afterId) {
          if (order === 'id') query = query.startAfter(afterId);
          else {
            const cursor = await collection.doc(afterId).get();
            if (!cursor.exists) return [];
            query = query.startAfter(cursor);
          }
        }
        const snapshot = await query.limit(31).get();
        return snapshot.docs.map(doc => ({ id: doc.id, data: doc.data() }));
      }, request.auth, input);
    }
    return await branchManagement(new FirestoreStore(db), async (org, activeOnly, afterId) => {
      const branches = db.collection(`orgs/${org}/branches`);
      let query = (activeOnly ? branches.where('status', '==', 'active') : branches)
        .orderBy(FieldPath.documentId()).limit(26);
      if (afterId) query = query.startAfter(afterId);
      const snapshot = await query.get();
      return snapshot.docs.map(doc => ({ id: doc.id, data: doc.data() }));
    }, request.auth, request.data);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw coachCommandError(error);
  }
});
