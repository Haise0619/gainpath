import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {defineString} from 'firebase-functions/params';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {InputValidationError} from '../../platform/validation';
import {miniGameContent, type MiniGameAuth} from './mini-game-content';
import {FirebaseMiniGameMediaStore} from './mini-game-content-storage';

const organization = defineString('MINI_GAME_CONTENT_ORGANIZATION_ID', {default: 'gainpath'});
async function freshAuth(auth: MiniGameAuth) {
  if (typeof auth.token.email !== 'string' || !Number.isSafeInteger(auth.token.auth_time) || Number(auth.token.auth_time) < 0) {
    throw new DomainError('unauthenticated', 'Sign in again with a verified account.');
  }
  const user = await getAuth().getUser(auth.uid), validAfter = user.tokensValidAfterTime ? Date.parse(user.tokensValidAfterTime) : 0;
  if (user.disabled || !user.emailVerified || user.email !== auth.token.email || !Number.isFinite(validAfter)
      || Number(auth.token.auth_time) * 1000 < validAfter) throw new DomainError('unauthenticated', 'Your account session changed.');
}

/** Prepared local endpoint. Release/export from the root entrypoint is separately reviewed. */
export const miniGameContentCommand = onCall({region: 'asia-southeast1', enforceAppCheck: true, timeoutSeconds: 60, maxInstances: 5, memory: '512MiB', concurrency: 1}, async request => {
  try {
    if (!request.app) throw new DomainError('unauthenticated', 'App verification required.');
    requireVerifiedEmail(request.auth);
    const org = organization.value();
    if (!org || (request.data as Record<string, unknown> | null)?.organizationId !== org) throw new DomainError('permission-denied', 'Mini-game content organization unavailable.');
    return await miniGameContent(new FirestoreStore(getFirestore()), request.auth, request.data, {media: new FirebaseMiniGameMediaStore(), freshAuth});
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('unavailable', 'Mini-game content could not be confirmed. Retry the same request.');
  }
});
