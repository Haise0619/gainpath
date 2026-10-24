import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from './coach-profile-callables';
import { FirestoreBookingQueryReader } from './booking-query-reader';
import { coachPerformance } from './coach-performance-service';
export const getCoachPerformanceCommand = onCall({ enforceAppCheck: true, timeoutSeconds: 120 }, async request => {
  try { const db = getFirestore(); return await coachPerformance(new FirestoreStore(db), request.auth, request.data, new FirestoreBookingQueryReader(db)); }
  catch (error) { throw coachCommandError(error); }
});
