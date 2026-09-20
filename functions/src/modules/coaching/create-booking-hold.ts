import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { InputValidationError } from '../../platform/validation';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { createBookingHoldService } from './booking-service';
import { requireVerifiedEmail } from '../../platform/auth-context';

export const createBookingHold = onCall({ enforceAppCheck: true }, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  try {
    requireVerifiedEmail(request.auth);
    return await createBookingHoldService(new FirestoreStore(getFirestore()), request.auth.uid, request.data);
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('internal', 'The booking could not be created. Retry with the same requestId.');
  }
});
