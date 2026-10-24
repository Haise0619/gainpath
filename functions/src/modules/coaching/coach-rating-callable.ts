import { AggregateField, getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from './coach-profile-callables';
import { coachRatings } from './coach-rating-service';
export const getCoachRatingsCommand = onCall({ enforceAppCheck: true }, async request => {
  try { const db = getFirestore(); return await coachRatings(new FirestoreStore(db), request.auth, request.data, {
    aggregate: async (org, id) => {
      const data = (await db.collection(`orgs/${org}/coaches/${id}/reviews`).where('stars', '>=', 1).where('stars', '<=', 5)
        .aggregate({ count: AggregateField.count(), total: AggregateField.sum('stars') }).get()).data();
      return { count: data.count, total: data.total };
    },
  }); } catch (error) { throw coachCommandError(error); }
});
