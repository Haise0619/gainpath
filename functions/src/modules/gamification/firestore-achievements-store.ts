import { FieldPath, type Firestore } from 'firebase-admin/firestore';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import type { AchievementStore } from './member-achievements';

export function firestoreAchievementsStore(db: Firestore): AchievementStore {
  const store = new FirestoreStore(db);
  return {
    transact: work => store.transact(work),
    page: async (path, after, limit) => {
      let query = db.collection(path).orderBy(FieldPath.documentId()).limit(limit);
      if (after !== null) query = query.startAfter(after);
      return (await query.get()).docs.map(doc => ({ id: doc.id, data: doc.data() }));
    },
  };
}
