import { FieldPath, getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from '../coaching/coach-profile-callables';
import { branchManagement } from './branch-management';

export const branchManagementCommand = onCall({ region: 'asia-southeast1', enforceAppCheck: true }, async request => {
  try {
    const db = getFirestore();
    return await branchManagement(new FirestoreStore(db), async (org, activeOnly, afterId) => {
      const branches = db.collection(`orgs/${org}/branches`);
      let query = (activeOnly ? branches.where('status', '==', 'active') : branches)
        .orderBy(FieldPath.documentId()).limit(26);
      if (afterId) query = query.startAfter(afterId);
      const snapshot = await query.get();
      return snapshot.docs.map(doc => ({ id: doc.id, data: doc.data() }));
    }, request.auth, request.data);
  } catch (error) { throw coachCommandError(error); }
});
