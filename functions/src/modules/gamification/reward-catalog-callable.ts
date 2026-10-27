import {getFirestore} from 'firebase-admin/firestore';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {DomainError} from '../../platform/errors';
import {InputValidationError} from '../../platform/validation';
import {rewardRequest, freshRewardAuth} from './reward-command-security';
import {rewardCatalogCommand as execute} from './reward-catalog-service';
import {uploadRewardCover} from './reward-cover-upload';
import {FirebaseRewardCoverStore} from './reward-cover-storage';
import {workoutRewardConfiguration} from './workout-rewards';
export const rewardCatalogCommand = onCall({region: 'asia-southeast1', enforceAppCheck: true, timeoutSeconds: 60, maxInstances: 5}, async request => {
  try {
    const auth = await rewardRequest(request);
    const store=new FirestoreStore(getFirestore());
    const result = ['workoutRewardOverview','saveWorkoutRewardDraft'].includes(request.data?.action)
      ? await workoutRewardConfiguration(store,auth,request.data)
      : request.data?.action==='uploadCover'
      ? await uploadRewardCover(store,auth,request.data,new FirebaseRewardCoverStore())
      : await execute(store, auth, request.data);
    await freshRewardAuth(auth); return result;
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('unavailable', 'Reward publication could not be confirmed. Retry the same request.');
  }
});
