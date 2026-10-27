import {getFirestore} from 'firebase-admin/firestore';
import {onCall,HttpsError} from 'firebase-functions/v2/https';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {DomainError} from '../../platform/errors';
import {InputValidationError} from '../../platform/validation';
import {rewardRequest,freshRewardAuth} from './reward-command-security';
import {workoutRewardCommand as execute} from './workout-rewards';
import {WORKOUT_REWARD_PHYSICAL_RELEASE_APPROVED} from './workout-reward-policy';
import {ENABLED_WORKOUT_TUPLES} from '../workouts/workout-service';
// Deliberately not exported from index.ts: local preparation only.
export const workoutRewardCommand=onCall({region:'asia-southeast1',enforceAppCheck:true,timeoutSeconds:60,maxInstances:5},async request=>{
 try{const auth=await rewardRequest(request);const result=await execute(new FirestoreStore(getFirestore()),auth,request.data,{physicalValidationApproved:WORKOUT_REWARD_PHYSICAL_RELEASE_APPROVED,enabledTuples:ENABLED_WORKOUT_TUPLES});await freshRewardAuth(auth);return result;}
 catch(error){if(error instanceof DomainError)throw new HttpsError(error.code,error.message);if(error instanceof InputValidationError)throw new HttpsError('invalid-argument',error.message);throw new HttpsError('unavailable','Workout reward status unavailable. No award was confirmed.');}
});
