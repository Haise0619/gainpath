import {digestOf} from '../workouts/workout-backup-validation';
import {parseQueueTarget,type QueueTarget} from './recommendation-queue-contracts';
import {qualifiedDecisionEvidence} from './evidence-learning-need';
import {selectPersonalizedRecommendation,type ReviewedPersonalizationCandidate} from './recommendation-personalization';
import type {AcceptedCanonicalSession,CanonicalSuggestion} from './canonical-recommendation-lifecycle';
import type {EvidenceScope,ExerciseCompatibility,ProvisionalSamplePolicy,SessionEvidence} from './exercise-insights-contracts';
import type {LearningNeed} from './recommendation-ranking-contracts';

/** Explicit code-reviewed interpretation of accepted v2 fields. This is not
 * supplied by a Member, inferred from a backup, or capture authority itself. */
export interface ReviewedAcceptedMetricBinding {
 reviewId:string;acceptedSchemaVersion:2;compatibility:ExerciseCompatibility;
 attemptMeasure:'completed_repetitions_lower_bound';localDateOffsetMinutes:480;
}
export interface ReviewedAcceptedDerivationPolicy {
 policyVersion:string;organizationId:string;exerciseLabel:string;metricBinding:ReviewedAcceptedMetricBinding;
 sample:ProvisionalSamplePolicy;maximumAgeMillis:number;attentionBelow:number;
 need:LearningNeed;
}
export type CanonicalPersonalizationCandidate=ReviewedPersonalizationCandidate<{target:QueueTarget;label:string}>;
const SUPPORTED:Record<string,{exercise:LearningNeed['exercise'];rule:string}>={
 F3b8xIr8ynBDd3gEICKX:{exercise:'squat',rule:'bodyweight-squat-side-v1'},
 'standing-calf-raise-side-v1':{exercise:'calf_raise',rule:'standing-calf-raise-side-v1'},
 'wall-push-up-side-v1':{exercise:'wall_push_up',rule:'wall-push-up-side-v1'},
};
const integer=(n:number,min:number,max:number)=>Number.isSafeInteger(n)&&n>=min&&n<=max;
/** Accepted summaries must already have passed canonical receipt/tuple admission.
 * Only non-mode-sensitive scored exercises are supported: a reviewed constant
 * cannot stand in for missing Curl/Row/Lunge arm/side or unsupported form metrics.
 * Completed reps are a conservative lower bound, never invented partial attempts. */
export function deriveReviewedAcceptedSuggestion(scope:EvidenceScope,sessions:readonly AcceptedCanonicalSession[],now:number,
 policy:ReviewedAcceptedDerivationPolicy,profile:unknown,candidates:readonly CanonicalPersonalizationCandidate[]):CanonicalSuggestion|null{
 try{
  const b=policy.metricBinding,c=b.compatibility,s=policy.sample,known=SUPPORTED[c.exerciseId];
  if(!known||policy.organizationId!=='gainpath'||scope.organizationId!==policy.organizationId||policy.need.exercise!==known.exercise||
   !/^[A-Za-z0-9_-]{1,128}$/.test(policy.policyVersion)||!/^[A-Za-z0-9_-]{1,128}$/.test(b.reviewId)||!policy.exerciseLabel.trim()||policy.exerciseLabel.length>80||
   b.acceptedSchemaVersion!==2||b.attemptMeasure!=='completed_repetitions_lower_bound'||b.localDateOffsetMinutes!==480||
   c.metricSchemaVersion!==1||c.mode!=='not_applicable'||c.scoreSupport!=='scored'||c.cameraView!=='side'||c.scoringVersion!==known.rule||
   !c.detectorId||!c.detectorVersion||!integer(now,1,Number.MAX_SAFE_INTEGER)||sessions.length>200||
   s.schemaVersion!==1||!s.revision||!integer(s.minimumScoredSessions,1,200)||!integer(s.minimumDistinctDays,1,90)||
   !integer(s.minimumAssessedAttempts,1,20000)||!Number.isFinite(s.minimumTrackingCoverage)||s.minimumTrackingCoverage<=0||s.minimumTrackingCoverage>1||
   !integer(policy.maximumAgeMillis,1,90*86400000)||!Number.isFinite(policy.attentionBelow)||policy.attentionBelow<0||policy.attentionBelow>100)return null;
  const seen=new Map<string,SessionEvidence>();
  for(const accepted of sessions){
   const i=accepted.input;
   if(i.organizationId!==scope.organizationId||i.memberId!==scope.memberId||i.schemaVersion!==2||i.provenance!=='real_camera'||
    !integer(accepted.acceptedAtMillis,i.endedAtMillis,now)||!/^[a-f0-9]{64}$/.test(accepted.fingerprint))return null;
   if(i.exerciseId!==c.exerciseId||i.scoringVersion!==c.scoringVersion||i.detectorId!==c.detectorId||i.detectorVersion!==c.detectorVersion||i.cameraView!==c.cameraView)continue;
   if(!integer(i.startedAtMillis,0,i.endedAtMillis)||!integer(i.endedAtMillis,1,now)||!integer(i.repetitions,0,20000)||
    !integer(i.trackedDurationMillis,0,Number.MAX_SAFE_INTEGER/1000)||!integer(i.rejectedDurationMillis,0,Number.MAX_SAFE_INTEGER/1000)||
    i.formScorePercent!==null&&(!Number.isFinite(i.formScorePercent)||i.formScorePercent<0||i.formScorePercent>100))return null;
   const total=i.trackedDurationMillis+i.rejectedDurationMillis;
   const recordKey=i.sessionId,old=seen.get(recordKey);if(old){if(old.digest!==accepted.fingerprint)return null;continue;}
   seen.set(recordKey,{kind:'session',recordKey,digest:accepted.fingerprint,updatedAtMillis:accepted.acceptedAtMillis,endedAtMillis:i.endedAtMillis,
    localDate:new Date(i.endedAtMillis+480*60000).toISOString().slice(0,10),compatibility:c,unsupportedReason:null,formScorePercent:i.formScorePercent,
    assessedAttempts:i.repetitions,trackedMicros:i.trackedDurationMillis*1000,rejectedMicros:i.rejectedDurationMillis*1000,trackingCoverage:total?i.trackedDurationMillis/total:null});
  }
  const decision=qualifiedDecisionEvidence([...seen.values()],s,policy.maximumAgeMillis,now,scope.memberId);
  if(decision.status!=='qualified'||decision.group.meanEstimatedFormScore===null||decision.group.meanEstimatedFormScore>=policy.attentionBelow)return null;
  const personalized=selectPersonalizedRecommendation(policy.need,profile,candidates);if(!personalized)return null;
  const selected=personalized.primary;parseQueueTarget(selected.target.target,scope.organizationId);
  if(!selected.target.label.trim()||selected.target.label.length>200||selected.kind!==selected.target.target.kind)return null;
  const observations=decision.qualified.map(e=>({id:e.recordKey,digest:e.digest})).sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0);
  return{needKey:digestOf({exercise:policy.need.exercise,objective:policy.need.objective,level:personalized.need.level}),
   evidenceFingerprint:digestOf({scope,observations,policy:digestOf(policy),binding:b,profile:personalized.profileFingerprint}),
   evidenceSummary:{assessedSessions:decision.qualified.length,distinctDays:new Set(decision.qualified.map(e=>e.localDate)).size,latestAtMillis:Math.max(...decision.qualified.map(e=>e.endedAtMillis))},
   policyVersion:policy.policyVersion,exerciseLabel:policy.exerciseLabel,objective:policy.need.objective,
   title:selected.kind==='content'?`A guide for your ${policy.exerciseLabel} practice`:`Optional coaching for ${policy.exerciseLabel}`,
   summary:selected.kind==='content'?'Explore guidance for the exercise you practised.':'Explore optional coaching for the exercise you practised.',
   explanations:personalized.explanations,target:selected.target.target,targetLabel:selected.target.label};
 }catch{return null;}
}
