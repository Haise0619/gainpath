import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {InputValidationError} from '../../platform/validation';
import {freshRewardAuth, rewardsOrganization} from './reward-command-security';
import {MINI_GAME_REWARD_ACCEPTED_VERIFICATION_VERSIONS, MINI_GAME_REWARD_RELEASE_APPROVED} from './mini-game-reward-policy';
import {miniGameRewards} from './mini-game-rewards';
import {miniGameParticipation,MINI_GAME_PARTICIPATION_RELEASE_APPROVED} from './mini-game-participation';

/** Local preparation only. Deliberately unexported from the root deployment entrypoint. */
export const miniGameRewardsCommand = onCall({region: 'asia-southeast1', enforceAppCheck: true, timeoutSeconds: 60, maxInstances: 5, memory: '512MiB', concurrency: 1}, async request => {
  try {
    if (!request.app) throw new DomainError('unauthenticated', 'App verification required.');
    requireVerifiedEmail(request.auth);
    const organizationId = rewardsOrganization.value();
    if (!organizationId || (request.data as Record<string, unknown> | null)?.organizationId !== organizationId) throw new DomainError('permission-denied', 'Mini-game rewards organization unavailable.');
    if (['participationOverview','claimParticipation'].includes(String((request.data as Record<string,unknown> | null)?.action))) {
      return await miniGameParticipation(new FirestoreStore(getFirestore()),request.auth,request.data,
        {freshAuth:freshRewardAuth,releaseApproved:MINI_GAME_PARTICIPATION_RELEASE_APPROVED});
    }
    return await miniGameRewards(new FirestoreStore(getFirestore()), request.auth, request.data, {freshAuth: freshRewardAuth,
      releaseApproved: MINI_GAME_REWARD_RELEASE_APPROVED, acceptedVerificationVersions: MINI_GAME_REWARD_ACCEPTED_VERIFICATION_VERSIONS});
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('unavailable', 'Mini-game reward status could not be confirmed. Retry the same request.');
  }
});
