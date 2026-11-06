import {getAuth} from 'firebase-admin/auth';
import {requireCurrentLifecycleIdentity} from '../identity/member-account-lifecycle-callables';
import {FirebaseCatalogMediaVerifier} from './exercise-catalog-callable';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { InputValidationError } from '../../platform/validation';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { publishRoutine } from './publish-routine';

export const publishRoutineCommand = onCall({enforceAppCheck:true},async request => {
  try {
    return await publishRoutine(
      new FirestoreStore(getFirestore()),
      request.auth ? { uid: request.auth.uid, token: request.auth.token } : undefined,
      request.data,
      Date.now,
      {media:new FirebaseCatalogMediaVerifier(),freshAuth:async auth=>{await requireCurrentLifecycleIdentity(auth,uid=>getAuth().getUser(uid));}},
    );
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('internal', 'The routine could not be published. Retry with the same requestId.');
  }
});
