import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { InputValidationError } from '../../platform/validation';
import { cancelAssignedBookingService } from './coach-booking-cancellation-service';

export const cancelAssignedBookingCommand = onCall({ enforceAppCheck: true }, async request => {
  try {
    return await cancelAssignedBookingService(new FirestoreStore(getFirestore()), request.auth, request.data);
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('internal', 'Cancellation outcome is unknown. Retry the same request.');
  }
});
