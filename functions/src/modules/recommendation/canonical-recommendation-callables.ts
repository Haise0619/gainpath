import {replayWorkoutHistory} from './workout-backup-history';
import {workoutRecommendationDependencies,workoutRecommendationGeminiKey} from './workout-backup-recommendation-events';
import {getWorkoutBackupRuntime} from './workout-backup-recommendation-runtime';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {DomainError} from '../../platform/errors';
import {createCanonicalRecommendationBackend} from './canonical-recommendation-backend';
import type {InsightsRequest} from './exercise-insights-contracts';
import {createCanonicalRecommendationAdmin} from './canonical-recommendation-admin';
import {firestoreAdminAiReader} from './admin-ai-service';
import {createAdminAiProvider} from './admin-ai-assistance';

/** Prepared export only. No deployment or admission policy is authorized. */
export const module13MemberCommand = onCall({region: 'asia-southeast1', enforceAppCheck: true,
  secrets:[workoutRecommendationGeminiKey],
  timeoutSeconds: 30, maxInstances: 2, concurrency: 20}, async request => {
  try {
    const db = getFirestore();
    if (db.databaseId !== '(default)') throw new DomainError('failed-precondition', 'Canonical database required.');
    return await createCanonicalRecommendationBackend({replayHistory: (org, member, after) => replayWorkoutHistory(db, workoutRecommendationDependencies(), org, member, after),runtime:getWorkoutBackupRuntime(),store: new FirestoreStore(db), readAuthIdentity: async uid => {
      const user = await getAuth().getUser(uid);
      return {uid: user.uid, email: user.email ?? '', emailVerified: user.emailVerified, disabled: user.disabled,
        tokensValidAfterMillis: user.tokensValidAfterTime ? Date.parse(user.tokensValidAfterTime) : 0};
    }})(request as unknown as InsightsRequest);
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    throw new HttpsError('unavailable', 'Recommendations are temporarily unavailable.');
  }
});

export const module13AdminCommand = onCall({region:'asia-southeast1',enforceAppCheck:true,
  secrets:[workoutRecommendationGeminiKey],
  timeoutSeconds:30,maxInstances:2,concurrency:20},async request=>{
  try {
    const db=getFirestore(); if(db.databaseId!=='(default)')throw new DomainError('failed-precondition','Canonical database required.');
    return await createCanonicalRecommendationAdmin({runtime:getWorkoutBackupRuntime(),store:new FirestoreStore(db),aiReader:firestoreAdminAiReader(db),
      aiProvider:process.env.GEMINI_API_KEY?createAdminAiProvider({apiKey:process.env.GEMINI_API_KEY}):undefined,readAuthIdentity:async uid=>{
      const user=await getAuth().getUser(uid);return{uid:user.uid,email:user.email??'',emailVerified:user.emailVerified,disabled:user.disabled,
        tokensValidAfterMillis:user.tokensValidAfterTime?Date.parse(user.tokensValidAfterTime):0};
    }})(request as unknown as InsightsRequest);
  }catch(error){if(error instanceof DomainError)throw new HttpsError(error.code,error.message);throw new HttpsError('unavailable','Recommendations are temporarily unavailable.');}
});
