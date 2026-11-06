import {randomUUID} from 'node:crypto';
import {DomainError} from '../../platform/errors';
import {requiredIdentifier,InputValidationError} from '../../platform/validation';
import type {DocumentData,TransactionPort} from '../../platform/firestore/store';
import {digestOf,keys,object} from '../workouts/workout-backup-validation';
import type {InsightsRequest} from './exercise-insights-contracts';
import {authorizeRecommendationSession,recommendationCommandError} from './recommendation-configuration';
import type {CandidateRecommendationResult} from './recommendation-candidate-service';
import type {TrainerCandidateResult} from './trainer-candidate-eligibility';
import type {ContentCandidateResult} from './content-candidate-eligibility';
import {validateNeed,type LearningNeed} from './recommendation-ranking-contracts';
import {parseRecommendationLead,parseQueueGenerationSummary,queueBusinessKey,queueInteger,queueText,type RecommendationLead,type RecommendationKind,type QueueGenerationSummary} from './recommendation-queue-contracts';
import {authorizeQueue,requireQueueAdmin,readRecommendationMemberState,type QueueSecurityDependencies} from './recommendation-queue-security';

export interface QueueGenerationItem {id:string;memberId:string;need:LearningNeed;exerciseId:string;memberLabel:string;exerciseLabel:string;category:string;evidenceStatus:'sufficient_synthetic'|'insufficient'|'unsupported';evidence?:RecommendationLead['evidence']}
export interface QueueEngineResult {
  recommendation:CandidateRecommendationResult<TrainerCandidateResult|ContentCandidateResult>;
  sourceFingerprint:string;
  evidenceBinding?:DocumentData;
  /** Stable observation identity, separate from capture-source freshness. Only sealed evidence sources may supply. */
  deduplicationFingerprint?:string;
  targetLabels:Record<string,{label:string;specialization:string|null;branchLabel:string|null}>;
}
/** Trusted compiled fixture catalog, not a request body or production data reader. */
export interface QueueGenerationSource {
  fixtureSetId:'module13-c-v1';organizationId?:'synthetic-org'|'gainpath';prepare?:()=>Promise<QueueGenerationSource>;abstentions?:{reason:'insufficient_evidence'|'unsupported_evidence'|'missing_consent'}[];sourceVersion:string;configVersion:string;validityMillis:number;items:QueueGenerationItem[];
  inference:'mock_or_recorded_synthetic';
  recommend(item:QueueGenerationItem,kind:RecommendationKind,allowInference:boolean):Promise<QueueEngineResult>;
  validate(tx:Pick<TransactionPort,'get'|'getAll'>,item:QueueGenerationItem,kind:RecommendationKind,fingerprint:string):Promise<boolean>;
}
export interface QueueGenerationDependencies extends QueueSecurityDependencies {source:QueueGenerationSource}
export interface QueueGenerationResponse {schemaVersion:1;mode:'synthetic_local';organizationId:string;summary:QueueGenerationSummary}
interface Run {schemaVersion:1;actorId:string;commandId:string;inputFingerprint:string;index:number;summary:QueueGenerationSummary}
const PAGE=2,LEASE=60000;
const evidenceSources=new WeakSet<QueueGenerationSource>();
/** Server composition seals evidence summaries; request objects cannot create this authority. */
export function markEvidenceQueueSource(source:QueueGenerationSource):void{evidenceSources.add(source);}
function validateSource(source:QueueGenerationSource):void{
  if(!source||source.fixtureSetId!=='module13-c-v1'||source.inference!=='mock_or_recorded_synthetic'||!queueText(source.sourceVersion,128)||!queueText(source.configVersion,128)||!queueInteger(source.validityMillis,60000)||source.validityMillis>7*86400000||!Array.isArray(source.items)||source.items.length+(source.abstentions?.length??0)>20||source.abstentions?.some(a=>!['insufficient_evidence','unsupported_evidence','missing_consent'].includes(a.reason)))throw new DomainError('failed-precondition','Explicit bounded synthetic sources required.');
  const ids=new Set<string>();for(const i of source.items){requiredIdentifier(i.id,'fixture');requiredIdentifier(i.memberId,'member');requiredIdentifier(i.exerciseId,'exercise');validateNeed(i.need);if(i.evidence&&!evidenceSources.has(source))throw new InputValidationError('Unverified evidence origin.');if(!i.id.startsWith('fictional-')||ids.has(i.id)||!['sufficient_synthetic','insufficient','unsupported'].includes(i.evidenceStatus)||![i.memberLabel,i.exerciseLabel,i.category].every(t=>queueText(t,120)))throw new InputValidationError('Invalid synthetic manifest.');ids.add(i.id);}
}
export function queueLeadFromEngine(item:QueueGenerationItem,kind:RecommendationKind,engine:QueueEngineResult,source:QueueGenerationSource,memberFingerprint:string,runId:string,now:number):RecommendationLead|null{
  if(engine.deduplicationFingerprint&&(!evidenceSources.has(source)||!/^[a-f0-9]{64}$/.test(engine.deduplicationFingerprint)))throw new DomainError('failed-precondition','Unverified evidence identity.');
  const org=source.organizationId??'synthetic-org';
  const r=engine.recommendation,top=r.ranking.final[0];
  if(r.ranking.status==='abstained'||!top)return null;
  if(!r.eligibility||!['ai_reranked','deterministic_fallback','deterministic_single_candidate'].includes(r.ranking.origin)||r.rankingCandidates.length>20||!r.rankingCandidates.some(c=>c.id===top.id&&c.organizationId===org&&c.kind===kind))throw new DomainError('failed-precondition','Invalid engine result.');
  let target:RecommendationLead['target'];let label=item.exerciseLabel,specialization:string|null=null,branchLabel:string|null=null;
  if(kind==='trainer'){
    const c=(r.eligibility as TrainerCandidateResult).candidates.find(c=>c.candidateId===top.id);if(!c?.availableOptions?.length)throw new DomainError('failed-precondition','Invalid Coach target.');
    const slot=c.availableOptions[0];target={kind:'trainer',coachId:c.coachId,branchId:slot.branchId,observedStartAtMillis:slot.startAtMillis,observedEndAtMillis:slot.endAtMillis};
    const display=engine.targetLabels[top.id];if(!display)throw new DomainError('failed-precondition','Missing Coach display.');label=display.label;specialization=display.specialization;branchLabel=display.branchLabel;
  }else{const c=(r.eligibility as ContentCandidateResult).candidates.find(c=>c.candidateId===top.id);if(!c)throw new DomainError('failed-precondition','Invalid tutorial target.');target={kind:'content',destination:c.destination};label=c.title;}
  const codes=r.ranking.ai?.find(a=>a.candidateId===top.id&&!a.abstain)?.reasonCodes??[...new Set(r.rankingCandidates.find(c=>c.id===top.id)!.evidence.flatMap(e=>e.supports))];
  const leadId=queueBusinessKey(org,item.memberId,kind,item.exerciseId,item.need.objective,engine.deduplicationFingerprint??engine.sourceFingerprint);
  return parseRecommendationLead({schemaVersion:1,mode:'synthetic_local',leadId,organizationId:org,memberId:item.memberId,kind,exerciseId:item.exerciseId,objective:item.need.objective,level:item.need.level,
    memberLabel:item.memberLabel,exerciseLabel:item.exerciseLabel,category:item.category,targetLabel:label,specialization,branchLabel,target,
    evidence:item.evidence??{summary:'Explicit synthetic learning need; no real workout history was processed.',scoredSessions:null,estimatedFormScorePercent:null,coverage:null,sourceVersion:source.sourceVersion,configVersion:source.configVersion},
    ranking:{origin:r.ranking.origin,reasonCodes:codes,explanations:top.explanations,model:r.ranking.provenance.model,promptVersion:r.ranking.provenance.promptVersion,algorithmVersion:r.ranking.provenance.rankingPolicy,fallbackReason:r.ranking.provenance.fallbackReason},
    sourceFingerprint:engine.sourceFingerprint,memberFingerprint,runId,createdAtMillis:now,expiresAtMillis:now+source.validityMillis,status:'pending',revision:1,decision:null},org);
}
/** Page-at-a-time durable generation; no external inference inside transactions. */
export function createRecommendationQueueGeneration(deps:QueueGenerationDependencies){
  return async(request:InsightsRequest):Promise<QueueGenerationResponse>=>{
    let reserved:{runId:string;token:string;index:number;auth:any;org:string;now:number}|undefined;
    try{
      const ctx=await authorizeQueue(request,deps),q=object(request.data);keys(q,['schemaVersion','organizationId','kind','commandId','continuation']);
      if(q.schemaVersion!==1||(q.kind!=='trainer'&&q.kind!=='content')||(q.continuation!==null&&!queueText(q.continuation,150)))throw new InputValidationError('Invalid queue refresh.');
      const commandId=requiredIdentifier(q.commandId,'command'),kind=q.kind;const source=deps.source.prepare?await deps.source.prepare():deps.source;validateSource(source);if((source.organizationId??'synthetic-org')!==ctx.organizationId)throw new DomainError('failed-precondition','Source scope changed.');const ROOT=`orgs/${ctx.organizationId}`;
      const items=structuredClone(source.items),inputFingerprint=digestOf({sourceVersion:source.sourceVersion,configVersion:source.configVersion,validityMillis:source.validityMillis,items,abstentions:source.abstentions??[]}),runId=digestOf({actorId:ctx.auth.uid,commandId,kind}),runPath=`${ROOT}/recommendationRuns/${runId}`,lockPath=`${ROOT}/recommendationRefreshLocks/${kind}`;
      let index=0;if(q.continuation!==null){const parts=(q.continuation as string).split(':');if(parts.length!==2||parts[0]!==runId||!/^\d{1,2}$/.test(parts[1]))throw new InputValidationError('Invalid continuation.');index=Number(parts[1]);if(index<1||index>20||index%PAGE!==0)throw new InputValidationError('Invalid continuation.');}
      const pagePath=`${runPath}/pages/${index}`,token=randomUUID();
      const prepared=await deps.store.transact(async tx=>{
        await requireQueueAdmin(tx,ctx.auth,ctx.organizationId);const old=await tx.get(runPath) as unknown as Run|undefined,prior=await tx.get(pagePath),lock=await tx.get(lockPath);
        if(old&&(old.schemaVersion!==1||old.actorId!==ctx.auth.uid||old.commandId!==commandId||old.inputFingerprint!==inputFingerprint))throw new DomainError('aborted','Refresh source or command changed.');
        if(old)parseQueueGenerationSummary(old.summary,kind);
        if(prior){if(prior.inputFingerprint!==inputFingerprint)throw new DomainError('aborted','Refresh changed.');const response=object(prior.response);keys(response,['schemaVersion','mode','organizationId','summary']);if(response.schemaVersion!==1||response.mode!=='synthetic_local'||response.organizationId!==ctx.organizationId)throw new DomainError('failed-precondition','Invalid page receipt.');return{replay:{schemaVersion:1 as const,mode:'synthetic_local' as const,organizationId:ctx.organizationId,summary:parseQueueGenerationSummary(response.summary,kind)}};}
        if((old?.index??0)!==index||old?.summary.status==='failed')throw new DomainError('aborted','Refresh continuation changed.');
        if(lock&&queueInteger(lock.expiresAtMillis)&&lock.expiresAtMillis>ctx.now)throw new DomainError('aborted','Queue refresh is already in progress.');
        const summary:QueueGenerationSummary=old?.summary??{runId,kind,status:'in_progress',processed:source.abstentions?.length??0,candidateCount:0,generated:0,abstained:source.abstentions?.length??0,fallbackCount:0,nextCursor:null,failureCode:null,algorithmVersion:'experimental-40-baseline-60-semantic-v1',model:null,updatedAtMillis:ctx.now,abstentionReasons:{insufficient_evidence:0,unsupported_evidence:0,missing_consent:0,no_eligible_candidates:0,semantic_abstention:0}};
        if(!old)for(const a of source.abstentions??[])summary.abstentionReasons[a.reason]++;
        tx.set(lockPath,{schemaVersion:1,runId,token,expiresAtMillis:ctx.now+LEASE});tx.set(runPath,{schemaVersion:1,actorId:ctx.auth.uid,commandId,inputFingerprint,index,summary});
        return{replay:null};
      });if(prepared.replay)return prepared.replay;
      reserved={runId,token,index,auth:ctx.auth,org:ctx.organizationId,now:ctx.now};
      const selected=items.slice(index,index+PAGE),results:{item:QueueGenerationItem;memberFingerprint:string;allowInference:boolean;engine:QueueEngineResult|null}[]=[];
      for(const item of selected){
        const fresh=await deps.readAuthIdentity(item.memberId);if(!fresh||fresh.uid!==item.memberId||fresh.disabled!==false||fresh.emailVerified!==true)throw new DomainError('permission-denied','Member unavailable.');
        const state=await deps.store.transact(async tx=>{await requireQueueAdmin(tx,ctx.auth,ctx.organizationId);const scope={organizationId:ctx.organizationId,memberId:item.memberId};return{member:await readRecommendationMemberState(tx,scope,ctx.now,deps.noticePolicies??[],['exerciseInsights','recommendationGeneration']),ai:await readRecommendationMemberState(tx,scope,ctx.now,deps.noticePolicies??[],['externalAiInference'])};});
        const member=state.member,allowInference=state.ai.eligible;
        if(!member.eligible||item.evidenceStatus!=='sufficient_synthetic'){results.push({item,memberFingerprint:member.fingerprint,allowInference,engine:null});continue;}
        const engine=await source.recommend(item,kind,allowInference),ranking=engine.recommendation.ranking;
        if(!allowInference&&(ranking.origin==='ai_reranked'||ranking.provenance.model!==null||ranking.origin==='deterministic_fallback'&&!['provider_not_configured','no_safe_semantic_evidence'].includes(ranking.provenance.fallbackReason??'')))throw new DomainError('failed-precondition','Unpermitted inference result.');
        results.push({item,memberFingerprint:member.fingerprint,allowInference,engine});
      }
      await authorizeRecommendationSession(request,deps);
      for(const row of results){const current=await deps.readAuthIdentity(row.item.memberId);if(!current||current.uid!==row.item.memberId||current.disabled!==false||current.emailVerified!==true)throw new DomainError('aborted','Member changed.');}
      const now=(deps.clock??Date.now)();if(!queueInteger(now,1)||now<ctx.now)throw new DomainError('unavailable','Invalid generation clock.');
      return await deps.store.transact(async tx=>{
        await requireQueueAdmin(tx,ctx.auth,ctx.organizationId);const current=await tx.get(runPath) as unknown as Run,lock=await tx.get(lockPath);if(lock?.token!==token||lock.runId!==runId||Number(lock.expiresAtMillis)<=now||current.index!==index||current.inputFingerprint!==inputFingerprint)throw new DomainError('aborted','Refresh lease changed.');
        const evidenceBindings:{fingerprint:string;data:DocumentData}[]=[],leads:{lead:RecommendationLead;previous:RecommendationLead|null}[]=[],existing:Set<string>=new Set(),abstentionReasons={...current.summary.abstentionReasons};let candidateCount=0,abstained=0,fallbackCount=0,model:string|null=current.summary.model;
        for(const row of results){
          if(!row.engine){abstained++;abstentionReasons[row.item.evidenceStatus==='insufficient'?'insufficient_evidence':row.item.evidenceStatus==='unsupported'?'unsupported_evidence':'missing_consent']++;continue;}
          const m=await readRecommendationMemberState(tx,{organizationId:ctx.organizationId,memberId:row.item.memberId},now,deps.noticePolicies??[],row.allowInference?['exerciseInsights','recommendationGeneration','externalAiInference']:['exerciseInsights','recommendationGeneration']);
          if(!m.eligible||m.fingerprint!==row.memberFingerprint||!await source.validate({get:p=>tx.get(p)},row.item,kind,row.engine.sourceFingerprint))throw new DomainError('aborted','Recommendation inputs changed.');
          if(row.engine.evidenceBinding){if(!evidenceSources.has(source))throw new DomainError('failed-precondition','Unverified evidence binding.');evidenceBindings.push({fingerprint:row.engine.sourceFingerprint,data:row.engine.evidenceBinding});}
          candidateCount+=row.engine.recommendation.rankingCandidates.length;model=row.engine.recommendation.ranking.provenance.model??model;const lead=queueLeadFromEngine(row.item,kind,row.engine,source,m.fingerprint,runId,now);
          if(!lead){abstained++;abstentionReasons[row.engine.recommendation.ranking.provenance.fallbackReason==='semantic_abstention'?'semantic_abstention':'no_eligible_candidates']++;continue;}if(lead.ranking.origin==='deterministic_fallback')fallbackCount++;model=lead.ranking.model??model;
          if(!existing.has(lead.leadId)){
            const rawOld=await tx.get(`${ROOT}/recommendationLeads/${lead.leadId}`),old=rawOld?parseRecommendationLead(rawOld,ctx.organizationId):null;
            if(!old)leads.push({lead,previous:null});
            else if(old.status!=='sent'&&old.status!=='dismissed'&&(old.status!=='pending'||old.expiresAtMillis<=now||old.memberFingerprint!==lead.memberFingerprint||old.sourceFingerprint!==lead.sourceFingerprint)){
              if(old.revision>=Number.MAX_SAFE_INTEGER)throw new DomainError('failed-precondition','Lead revision limit.');
              leads.push({lead:{...lead,createdAtMillis:old.createdAtMillis,revision:old.revision+1},previous:old});
            }
            existing.add(lead.leadId);
          }
        }
        const next=index+selected.length,summary:QueueGenerationSummary={...current.summary,processed:next+(source.abstentions?.length??0),candidateCount:current.summary.candidateCount+candidateCount,generated:current.summary.generated+leads.length,abstained:current.summary.abstained+abstained,abstentionReasons,fallbackCount:current.summary.fallbackCount+fallbackCount,status:next<items.length?'in_progress':'complete',nextCursor:next<items.length?`${runId}:${next}`:null,failureCode:null,model,updatedAtMillis:now};
        const response:QueueGenerationResponse={schemaVersion:1,mode:'synthetic_local',organizationId:ctx.organizationId,summary};
        for(const binding of evidenceBindings)tx.set(`${ROOT}/recommendationEvidenceBindings/${binding.fingerprint}`,binding.data);
        for(const change of leads){const lead=change.lead;if(change.previous){tx.set(`${ROOT}/recommendationLeads/${lead.leadId}`,lead);tx.create(`${ROOT}/recommendationRefreshAudits/${digestOf({runId,index,leadId:lead.leadId,revision:lead.revision})}`,{schemaVersion:1,organizationId:ctx.organizationId,actorId:ctx.auth.uid,leadId:lead.leadId,runId,previousStatus:change.previous.status,previousRevision:change.previous.revision,revision:lead.revision,atMillis:now,sourceFingerprint:lead.sourceFingerprint});}else tx.create(`${ROOT}/recommendationLeads/${lead.leadId}`,lead);}
        tx.set(runPath,{...current,index:next,summary});tx.set(lockPath,{schemaVersion:1,runId,token,expiresAtMillis:now});tx.create(pagePath,{schemaVersion:1,inputFingerprint,response});tx.set(`${ROOT}/recommendationGenerationState/${kind}`,{schemaVersion:1,summary});
        return response;
      });
    }catch(error){
      if(reserved){const r=reserved;try{await deps.store.transact(async tx=>{await requireQueueAdmin(tx,r.auth,r.org);const ROOT=`orgs/${r.org}`,path=`${ROOT}/recommendationRuns/${r.runId}`,run=await tx.get(path) as unknown as Run|undefined,lockPath=`${ROOT}/recommendationRefreshLocks/${run?.summary.kind}`,lock=await tx.get(lockPath);if(run&&lock?.token===r.token){const summary={...run.summary,status:'failed' as const,failureCode:error instanceof DomainError?error.code:'unavailable',nextCursor:null,updatedAtMillis:r.now};tx.set(path,{...run,summary});tx.set(lockPath,{...lock,expiresAtMillis:r.now});tx.set(`${ROOT}/recommendationGenerationState/${run.summary.kind}`,{schemaVersion:1,summary});}});}catch{/* Do not overwrite source/authorization failure with audit failure. */}}
      throw recommendationCommandError(error);
    }
  };
}
