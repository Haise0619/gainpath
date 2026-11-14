import type {InsightsRequest} from './exercise-insights-contracts';
import type {NotificationReader} from '../coaching/module9-member-service';
import {DomainError} from '../../platform/errors';
import {digestOf} from '../workouts/workout-backup-validation';
import {authorizeRecommendationSession} from './recommendation-configuration';
import {createCanonicalRecommendationLifecycle,type CanonicalLifecycleDependencies} from './canonical-recommendation-lifecycle';
/** Module9 uses the same current, consent-redacted projection as Home. */
export async function createCanonicalNoticeProjector(deps:CanonicalLifecycleDependencies,request:InsightsRequest):Promise<NonNullable<NotificationReader['projectRecommendation']>> {
 const initial=await authorizeRecommendationSession(request,deps);
 return async(org,uid,id,data)=>{
  const auth=await authorizeRecommendationSession(request,deps);
  if(auth.uid!==initial.uid||uid!==auth.uid||data.recipientId!==uid||!['accepted_workout','workout_backup'].includes(String(data.mode))||data.type!=='recommendation'||typeof data.recommendationId!=='string'||id!==digestOf({canonicalRecommendation:data.recommendationId}))throw new DomainError('permission-denied','Recommendation unavailable.');
  const detail=await createCanonicalRecommendationLifecycle(deps).member(auth,org,data.recommendationId,'get',null,null);
  await authorizeRecommendationSession(request,deps);
  return{title:detail.title,message:detail.summary,recommendation:{schemaVersion:1,recommendationId:detail.recommendationId,kind:detail.kind,state:detail.state,expiresAtMillis:detail.expiresAtMillis,target:detail.target}};
 };
}
