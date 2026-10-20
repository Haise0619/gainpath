import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from './coach-profile-callables';
import { bookingCommunication } from './booking-communication-service';

export const bookingCommunicationCommand = onCall({ enforceAppCheck: true }, async request => {
  try { return await bookingCommunication(new FirestoreStore(getFirestore()), request.auth, request.data); }
  catch (error) { throw coachCommandError(error); }
});
