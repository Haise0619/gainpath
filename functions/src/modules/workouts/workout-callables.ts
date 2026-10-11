import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall, type CallableRequest } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { InputValidationError } from '../../platform/validation';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { acknowledgeWorkoutConsent, revokeWorkoutConsent, submitWorkoutSession, type WorkoutAuth } from './workout-service';
import type { DocumentStore } from '../../platform/firestore/store';

async function call<T>(request: CallableRequest, action: (store: DocumentStore, auth: WorkoutAuth | undefined, data: unknown) => Promise<T>): Promise<T> {
  try {
    return await action(new FirestoreStore(getFirestore()), request.auth ? { uid: request.auth.uid, token: request.auth.token } : undefined, request.data);
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('internal', 'Workout operation failed. Retry using the same requestId.');
  }
}
export const acknowledgeWorkoutConsentCommand = onCall(request => call(request, acknowledgeWorkoutConsent));
export const revokeWorkoutConsentCommand = onCall(request => call(request, revokeWorkoutConsent));
// No caller-controlled policy injection: production's enabled list stays empty.
export const submitWorkoutSessionCommand = onCall(request => call(request,
  (store, auth, data) => submitWorkoutSession(store, auth, data)));
