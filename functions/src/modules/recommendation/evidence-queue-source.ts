import {DomainError} from '../../platform/errors';
import type {DocumentData,TransactionPort} from '../../platform/firestore/store';
import {digestOf,keys,object} from '../workouts/workout-backup-validation';
import {evaluateRecommendationConsentV2} from './recommendation-consent-v2';
import {readRecommendationMemberState,requireSyntheticQueue,type QueueSecurityDependencies} from './recommendation-queue-security';
import {deriveEvidenceLearningNeed,evidenceLearningPolicyFingerprint,type AttestedWorkoutEvidenceBatch,type DerivedEvidenceLearningNeed,type DerivedEvidenceProvenance,type EvidenceAbstentionReason,type EvidenceWindow,type ReviewedEvidenceLearningPolicy} from './evidence-learning-need';
import {markEvidenceQueueSource,type QueueEngineResult,type QueueGenerationItem,type QueueGenerationSource} from './recommendation-queue-generation';
import {queueBusinessKey,type RecommendationLead,type RecommendationKind} from './recommendation-queue-contracts';
import {validateNeed} from './recommendation-ranking-contracts';
import type {EvidenceScope} from './exercise-insights-contracts';

type ReaderTx=Pick<TransactionPort,'get'|'getAll'>;
export interface EvidenceQueueMember {memberId:string;memberLabel:string;exerciseId:string;exerciseLabel:string;category:string}
export interface EvidenceQueueBinding {schemaVersion:1;scope:EvidenceScope;exerciseId:string;need:QueueGenerationItem['need'];kind:RecommendationKind;provenance:DerivedEvidenceProvenance;candidateFingerprint:string;deduplicationFingerprint:string;maximumAgeMillis:number;memberFingerprintAtExtraction:string;evidence:RecommendationLead['evidence']}
export interface EvidenceQueueSourceOptions extends QueueSecurityDependencies {
 organizationId:'gainpath';members:readonly EvidenceQueueMember[];window:EvidenceWindow;validityMillis:number;
 readEvidence:(scope:EvidenceScope,window:EvidenceWindow)=>Promise<AttestedWorkoutEvidenceBatch>;
 readPolicy:(scope:EvidenceScope,exerciseId:string)=>Promise<ReviewedEvidenceLearningPolicy|null>;
 revalidateEvidence:(tx:ReaderTx,scope:EvidenceScope,sourceRevision:string,policyFingerprint:string)=>Promise<boolean>;
 recommend:(item:QueueGenerationItem,kind:RecommendationKind,allowInference:boolean)=>Promise<QueueEngineResult>;
 validateCandidates:(tx:ReaderTx,item:QueueGenerationItem,kind:RecommendationKind,candidateFingerprint:string)=>Promise<boolean>;
}
const denied=()=>new DomainError('failed-precondition','Evidence source requires current reviewed authorization.');
const bindingPath=(org:string,fingerprint:string)=>`orgs/${org}/recommendationEvidenceBindings/${fingerprint}`;
const reason=(r:EvidenceAbstentionReason):'missing_consent'|'unsupported_evidence'|'insufficient_evidence'=>r==='missing_consent'?'missing_consent':['unsupported_exercise','incompatible_scoring'].includes(r)?'unsupported_evidence':'insufficient_evidence';
/** New local source composition only; no Firebase app, callable registration, policy default or provider. */
export function createEvidenceDrivenQueueSource(options:EvidenceQueueSourceOptions):QueueGenerationSource&{
 validateLead:(tx:ReaderTx,lead:RecommendationLead)=>Promise<boolean>;
 latestAbstentions:()=>readonly {memberId:string;exerciseId:string;reason:EvidenceAbstentionReason}[];
}{
 requireSyntheticQueue(options,options.organizationId);
 if(options.organizationId!=='gainpath'||options.members.length>20||new Set(options.members.map(m=>`${m.memberId}:${m.exerciseId}`)).size!==options.members.length)throw denied();
 const clock=options.clock??Date.now;let last:{memberId:string;exerciseId:string;reason:EvidenceAbstentionReason}[]=[];
 async function validateBinding(tx:ReaderTx,b:EvidenceQueueBinding,fingerprint:string,lead?:RecommendationLead):Promise<boolean>{
  try{
   keys(object(b),['schemaVersion','scope','exerciseId','need','kind','provenance','candidateFingerprint','deduplicationFingerprint','maximumAgeMillis','memberFingerprintAtExtraction','evidence']);validateNeed(b.need);
   keys(object(b.scope),['organizationId','memberId']);
   keys(object(b.provenance),['schemaVersion','origin','scope','window','sourceRevision','policyFingerprint','compatibilityFingerprint','evidenceFingerprint','duplicateRecords','latestCaptureAtMillis']);
   keys(object(b.provenance.scope),['organizationId','memberId']);keys(object(b.provenance.window),['startAtMillis','endAtMillis']);
   for(const hash of [fingerprint,b.candidateFingerprint,b.deduplicationFingerprint,b.memberFingerprintAtExtraction,b.provenance.sourceRevision,b.provenance.policyFingerprint,b.provenance.compatibilityFingerprint,b.provenance.evidenceFingerprint])if(typeof hash!=='string'||!/^[a-f0-9]{64}$/.test(hash))return false;
   for(const id of [b.scope.organizationId,b.scope.memberId,b.exerciseId])if(typeof id!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(id))return false;
   if(b.provenance.schemaVersion!==1||!['trainer','content'].includes(b.kind)||!Number.isSafeInteger(b.provenance.latestCaptureAtMillis)||b.provenance.latestCaptureAtMillis<0||b.provenance.latestCaptureAtMillis>clock())return false;
  }catch{return false;}
  if(!b||b.schemaVersion!==1||b.scope.organizationId!==options.organizationId||b.provenance.origin!=='validated_workout_evidence'||digestOf(b.scope)!==digestOf(b.provenance.scope)||b.exerciseId!==lead?.exerciseId&&lead!==undefined||digestOf(b)!==fingerprint)return false;
  if(b.deduplicationFingerprint!==digestOf({evidence:b.provenance.evidenceFingerprint,candidate:b.candidateFingerprint,kind:b.kind}))return false;
  if(lead&&(b.scope.memberId!==lead.memberId||b.kind!==lead.kind||lead.objective!==b.need.objective||lead.level!==b.need.level||digestOf(lead.evidence)!==digestOf(b.evidence)||queueBusinessKey(lead.organizationId,lead.memberId,lead.kind,lead.exerciseId,lead.objective,b.deduplicationFingerprint)!==lead.leadId))return false;
  const currentMember=await readRecommendationMemberState(tx,b.scope,clock(),options.noticePolicies??[],['exerciseInsights','recommendationGeneration']);
  if(!currentMember.eligible||currentMember.fingerprint!==b.memberFingerprintAtExtraction)return false;
  if(!await options.revalidateEvidence(tx,b.scope,b.provenance.sourceRevision,b.provenance.policyFingerprint))return false;
  if(!Number.isSafeInteger(b.maximumAgeMillis)||b.maximumAgeMillis<1||b.maximumAgeMillis>90*86400000||clock()-b.provenance.latestCaptureAtMillis>b.maximumAgeMillis)return false;
  const item:QueueGenerationItem={id:'fictional-evidence-validation',memberId:b.scope.memberId,need:b.need,exerciseId:b.exerciseId,memberLabel:'Synthetic Member',exerciseLabel:'Exercise',category:'Technique',evidenceStatus:'sufficient_synthetic'};
  return options.validateCandidates(tx,item,b.kind,b.candidateFingerprint);
 }
 const source:QueueGenerationSource&{validateLead:(tx:ReaderTx,lead:RecommendationLead)=>Promise<boolean>;latestAbstentions:()=>typeof last}={
  fixtureSetId:'module13-c-v1',organizationId:options.organizationId,sourceVersion:'evidence-preparation-required',configVersion:'reviewed-policy-required',validityMillis:options.validityMillis,items:[],inference:'mock_or_recorded_synthetic',
  recommend:async()=>{throw denied();},validate:async()=>false,
  latestAbstentions:()=>structuredClone(last),
  validateLead:async(tx,lead)=>{if(lead.organizationId!==options.organizationId)return false;const raw=await tx.get(bindingPath(lead.organizationId,lead.sourceFingerprint));return !!raw&&validateBinding(tx,raw as unknown as EvidenceQueueBinding,lead.sourceFingerprint,lead);},
  prepare:async()=>{
   const now=clock(),derived=new Map<string,DerivedEvidenceLearningNeed>(),extractionMembers=new Map<string,string>(),maxAges=new Map<string,number>();const abstentions:typeof last=[];const items:QueueGenerationItem[]=[];
   for(const m of options.members){
    const scope={organizationId:options.organizationId,memberId:m.memberId};
    const fresh=await options.readAuthIdentity(m.memberId);if(!fresh||fresh.uid!==m.memberId||fresh.disabled!==false||fresh.emailVerified!==true){abstentions.push({...m,reason:'missing_consent'});continue;}
    const before=await options.store.transact(async tx=>{
     const state=await readRecommendationMemberState(tx,scope,now,options.noticePolicies??[],['exerciseInsights','recommendationGeneration']);
     const consent=await tx.get(`orgs/${scope.organizationId}/recommendationConsent/${scope.memberId}`);
     const generationHistory=evaluateRecommendationConsentV2(consent,scope,now,options.noticePolicies??[],'recommendationGeneration');
     const history=evaluateRecommendationConsentV2(consent,scope,now,options.noticePolicies??[],'exerciseInsights');
     return{state,history,generationHistory};
    });
    if(!before.state.eligible||!before.history.allowed||!before.generationHistory.allowed||before.history.historyStartAtMillis===undefined||before.generationHistory.historyStartAtMillis===undefined||options.window.startAtMillis<Math.max(before.history.historyStartAtMillis,before.generationHistory.historyStartAtMillis)){abstentions.push({...m,reason:'missing_consent'});continue;}
    const policy=await options.readPolicy(scope,m.exerciseId);
    if(!policy){abstentions.push({...m,reason:'policy_unavailable'});continue;}
    try{evidenceLearningPolicyFingerprint(policy);}catch{abstentions.push({...m,reason:'invalid_policy'});continue;}
    if(policy.compatibility.exerciseId!==m.exerciseId){abstentions.push({...m,reason:'invalid_policy'});continue;}
    // Policy lookup may await a datastore. Recheck current Auth and all purpose/history
    // fingerprints before invoking the payload reader, rather than reading then rejecting.
    const sourceIdentity=await options.readAuthIdentity(m.memberId);
    if(!sourceIdentity||sourceIdentity.uid!==m.memberId||sourceIdentity.disabled!==false||sourceIdentity.emailVerified!==true)throw new DomainError('aborted','Evidence identity changed.');
    const beforeRead=await options.store.transact(tx=>readRecommendationMemberState(tx,scope,clock(),options.noticePolicies??[],['exerciseInsights','recommendationGeneration']));
    if(!beforeRead.eligible||beforeRead.fingerprint!==before.state.fingerprint)throw new DomainError('aborted','Evidence permissions changed.');
    // Reader failures refuse the entire refresh; never convert incomplete reads into poor form.
    const batch=await options.readEvidence(scope,options.window);
    const result=deriveEvidenceLearningNeed(scope,batch,policy,options.window,now,options.fypCapability);
    const after=await options.store.transact(tx=>readRecommendationMemberState(tx,scope,clock(),options.noticePolicies??[],['exerciseInsights','recommendationGeneration']));
    if(!after.eligible||after.fingerprint!==before.state.fingerprint)throw new DomainError('aborted','Evidence permissions changed.');
    if(result.status==='abstained'){abstentions.push({...m,reason:result.reason});continue;}
    const id=`fictional-evidence-${digestOf({memberId:m.memberId,exerciseId:m.exerciseId}).slice(0,32)}`;
    items.push({...m,id,need:result.need,evidenceStatus:'sufficient_synthetic',evidence:result.evidence});derived.set(id,result);extractionMembers.set(id,before.state.fingerprint);maxAges.set(id,policy.maximumAgeMillis);
   }
   last=abstentions;
   const bindings=new Map<string,EvidenceQueueBinding>(),itemFingerprints=new Map(items.map(i=>[i.id,digestOf(i)]));
   const prepared:QueueGenerationSource={fixtureSetId:'module13-c-v1',organizationId:options.organizationId,sourceVersion:digestOf([...derived.values()].map(d=>d.provenance.evidenceFingerprint)),configVersion:digestOf([...derived.values()].map(d=>d.provenance.policyFingerprint)),validityMillis:options.validityMillis,items,abstentions:abstentions.map(a=>({reason:reason(a.reason)})),inference:'mock_or_recorded_synthetic',
    recommend:async(item,kind,allowInference)=>{
     const d=derived.get(item.id);if(!d||digestOf(item)!==itemFingerprints.get(item.id)||digestOf(item.need)!==digestOf(d.need)||item.exerciseId!==d.exerciseId)throw denied();
     const engine=await options.recommend(item,kind,allowInference);
     const binding:EvidenceQueueBinding={schemaVersion:1,scope:d.provenance.scope,exerciseId:d.exerciseId,need:d.need,kind,provenance:d.provenance,candidateFingerprint:engine.sourceFingerprint,deduplicationFingerprint:digestOf({evidence:d.provenance.evidenceFingerprint,candidate:engine.sourceFingerprint,kind}),maximumAgeMillis:maxAges.get(item.id)!,memberFingerprintAtExtraction:extractionMembers.get(item.id)!,evidence:d.evidence};
     const sourceFingerprint=digestOf(binding);bindings.set(sourceFingerprint,binding);
     return{...engine,sourceFingerprint,deduplicationFingerprint:binding.deduplicationFingerprint,evidenceBinding:binding as unknown as DocumentData};
    },
    validate:async(tx,item,kind,fingerprint)=>{const b=bindings.get(fingerprint);return !!b&&b.kind===kind&&b.scope.memberId===item.memberId&&digestOf(item)===itemFingerprints.get(item.id)&&validateBinding(tx,b,fingerprint);},
   };markEvidenceQueueSource(prepared);return prepared;
  },
 };return source;
}
