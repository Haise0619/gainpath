import { FieldPath, getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from './coach-profile-callables';
import { module9MemberCommand } from './module9-member-service';
export const module9MemberCommandCallable = onCall({ enforceAppCheck: true }, async request => {
  try {
    const db = getFirestore();
    return await module9MemberCommand(new FirestoreStore(db), request.auth, request.data, Date.now, {
      list: async (org, uid, afterId) => {
        let query = db.collection(`orgs/${org}/notifications`).where('recipientId', '==', uid).orderBy('createdAtMillis', 'desc').orderBy(FieldPath.documentId(), 'desc');
        if (afterId) {
          const cursor = await db.doc(`orgs/${org}/notifications/${afterId}`).get();
          if (!cursor.exists || cursor.data()?.recipientId !== uid) throw new Error('Invalid notification cursor');
          query = query.startAfter(cursor);
        }
        return (await query.limit(31).get()).docs.map(d => ({ id: d.id, data: d.data() }));
      },
    });
  } catch (e) { throw coachCommandError(e); }
});
