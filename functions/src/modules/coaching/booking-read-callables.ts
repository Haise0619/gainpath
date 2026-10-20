import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { InputValidationError } from '../../platform/validation';
import { getBookingListService } from './booking-list-service';
import { FirestoreBookingQueryReader } from './booking-query-reader';

export const getBookingListCommand = onCall(async request => {
  try {
    const db = getFirestore();
    return await getBookingListService(new FirestoreStore(db), request.auth, request.data, new FirestoreBookingQueryReader(db));
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('internal', 'Bookings could not be loaded. Retry later.');
  }
});
