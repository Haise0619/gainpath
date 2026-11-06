import {DomainError} from '../../platform/errors';
import type {InsightsRequest} from './exercise-insights-contracts';
import type {NotificationReader} from '../coaching/module9-member-service';
import type {RecommendationDeliveryDependencies} from './recommendation-member-contracts';
import {authorizeRecommendationSession,recommendationCommandError} from './recommendation-configuration';
import {deliveryNow,requireSyntheticDelivery} from './recommendation-delivery';
import {projectMemberRecommendation,requireRecommendationMember} from './recommendation-member-service';

/** Optional Module9 adapter. Default inbox composition never enables D on its own. */
export async function createRecommendationNoticeProjector(deps:RecommendationDeliveryDependencies,request:InsightsRequest):Promise<NonNullable<NotificationReader['projectRecommendation']>>{
  const initial=await authorizeRecommendationSession(request,deps);
  return async(org,uid,id,data)=>{
    try{
      requireSyntheticDelivery(deps,org);
      const auth=await authorizeRecommendationSession(request,deps);
      if(auth.uid!==initial.uid||uid!==auth.uid||data.recipientId!==uid||data.type!=='recommendation'||typeof data.recommendationId!=='string'||id!==`recommendation-${data.recommendationId}`)throw new DomainError('permission-denied','Recommendation unavailable.');
      const detail=await deps.store.transact(async tx=>{await requireRecommendationMember(tx,auth,org);return projectMemberRecommendation(tx,deps,auth,org,data.recommendationId as string,deliveryNow(deps));});
      await authorizeRecommendationSession(request,deps);
      return{title:detail.title,message:detail.summary,recommendation:{schemaVersion:1,recommendationId:detail.recommendationId,kind:detail.kind,state:detail.state,expiresAtMillis:detail.expiresAtMillis,target:detail.target}};
    }catch(error){throw recommendationCommandError(error);}
  };
}
