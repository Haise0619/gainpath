import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { InputValidationError } from '../../platform/validation';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { readCoachIdentity } from './coach-identity-reader';
import { saveCoachProfile, setCoachDirectoryStatus } from './coach-profile-service';

export function coachCommandError(error: unknown): HttpsError {
  if (error instanceof DomainError) return new HttpsError(error.code, error.message);
  if (error instanceof InputValidationError) return new HttpsError('invalid-argument', error.message);
  return new HttpsError('internal', 'The Coach operation could not complete. Retry with the same request ID.');
}
export const saveCoachProfileCommand = onCall(async request => {
  try { return await saveCoachProfile(new FirestoreStore(getFirestore()), request.auth, request.data); }
  catch (error) { throw coachCommandError(error); }
});
export const setCoachDirectoryStatusCommand = onCall(async request => {
  try { return await setCoachDirectoryStatus(new FirestoreStore(getFirestore()), request.auth, request.data, readCoachIdentity); }
  catch (error) { throw coachCommandError(error); }
});
