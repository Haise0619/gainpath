import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { InputValidationError } from '../../platform/validation';
import { readCoachIdentity } from './coach-identity-reader';
import { getMemberBookingOptionsService } from './member-booking-options-service';

export const getMemberBookingOptionsCommand = onCall({ enforceAppCheck: true }, async request => {
  try {
    return await getMemberBookingOptionsService(new FirestoreStore(getFirestore()), request.auth, request.data, readCoachIdentity);
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('internal', 'Booking options could not be loaded. Retry later.');
  }
});
