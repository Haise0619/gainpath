import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from './coach-profile-callables';
import { getClientPostureHistory, type WorkoutSessionQueryReader } from './client-posture-service';
import type { DocumentData } from '../../platform/firestore/store';

export class FirestoreWorkoutSessionReader implements WorkoutSessionQueryReader {
  constructor(private readonly db: Firestore) {}
  async readMemberSessions(org: string, memberId: string, limit = 20): Promise<DocumentData[]> {
    const snapshot = await this.db
      .collection(`orgs/${org}/workoutSessions`)
      .where('memberId', '==', memberId)
      .where('status', '==', 'accepted')
      .orderBy('endedAtMillis', 'desc')
      .limit(limit)
      .get();
    return snapshot.docs.map(doc => doc.data());
  }
}

export const getClientPostureHistoryCommand = onCall({ enforceAppCheck: true }, async request => {
  try {
    const db = getFirestore();
    return await getClientPostureHistory(
      new FirestoreStore(db),
      request.auth,
      request.data,
      new FirestoreWorkoutSessionReader(db)
    );
  } catch (error) {
    throw coachCommandError(error);
  }
});
