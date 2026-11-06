import {DomainError} from '../../platform/errors';
import type {DocumentData} from '../../platform/firestore/store';
import {InputValidationError,requiredIdentifier} from '../../platform/validation';
import {keys,object} from '../workouts/workout-backup-validation';
import type {InsightsRequest} from './exercise-insights-contracts';
import {authorizeRecommendationSession,recommendationCommandError} from './recommendation-configuration';
import {parseRecommendationLead,parseQueueGenerationSummary,queueInteger,queueText,QUEUE_STATUSES,type RecommendationLead,type QueueGenerationSummary,type RecommendationQueuePage,type RecommendationQueueQuery} from './recommendation-queue-contracts';
import {authorizeQueue,requireQueueAdmin,readRecommendationMemberState,type QueueSecurityDependencies} from './recommendation-queue-security';

import {recommendationPurposes,validRecipientIdentity} from './recommendation-delivery';
export interface QueuePageReader {readLeads(organizationId:string,afterLeadId:string|null,limit:number):Promise<{id:string;data:DocumentData}[]>}
function parseQuery(raw:unknown,now:number):RecommendationQueueQuery{
  const q=object(raw);keys(q,['schemaVersion','organizationId','kind','status','startAtMillis','endAtMillis','exerciseId','category','specialization','afterLeadId','limit']);
  if(q.schemaVersion!==1||(q.kind!=='trainer'&&q.kind!=='content')||(q.status!=='all'&&!QUEUE_STATUSES.includes(q.status as any))||!queueInteger(q.startAtMillis)||!queueInteger(q.endAtMillis,1)||q.startAtMillis>=q.endAtMillis||q.endAtMillis>now||q.endAtMillis-q.startAtMillis>90*86400000||!queueInteger(q.limit,1)||q.limit>25)throw new InputValidationError('Invalid bounded queue query.');
  for(const k of ['exerciseId','afterLeadId'])if(q[k]!==null)requiredIdentifier(q[k],k);
  for(const k of ['category','specialization'])if(q[k]!==null&&!queueText(q[k],120))throw new InputValidationError('Invalid filter.');
  return q as unknown as RecommendationQueueQuery;
}
function generationSummary(raw:unknown,kind:string):QueueGenerationSummary|null{
  if(raw===undefined)return null;const state=object(raw);keys(state,['schemaVersion','summary']);if(state.schemaVersion!==1)throw Error();const s=object(state.summary);
  keys(s,['runId','kind','status','processed','candidateCount','generated','abstained','fallbackCount','nextCursor','failureCode','algorithmVersion','model','updatedAtMillis','abstentionReasons']);
  return parseQueueGenerationSummary(s,kind as 'trainer'|'content');
}
/** Bounded on-demand view, all filters before stable page slicing; no raw histories. */
export function createRecommendationQueueList(deps:QueueSecurityDependencies&{reader:QueuePageReader}){
  return async(request:InsightsRequest):Promise<RecommendationQueuePage>=>{
    try{
      const ctx=await authorizeQueue(request,deps),q=parseQuery(request.data,ctx.now),all:RecommendationLead[]=[];let after:string|null=null;
      for(;;){const page=await deps.reader.readLeads(ctx.organizationId,after,26);if(!Array.isArray(page)||page.length>26)throw Error();for(const row of page){if(!row||typeof row.id!=='string'||(after!==null&&row.id<=after))throw Error();const lead=parseRecommendationLead(row.data,ctx.organizationId);if(lead.leadId!==row.id)throw Error();all.push(lead);after=row.id;if(all.length>100)throw new DomainError('resource-exhausted','Queue source exceeds local read bounds.');}if(page.length<26)break;}
      // Never release retained labels, evidence, facets or complements after purpose
      // revocation. No redacted lead wire shape is approved: refuse the whole list.
      await authorizeRecommendationSession(request,deps);
      const memberIds=[...new Set(all.filter(l=>l.kind===q.kind).map(l=>l.memberId))];
      for(const uid of memberIds)if(!validRecipientIdentity(await deps.readAuthIdentity(uid),uid))throw new DomainError('permission-denied','Current recommendation purposes are required.');
      const verifiedAt=(deps.clock??Date.now)();if(!queueInteger(verifiedAt,ctx.now)||verifiedAt>8640000000000000)throw new DomainError('unavailable','Invalid queue clock.');
      const generation=await deps.store.transact(async tx=>{
        await requireQueueAdmin(tx,ctx.auth,ctx.organizationId);
        for(const lead of all.filter(l=>l.kind===q.kind)){
          const purposes=recommendationPurposes(lead).filter(p=>p!=='recommendationDelivery');
          if(!(await readRecommendationMemberState(tx,{organizationId:ctx.organizationId,memberId:lead.memberId},verifiedAt,deps.noticePolicies??[],purposes)).eligible)throw new DomainError('permission-denied','Current recommendation purposes are required.');
        }
        return generationSummary(await tx.get(`orgs/${ctx.organizationId}/recommendationGenerationState/${q.kind}`),q.kind);
      });
      const capturedAt=(deps.clock??Date.now)();if(!queueInteger(capturedAt,verifiedAt)||capturedAt>8640000000000000)throw new DomainError('unavailable','Invalid queue clock.');
      const kindRows=all.filter(l=>l.kind===q.kind),facets={exercises:[...new Map(kindRows.map(l=>[l.exerciseId,{id:l.exerciseId,label:l.exerciseLabel}])).values()].sort((a,b)=>a.id<b.id?-1:1),categories:[...new Set(kindRows.map(l=>l.category))].sort(),specializations:[...new Set(kindRows.flatMap(l=>l.specialization===null?[]:[l.specialization]))].sort()};
      const filtered=kindRows.filter(l=>l.createdAtMillis>=q.startAtMillis&&l.createdAtMillis<q.endAtMillis&&(q.exerciseId===null||l.exerciseId===q.exerciseId)&&(q.category===null||l.category===q.category)&&(q.specialization===null||l.specialization===q.specialization));
      // Pending records that have passed their validity cannot offer Send, even before a decision refresh.
      const visible=filtered.map(l=>l.status==='pending'&&l.expiresAtMillis<=capturedAt?{...l,status:'expired' as const}:l);
      const summary={pending:visible.filter(l=>l.status==='pending').length,processed:visible.filter(l=>l.status==='sent'||l.status==='dismissed').length,unavailable:visible.filter(l=>['expired','stale','revoked'].includes(l.status)).length};
      const selected=visible.filter(l=>(q.status==='all'||l.status===q.status)&&(q.afterLeadId===null||l.leadId>q.afterLeadId)),leads=selected.slice(0,q.limit),nextAfterLeadId=selected.length>q.limit?leads.at(-1)!.leadId:null;

      return{schemaVersion:1,mode:'synthetic_local',organizationId:ctx.organizationId,kind:q.kind,capturedAtMillis:capturedAt,leads,nextAfterLeadId,summary,facets,generation};
    }catch(error){throw recommendationCommandError(error);}
  };
}
