import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {InputValidationError} from '../../platform/validation';
import {freshRewardAuth, rewardsOrganization} from './reward-command-security';
import {miniGameRounds} from './mini-game-rounds';

/** Local candidate only; deliberately not exported from the deployment entrypoint. */
export const miniGameRoundCommand = onCall({region:'asia-southeast1', enforceAppCheck:true,
  timeoutSeconds:30, maxInstances:5, memory:'512MiB', concurrency:1}, async request => {
  try {
    if (!request.app) throw new DomainError('unauthenticated', 'App verification required.');
    requireVerifiedEmail(request.auth);
    const org = rewardsOrganization.value();
    if (!org || (request.data as Record<string,unknown> | null)?.organizationId !== org) throw new DomainError('permission-denied','Round organization unavailable.');
    return await miniGameRounds(new FirestoreStore(getFirestore()), request.auth, request.data, {freshAuth:freshRewardAuth});
  } catch (e) {
    if (e instanceof DomainError) throw new HttpsError(e.code,e.message);
    if (e instanceof InputValidationError) throw new HttpsError('invalid-argument',e.message);
    throw new HttpsError('unavailable','Round timing could not be confirmed. Retry the same command.');
  }
});
