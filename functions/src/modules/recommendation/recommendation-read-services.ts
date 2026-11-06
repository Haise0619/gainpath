import {DomainError} from '../../platform/errors';
import {InputValidationError,requiredIdentifier} from '../../platform/validation';
import {keys,object} from '../workouts/workout-backup-validation';
import type {InsightsRequest} from './exercise-insights-contracts';
import {authorizeRecommendationSession,defaultRecommendationConfiguration,parseRecommendationConfiguration,recommendationCommandError} from './recommendation-configuration';
import {parseRecommendationConsentV2} from './recommendation-consent-v2';
import {requireQueueAdmin} from './recommendation-queue-security';
import {requireRecommendationMember} from './recommendation-member-service';
import {deliveryNow,resolveCurrentRecommendation,validRecipientIdentity} from './recommendation-delivery';
import type {RecommendationDeliveryDependencies} from './recommendation-member-contracts';
import {parseRecommendationLead,parseQueueGenerationSummary,queueFailure,type RecommendationLead} from './recommendation-queue-contracts';

/** Production-shaped read libraries, never callable registrations. No source scan or mutation. */
export function createRecommendationReadServices(deps:RecommendationDeliveryDependencies&{
 readonly validateTarget?:(tx:Parameters<RecommendationDeliveryDependencies['resolveTarget']>[0],lead:RecommendationLead)=>Promise<'valid'|'stale'>;
}){
 const query=(request:InsightsRequest,version:number,extra:string[]=[])=>{
  const q=object(request.data);keys(q,['schemaVersion','organizationId',...extra]);
  if(q.schemaVersion!==version)throw new InputValidationError('Unsupported version.');
  requiredIdentifier(q.organizationId,'organization');for(const k of extra)requiredIdentifier(q[k],k);return q;
 };
 const safe=<T>(work:()=>Promise<T>)=>work().catch(error=>{throw recommendationCommandError(error);});
 return{
  configuration:(request:InsightsRequest)=>safe(async()=>{
   const q=query(request,1),org=String(q.organizationId),auth=await authorizeRecommendationSession(request,deps);
   return deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);const raw=await tx.get(`orgs/${org}/recommendationConfiguration/current`);
    return raw?parseRecommendationConfiguration(raw,org):defaultRecommendationConfiguration(org);});
  }),
  consent:(request:InsightsRequest)=>safe(async()=>{
   const q=query(request,2),org=String(q.organizationId),auth=await authorizeRecommendationSession(request,deps),now=deliveryNow(deps);
   return deps.store.transact(async tx=>{await requireRecommendationMember(tx,auth,org);const raw=await tx.get(`orgs/${org}/recommendationConsent/${auth.uid}`);
    return raw?structuredClone(parseRecommendationConsentV2(raw,{organizationId:org,memberId:auth.uid},now)):null;});
  }),
  status:(request:InsightsRequest)=>safe(async()=>{
   const q=query(request,1,['runId']),org=String(q.organizationId),auth=await authorizeRecommendationSession(request,deps);
   return deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);const raw=await tx.get(`orgs/${org}/recommendationRuns/${q.runId}`);
    if(!raw||raw.schemaVersion!==1)throw queueFailure();let summary;try{summary=parseQueueGenerationSummary(raw.summary);}catch{throw queueFailure();}
    if(summary.runId!==q.runId||summary.updatedAtMillis>deliveryNow(deps))throw queueFailure();
    return{schemaVersion:1 as const,mode:'synthetic_local' as const,organizationId:org,summary};});
  }),
  lead:(request:InsightsRequest)=>safe(async()=>{
   const q=query(request,1,['leadId']),org=String(q.organizationId),auth=await authorizeRecommendationSession(request,deps),now=deliveryNow(deps);
   const lead=await deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);return parseRecommendationLead(await tx.get(`orgs/${org}/recommendationLeads/${q.leadId}`),org);});
   if(lead.leadId!==q.leadId||!validRecipientIdentity(await deps.readAuthIdentity(lead.memberId),lead.memberId))throw queueFailure();
   await authorizeRecommendationSession(request,deps);
   const currentNow=deliveryNow(deps,now);
   return deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);const current=parseRecommendationLead(await tx.get(`orgs/${org}/recommendationLeads/${q.leadId}`),org);
    if(current.revision!==lead.revision||current.sourceFingerprint!==lead.sourceFingerprint||current.createdAtMillis>currentNow||current.expiresAtMillis<=currentNow||
     deps.validateTarget&&await deps.validateTarget(tx,current)!=='valid'||!await resolveCurrentRecommendation(tx,deps,current,currentNow))throw queueFailure();
    await requireQueueAdmin(tx,auth,org);return{schemaVersion:1 as const,mode:'synthetic_local' as const,organizationId:org,lead:current};});
  }),
 };
}
