import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from './coach-profile-callables';
import { submitBookingReview } from './booking-review-service';

export const submitBookingReviewCommand = onCall({ enforceAppCheck: true }, async request => {
  try {
    return await submitBookingReview(
      new FirestoreStore(getFirestore()),
      request.auth,
      request.data
    );
  } catch (error) {
    throw coachCommandError(error);
  }
});
