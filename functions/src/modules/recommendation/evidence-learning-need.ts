import {digestOf,keys,object} from '../workouts/workout-backup-validation';
import {aggregateExerciseEvidence} from './exercise-insights-aggregation';
import {extractWorkoutEvidence} from './workout-evidence';
import {requireFypRuntimeCapability,type FypRuntimeCapability} from '../dataset/fyp-scope';
import {extractFypObservationEvidence} from '../dataset/fyp-observations';
import {parseRecommendationConfiguration,type ReviewedRecommendationPolicy} from './recommendation-configuration';
import {validateNeed,type LearningNeed} from './recommendation-ranking-contracts';
import type {EvidenceRow,EvidenceScope,ExerciseCompatibility,ProvisionalSamplePolicy,SessionEvidence} from './exercise-insights-contracts';

export interface EvidenceWindow {startAtMillis:number;endAtMillis:number}
/** Test-source attestation only. A production reader must provide separately reviewed capture trust. */
export interface SyntheticCaptureAttestation {rowId:string;organizationId:string;memberId:string;recordKey:string;digest:string;updatedAtMillis:number;capturedAtMillis:number;trust:'synthetic_emulator_attested'|'cohort_synthetic_observation'}
export interface AttestedWorkoutEvidenceBatch {schemaVersion:1;scope:EvidenceScope;window:EvidenceWindow;sourceRevision:string;rows:EvidenceRow[];attestations:SyntheticCaptureAttestation[]}
export interface ReviewedEvidenceLearningPolicy {schemaVersion:1;mode:'synthetic_reviewed';policyId:string;reviewVersion:string;compatibility:ExerciseCompatibility;provisionalSamplePolicy:ProvisionalSamplePolicy;attentionThreshold:{operator:'score_below';estimatedFormScorePercent:number};objective:LearningNeed['objective'];level:LearningNeed['level'];maximumAgeMillis:number}
export type EvidenceAbstentionReason='policy_unavailable'|'invalid_policy'|'invalid_source'|'unsupported_exercise'|'incompatible_scoring'|'insufficient_evidence'|'stale_evidence'|'no_guidance_opportunity'|'missing_consent';
export interface DerivedEvidenceProvenance {schemaVersion:1;origin:'validated_workout_evidence';scope:EvidenceScope;window:EvidenceWindow;sourceRevision:string;policyFingerprint:string;compatibilityFingerprint:string;evidenceFingerprint:string;duplicateRecords:number;latestCaptureAtMillis:number}
export interface DerivedEvidenceLearningNeed {status:'derived';need:LearningNeed;exerciseId:string;evidence:{summary:string;scoredSessions:number;estimatedFormScorePercent:number;coverage:number;sourceVersion:string;configVersion:string};provenance:DerivedEvidenceProvenance}
export type EvidenceLearningNeedResult=DerivedEvidenceLearningNeed|{status:'abstained';reason:EvidenceAbstentionReason};
const EXERCISE_MAP:Readonly<Record<string,LearningNeed['exercise']>>=Object.freeze({F3b8xIr8ynBDd3gEICKX:'squat','standing-single-arm-curl-side-v1':'single_arm_curl','standing-calf-raise-side-v1':'calf_raise','wall-push-up-side-v1':'wall_push_up'});
const integer=(n:unknown):n is number=>Number.isSafeInteger(n)&&Number(n)>=0;
/** Reuses A2 policy validation. No new defaults, scores, faults or clinical interpretation. */
export function evidenceLearningPolicyFingerprint(policy:ReviewedEvidenceLearningPolicy):string{
 const p=object(policy);keys(p,['schemaVersion','mode','policyId','reviewVersion','compatibility','provisionalSamplePolicy','attentionThreshold','objective','level','maximumAgeMillis']);
 if(p.schemaVersion!==1||p.mode!=='synthetic_reviewed'||!integer(p.maximumAgeMillis)||p.maximumAgeMillis<1||p.maximumAgeMillis>90*86400000)throw Error('invalid_policy');
 const reviewed:ReviewedRecommendationPolicy={policyId:policy.policyId,reviewVersion:policy.reviewVersion,compatibility:policy.compatibility,provisionalSamplePolicy:policy.provisionalSamplePolicy,attentionThreshold:policy.attentionThreshold,cohortEligibility:null};
 parseRecommendationConfiguration({schemaVersion:1,organizationId:'gainpath',revision:1,policies:[reviewed],activation:{generation:false,externalAi:false,matching:false,delivery:false}},'gainpath');
 if(!policy.provisionalSamplePolicy||!policy.attentionThreshold||policy.compatibility.scoreSupport!=='scored')throw Error('invalid_policy');
 validateNeed({exercise:EXERCISE_MAP[policy.compatibility.exerciseId]??'squat',objective:policy.objective,level:policy.level});
 return digestOf(policy);
}
/** Validated provisional workout measurements -> educational objective, never invented movement faults. */
export function deriveEvidenceLearningNeed(scope:EvidenceScope,batch:AttestedWorkoutEvidenceBatch,policy:ReviewedEvidenceLearningPolicy|null,window:EvidenceWindow,now:number,fypCapability?:FypRuntimeCapability):EvidenceLearningNeedResult{
 if(!policy)return{status:'abstained',reason:'policy_unavailable'};
 let policyFingerprint:string;try{policyFingerprint=evidenceLearningPolicyFingerprint(policy);}catch{return{status:'abstained',reason:'invalid_policy'};}
 try{
  if(!integer(now)||!integer(window.startAtMillis)||!integer(window.endAtMillis)||window.startAtMillis>=window.endAtMillis||window.endAtMillis>now||window.endAtMillis-window.startAtMillis>90*86400000||batch.schemaVersion!==1||digestOf(batch.scope)!==digestOf(scope)||digestOf(batch.window)!==digestOf(window)||!/^[a-f0-9]{64}$/.test(batch.sourceRevision)||!Array.isArray(batch.rows)||batch.rows.length>200||!Array.isArray(batch.attestations)||batch.attestations.length!==batch.rows.length)throw Error();
  let bytes=0,duplicates=0;const seen=new Map<string,SessionEvidence>(),ids=new Set<string>();
  for(const row of batch.rows){
   if(ids.has(row.id))throw Error();ids.add(row.id);bytes+=Buffer.byteLength(String(row.data.payloadJson),'utf8');if(bytes>2*1024*1024)throw Error();
   const a=batch.attestations.filter(a=>a.rowId===row.id);if(a.length!==1)throw Error();const att=a[0];
   const cohort=requireFypRuntimeCapability(fypCapability,scope.organizationId);
   const s=cohort?extractFypObservationEvidence(scope,row,now,fypCapability!):extractWorkoutEvidence(scope,row,now);if(s.kind!=='session'||att.trust!==(cohort?'cohort_synthetic_observation':'synthetic_emulator_attested')||att.organizationId!==scope.organizationId||att.memberId!==scope.memberId||att.recordKey!==s.recordKey||att.digest!==s.digest||att.updatedAtMillis!==s.updatedAtMillis||att.capturedAtMillis!==s.endedAtMillis||s.endedAtMillis<window.startAtMillis||s.endedAtMillis>=window.endAtMillis)throw Error();
   const old=seen.get(s.recordKey);if(old){if(old.digest!==s.digest)throw Error();duplicates++;}else seen.set(s.recordKey,s);
  }
  const sessions=[...seen.values()];if(!sessions.length)return{status:'abstained',reason:'insufficient_evidence'};
  const mapped=EXERCISE_MAP[policy.compatibility.exerciseId];if(scope.organizationId!=='gainpath'||!mapped)return{status:'abstained',reason:'unsupported_exercise'};
  const compatible=sessions.filter(s=>s.compatibility&&digestOf(s.compatibility)===digestOf(policy.compatibility));
  if(!compatible.length)return{status:'abstained',reason:sessions.some(s=>s.compatibility)?'incompatible_scoring':'unsupported_exercise'};
  const latest=Math.max(...compatible.map(s=>s.endedAtMillis));if(now-latest>policy.maximumAgeMillis)return{status:'abstained',reason:'stale_evidence'};
  const group=aggregateExerciseEvidence([{memberId:scope.memberId,sessions:compatible}],policy.provisionalSamplePolicy)[0];
  if(!group||group.evidenceState!=='meets_provisional_minimums'||group.meanEstimatedFormScore===null||group.trackingCoverage===null)return{status:'abstained',reason:'insufficient_evidence'};
  if(group.meanEstimatedFormScore>=policy.attentionThreshold.estimatedFormScorePercent)return{status:'abstained',reason:'no_guidance_opportunity'};
  const need:LearningNeed={exercise:mapped,objective:policy.objective,level:policy.level};
  const minimal=sessions.map(s=>({key:s.recordKey,digest:s.digest})).sort((a,b)=>a.key.localeCompare(b.key));
  const provenance:DerivedEvidenceProvenance={schemaVersion:1,origin:'validated_workout_evidence',scope:{...scope},window:{...window},sourceRevision:batch.sourceRevision,policyFingerprint,compatibilityFingerprint:digestOf(policy.compatibility),evidenceFingerprint:digestOf({scope,policyFingerprint,minimal,need}),duplicateRecords:duplicates,latestCaptureAtMillis:latest};
  return{status:'derived',need,exerciseId:policy.compatibility.exerciseId,evidence:{summary:'Educational technique guidance derived from validated workout evidence under an explicitly synthetic reviewed policy.',scoredSessions:group.scoredSessions,estimatedFormScorePercent:group.meanEstimatedFormScore,coverage:group.trackingCoverage,sourceVersion:'validated-workout-evidence-v1',configVersion:policy.reviewVersion},provenance};
 }catch{return{status:'abstained',reason:'invalid_source'};}
}
