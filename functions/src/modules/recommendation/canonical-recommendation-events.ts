import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {getReviewedCanonicalRuntime} from './canonical-recommendation-runtime';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {CANONICAL_RECOMMENDATION_RELEASE} from './canonical-recommendation-backend';
import {createCanonicalRecommendationLifecycle,type CanonicalLifecycleDependencies} from './canonical-recommendation-lifecycle';

/** Server-event seam. Event payload is not treated as capture authority. The
 * lifecycle rereads accepted summary + receipt and gates history before scans. */
export function createAcceptedWorkoutRecommendationHandler(deps: CanonicalLifecycleDependencies) {
  return async(event:{organizationId:string;memberId:string;acceptedId:string}) =>
    createCanonicalRecommendationLifecycle(deps).accepted(event.organizationId,event.memberId,event.acceptedId);
}
/** Recovery receives only bounded server-discovered prepared IDs. Successful
 * and response-lost retries converge through the atomic delivery receipt. */
export function createCanonicalDeliveryRecovery(deps:CanonicalLifecycleDependencies) {
  return async(org:string,ids:readonly string[])=>{
    if(ids.length>25||new Set(ids).size!==ids.length)throw Error('Bounded unique recovery batch required.');
    const lifecycle=createCanonicalRecommendationLifecycle(deps),results:{id:string;status:'delivered'|'blocked'|'retry'}[]=[];
    for(const id of ids)try{await lifecycle.deliver(org,id);results.push({id,status:'delivered'});}catch(error){
      const code=(error as {code?:string}).code;
      results.push({id,status:code==='failed-precondition'||code==='permission-denied'?'blocked':'retry'});
    }
    return results;
  };
}
export function createCanonicalDeliveryRecoverySweep(deps:CanonicalLifecycleDependencies&{
  listPrepared:()=>Promise<readonly {organizationId:string;id:string}[]>}) {
  return async()=>{
    const rows=await deps.listPrepared();if(rows.length>25||new Set(rows.map(r=>`${r.organizationId}/${r.id}`)).size!==rows.length)throw Error('Bounded unique prepared batch required.');
    const recover=createCanonicalDeliveryRecovery(deps),results:{organizationId:string;id:string;status:'delivered'|'blocked'|'retry'}[]=[];
    for(const row of rows)for(const result of await recover(row.organizationId,[row.id]))results.push({...result,organizationId:row.organizationId});
    return results;
  };
}
/** Export prepared for a separately reviewed release. No source data is read
 * and no write/provider call occurs while canonical admission is disabled. */
export const module13AcceptedWorkoutCreated=onDocumentCreated({region:'asia-southeast1',
  document:'orgs/{organizationId}/workoutSessions/{acceptedId}',retry:true,maxInstances:2},async event=>{
  if(!CANONICAL_RECOMMENDATION_RELEASE.enabled)return;
  const deps=reviewedDependencies();if(!deps)return;
  const memberId=event.data?.data().memberId;if(typeof memberId!=='string')return;
  await createAcceptedWorkoutRecommendationHandler(deps)({organizationId:event.params.organizationId,memberId,acceptedId:event.params.acceptedId});
});

/** Disabled until a reviewed prepared-only bounded reader and lifecycle runtime
 * are composed. A failed record never stops independent authorized deliveries. */
export const module13RecoverDeliveries=onSchedule({region:'asia-southeast1',schedule:'every 15 minutes',
  timeZone:'Asia/Kuala_Lumpur',maxInstances:1,timeoutSeconds:120},async()=>{
  if(!CANONICAL_RECOMMENDATION_RELEASE.enabled)return;
  const deps=reviewedDependencies();if(!deps)return;
  const db=getFirestore();
  await createCanonicalDeliveryRecoverySweep({...deps,listPrepared:async()=>{
    const rows=await db.collectionGroup('canonicalRecommendations').where('mode','==','accepted_workout').where('status','==','prepared').limit(25).get();
    return rows.docs.filter(d=>/^orgs\/[^/]+\/canonicalRecommendations\/[a-f0-9]{64}$/.test(d.ref.path))
      .map(d=>({organizationId:d.ref.path.split('/')[1],id:d.id}));
  }})();
});

function reviewedDependencies():CanonicalLifecycleDependencies|undefined {
 const runtime=getReviewedCanonicalRuntime();if(!runtime)return undefined;
 const db=getFirestore();if(db.databaseId!=='(default)')throw Error('Canonical database required.');
 return{runtime,store:new FirestoreStore(db),readAuthIdentity:async uid=>{
  const user=await getAuth().getUser(uid);return{uid:user.uid,email:user.email??'',emailVerified:user.emailVerified,disabled:user.disabled,tokensValidAfterMillis:user.tokensValidAfterTime?Date.parse(user.tokensValidAfterTime):0};
 }};
}
