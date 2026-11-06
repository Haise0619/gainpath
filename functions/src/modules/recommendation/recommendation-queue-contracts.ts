import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {digestOf,keys,object} from '../workouts/workout-backup-validation';
import {LEVELS,OBJECTIVES,REASON_CODES,type LearningNeed,type ReasonCode} from './recommendation-ranking-contracts';
import type {MemberContentDestination} from './content-candidate-eligibility';

export type RecommendationKind='trainer'|'content';
export type RecommendationLeadStatus='pending'|'sent'|'dismissed'|'expired'|'stale'|'revoked';
export type QueueTarget={kind:'trainer';coachId:string;branchId:string;observedStartAtMillis:number;observedEndAtMillis:number}
  |{kind:'content';destination:MemberContentDestination};
export interface RecommendationLead {
  schemaVersion:1;mode:'synthetic_local';leadId:string;organizationId:string;memberId:string;kind:RecommendationKind;
  exerciseId:string;objective:LearningNeed['objective'];level:LearningNeed['level'];
  memberLabel:string;exerciseLabel:string;category:string;targetLabel:string;specialization:string|null;branchLabel:string|null;
  target:QueueTarget;
  evidence:{summary:string;scoredSessions:number|null;estimatedFormScorePercent:number|null;coverage:number|null;sourceVersion:string;configVersion:string};
  ranking:{origin:'ai_reranked'|'deterministic_fallback'|'deterministic_single_candidate';reasonCodes:ReasonCode[];explanations:string[];model:string|null;promptVersion:string;algorithmVersion:string;fallbackReason:string|null};
  sourceFingerprint:string;memberFingerprint:string;runId:string;createdAtMillis:number;expiresAtMillis:number;status:RecommendationLeadStatus;revision:number;
  decision:null|{actorId:string;atMillis:number;commandId:string;reason:string|null;recipientRecommendationId:string|null};
}
export interface QueueGenerationSummary {
  runId:string;kind:RecommendationKind;status:'in_progress'|'complete'|'failed';processed:number;candidateCount:number;generated:number;abstained:number;fallbackCount:number;
  nextCursor:string|null;failureCode:string|null;algorithmVersion:string;model:string|null;updatedAtMillis:number;
  abstentionReasons:{insufficient_evidence:number;unsupported_evidence:number;missing_consent:number;no_eligible_candidates:number;semantic_abstention:number};
}
export interface RecommendationQueueQuery {
  schemaVersion:1;organizationId:string;kind:RecommendationKind;status:'all'|RecommendationLeadStatus;
  startAtMillis:number;endAtMillis:number;exerciseId:string|null;category:string|null;specialization:string|null;afterLeadId:string|null;limit:number;
}
export interface RecommendationQueuePage {
  schemaVersion:1;mode:'synthetic_local';organizationId:string;kind:RecommendationKind;capturedAtMillis:number;
  leads:RecommendationLead[];nextAfterLeadId:string|null;summary:{pending:number;processed:number;unavailable:number};
  facets:{exercises:{id:string;label:string}[];categories:string[];specializations:string[]};generation:QueueGenerationSummary|null;
}
export interface RecommendationDecisionReceipt {
  schemaVersion:1;organizationId:string;leadId:string;revision:number;status:RecommendationLeadStatus;
  outcome:'prepared'|'dismissed'|'blocked';recipientRecommendationId:string|null;deliveryStatus:'prepared_local'|'not_prepared';
}
export interface RecommendationRecipientRecord {
  schemaVersion:1;mode:'synthetic_local';recipientRecommendationId:string;organizationId:string;memberId:string;leadId:string;
  kind:RecommendationKind;target:QueueTarget;createdAtMillis:number;expiresAtMillis:number;status:'prepared';
  memberReadAtMillis:null;acknowledgedAtMillis:null;withdrawnAtMillis:null;
  notificationDraft:{schemaVersion:1;type:'recommendation';recipientId:string;recommendationId:string;title:string;message:string;createdAtMillis:number;read:false};
}
export const QUEUE_STATUSES:readonly RecommendationLeadStatus[]=['pending','sent','dismissed','expired','stale','revoked'];
export const queueFailure=()=>new DomainError('failed-precondition','Recommendation records require review.');
export const queueInteger=(v:unknown,min=0):v is number=>Number.isSafeInteger(v)&&Number(v)>=min;
export function queueText(v:unknown,max=200):v is string{return typeof v==='string'&&!!v.trim()&&v.length<=max&&!/[\x00-\x1f\x7f]/.test(v);}
export function parseQueueTarget(raw:unknown,org:string):QueueTarget{
  const t=object(raw);
  if(t.kind==='trainer'){
    keys(t,['kind','coachId','branchId','observedStartAtMillis','observedEndAtMillis']);requiredIdentifier(t.coachId,'coach');requiredIdentifier(t.branchId,'branch');
    if(!queueInteger(t.observedStartAtMillis,1)||!queueInteger(t.observedEndAtMillis,1)||t.observedEndAtMillis<=t.observedStartAtMillis||t.observedEndAtMillis-t.observedStartAtMillis>3600000)throw queueFailure();
  }else if(t.kind==='content'){
    keys(t,['kind','destination']);const d=object(t.destination);keys(d,['kind','organizationId','routineId','exerciseIndex','exerciseId','dayNumber']);
    if(d.kind!=='published_routine_exercise_tutorial'||d.organizationId!==org||!queueInteger(d.exerciseIndex)||d.exerciseIndex>49||!queueInteger(d.dayNumber,1)||d.dayNumber>50)throw queueFailure();requiredIdentifier(d.routineId,'routine');requiredIdentifier(d.exerciseId,'exercise');
  }else throw queueFailure();
  return structuredClone(raw) as QueueTarget;
}
export function parseRecommendationLead(raw:unknown,org:string):RecommendationLead{
  try{
    const l=object(raw);keys(l,['schemaVersion','mode','leadId','organizationId','memberId','kind','exerciseId','objective','level','memberLabel','exerciseLabel','category','targetLabel','specialization','branchLabel','target','evidence','ranking','sourceFingerprint','memberFingerprint','runId','createdAtMillis','expiresAtMillis','status','revision','decision']);
    if(l.schemaVersion!==1||l.mode!=='synthetic_local'||l.organizationId!==org||!['trainer','content'].includes(l.kind as string)||!OBJECTIVES.includes(l.objective as any)||!LEVELS.includes(l.level as any)||!QUEUE_STATUSES.includes(l.status as any)||!queueInteger(l.revision,1)||!queueInteger(l.createdAtMillis,1)||!queueInteger(l.expiresAtMillis,1)||l.expiresAtMillis<=l.createdAtMillis)throw queueFailure();
    for(const k of ['leadId','memberId','exerciseId','runId'])requiredIdentifier(l[k],k);
    for(const k of ['memberLabel','exerciseLabel','category','targetLabel'])if(!queueText(l[k],120))throw queueFailure();
    for(const k of ['specialization','branchLabel'])if(l[k]!==null&&!queueText(l[k],120))throw queueFailure();
    for(const k of ['sourceFingerprint','memberFingerprint'])if(typeof l[k]!=='string'||!/^[a-f0-9]{64}$/.test(l[k]))throw queueFailure();
    const t=parseQueueTarget(l.target,org);if(t.kind!==l.kind)throw queueFailure();
    const e=object(l.evidence);keys(e,['summary','scoredSessions','estimatedFormScorePercent','coverage','sourceVersion','configVersion']);
    if(!queueText(e.summary,400)||!queueText(e.sourceVersion,128)||!queueText(e.configVersion,128)||(e.scoredSessions!==null&&!queueInteger(e.scoredSessions))||(e.estimatedFormScorePercent!==null&&(typeof e.estimatedFormScorePercent!=='number'||!Number.isFinite(e.estimatedFormScorePercent)||e.estimatedFormScorePercent<0||e.estimatedFormScorePercent>100))||(e.coverage!==null&&(typeof e.coverage!=='number'||!Number.isFinite(e.coverage)||e.coverage<0||e.coverage>1)))throw queueFailure();
    const r=object(l.ranking);keys(r,['origin','reasonCodes','explanations','model','promptVersion','algorithmVersion','fallbackReason']);
    if(!['ai_reranked','deterministic_fallback','deterministic_single_candidate'].includes(r.origin as string)||!Array.isArray(r.reasonCodes)||r.reasonCodes.length>6||new Set(r.reasonCodes).size!==r.reasonCodes.length||r.reasonCodes.some(c=>!REASON_CODES.includes(c))||!Array.isArray(r.explanations)||r.explanations.length>6||r.explanations.some(s=>!queueText(s,300)))throw queueFailure();
    for(const k of ['promptVersion','algorithmVersion'])if(!queueText(r[k],128))throw queueFailure();for(const k of ['model','fallbackReason'])if(r[k]!==null&&!queueText(r[k],128))throw queueFailure();
    if(l.decision!==null){const d=object(l.decision);keys(d,['actorId','atMillis','commandId','reason','recipientRecommendationId']);requiredIdentifier(d.actorId,'actor');requiredIdentifier(d.commandId,'command');if(!queueInteger(d.atMillis,1)||d.atMillis<l.createdAtMillis||(d.reason!==null&&!queueText(d.reason,300)))throw queueFailure();if(d.recipientRecommendationId!==null)requiredIdentifier(d.recipientRecommendationId,'recipient');}
    if((l.status==='pending'&&l.decision!==null)||((l.status==='sent'||l.status==='dismissed')&&l.decision===null))throw queueFailure();
    if(l.status==='sent'&&(object(l.decision).recipientRecommendationId===null||object(l.decision).reason!==null))throw queueFailure();
    if(l.status==='dismissed'&&(object(l.decision).recipientRecommendationId!==null||!queueText(object(l.decision).reason,300)||String(object(l.decision).reason).trim().length<8))throw queueFailure();
    return structuredClone(l) as unknown as RecommendationLead;
  }catch{throw queueFailure();}
}
export const queueBusinessKey=(org:string,memberId:string,kind:RecommendationKind,exerciseId:string,objective:string,sourceFingerprint:string)=>digestOf({org,memberId,kind,exerciseId,objective,sourceFingerprint});
export function parseQueueGenerationSummary(raw:unknown,kind?:RecommendationKind):QueueGenerationSummary{
  const s=object(raw);keys(s,['runId','kind','status','processed','candidateCount','generated','abstained','fallbackCount','nextCursor','failureCode','algorithmVersion','model','updatedAtMillis','abstentionReasons']);requiredIdentifier(s.runId,'run');
  if((s.kind!=='trainer'&&s.kind!=='content')||(kind!==undefined&&s.kind!==kind)||!['in_progress','complete','failed'].includes(s.status as string))throw queueFailure();
  for(const k of ['processed','candidateCount','generated','abstained','fallbackCount','updatedAtMillis'])if(!queueInteger(s[k]))throw queueFailure();
  if(Number(s.processed)>20||Number(s.candidateCount)>400||Number(s.generated)+Number(s.abstained)>Number(s.processed)||Number(s.fallbackCount)>Number(s.processed))throw queueFailure();
  const reasons=object(s.abstentionReasons);keys(reasons,['insufficient_evidence','unsupported_evidence','missing_consent','no_eligible_candidates','semantic_abstention']);if(Object.values(reasons).some(n=>!queueInteger(n))||Object.values(reasons).reduce<number>((sum,n)=>sum+Number(n),0)!==s.abstained)throw queueFailure();
  for(const k of ['nextCursor','failureCode','model'])if(s[k]!==null&&!queueText(s[k],150))throw queueFailure();if(!queueText(s.algorithmVersion,128)||(s.status!=='in_progress'&&s.nextCursor!==null))throw queueFailure();
  return structuredClone(s) as unknown as QueueGenerationSummary;
}
