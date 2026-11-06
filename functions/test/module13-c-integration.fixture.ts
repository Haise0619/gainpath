/** Test-only compiled fictional source composition. Never imported by index.ts. */
import type {DocumentData,DocumentStore,TransactionPort} from '../src/platform/firestore/store';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {recommendContentCandidates,recommendTrainerCandidates} from '../src/modules/recommendation/recommendation-candidate-service';
import {createRecommendationConsentV2Command,type ReviewedConsentNoticePolicy} from '../src/modules/recommendation/recommendation-consent-v2';
import type {QueueGenerationItem,QueueGenerationSource,QueueEngineResult} from '../src/modules/recommendation/recommendation-queue-generation';
import type {RecommendationLead,RecommendationKind} from '../src/modules/recommendation/recommendation-queue-contracts';
import type {QueueSecurityDependencies} from '../src/modules/recommendation/recommendation-queue-security';
import type {ContentCandidateSource,ContentCandidateResult} from '../src/modules/recommendation/content-candidate-eligibility';
import type {TrainerCandidateResult} from '../src/modules/recommendation/trainer-candidate-eligibility';
import type {RankingProvider} from '../src/modules/recommendation/recommendation-ranking-contracts';
import {trainerFixture,expertise,now as oldNow} from './trainer-candidate.fixture';

export const MODULE13_C_NOW=Date.parse('2026-11-01T00:00:00Z');
export const MODULE13_C_ORG='synthetic-org';
export const MODULE13_C_MEMBER='fictional-member';
export const MODULE13_C_ADMIN='fictional-admin';
export const MODULE13_C_COACH='fictional-coach';
const ROOT=`orgs/${MODULE13_C_ORG}`,EXERCISE='fictional-squat',SOURCE='module13-c-persisted-synthetic-v1',CONFIG='module13-c-curation-v1';
const notice:ReviewedConsentNoticePolicy={policyId:'fictional-notice',noticeVersion:'v1',contentVersion:'v1',history:{mode:'from_grant'}};
const substitutions:Record<string,string>={'org-1':MODULE13_C_ORG,'member-1':MODULE13_C_MEMBER,'coach-1':MODULE13_C_COACH,'staff-1':'fictional-staff','branch-1':'fictional-branch','branch-2':'fictional-other-branch','F3b8xIr8ynBDd3gEICKX':EXERCISE,'2026-10-02':'2026-11-02'};
function rename(value:unknown):any{
  if(typeof value==='string'){for(const [a,b] of Object.entries(substitutions))value=(value as string).replaceAll(a,b);return value;}
  if(typeof value==='number'&&value>=oldNow)return value+MODULE13_C_NOW-oldNow;
  if(Array.isArray(value))return value.map(rename);
  if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[rename(k),rename(v)]));
  return value;
}
function publication(suffix:string):DocumentData{return{schemaVersion:1,kind:'routine',status:'published',sourceBlueprintId:`fictional-blueprint-${suffix}`,title:`Fictional squat lesson ${suffix}`,estimatedMinutes:10,difficulty:'Beginner',exercises:[{exerciseId:EXERCISE,name:`Fictional squat tutorial ${suffix.toUpperCase()}`,sets:2,reps:5,dayNumber:1,tutorialSteps:[{title:'Stance',description:'Practice foundational squat stance with controlled depth and steady movement.'}]}]};}
const publications=['fictional-routine-a','fictional-routine-b'];
const suitability=publications.map((id,i)=>({id:`fictional-curation-${i}`,publicationId:id,exerciseIndex:0,publicationDigest:digestOf(publication(i?'b':'a')),objectives:['technique_foundations' as const],levels:['beginner' as const]}));
const trustedExpertise=[{...rename(expertise),teachingFocus:'Fictional beginner squat foundations.'}];
export function module13CFixtureDocuments():Record<string,DocumentData>{
  const old=trainerFixture().store.documents;
  const docs:Record<string,DocumentData>={};for(const [p,d]of old)docs[rename(p)]=rename(d);
  docs[`${ROOT}/coaches/${MODULE13_C_COACH}`].displayName='Fictional Coach Amira';
  docs[`${ROOT}/coaches/${MODULE13_C_COACH}`].bio='Fictional reviewed educational profile.';
  docs[`${ROOT}/coaches/${MODULE13_C_COACH}`].specialty='Squat foundations';
  for(const [uid,role]of [[MODULE13_C_ADMIN,'admin'],[MODULE13_C_MEMBER,'member'],[MODULE13_C_COACH,'coach']]){
    docs[`users/${uid}`]={...docs[`users/${uid}`],organizationId:MODULE13_C_ORG,role};
    docs[`${ROOT}/members/${uid}`]={...docs[`${ROOT}/members/${uid}`],organizationId:MODULE13_C_ORG,userId:uid,role,status:'active',branchIds:uid===MODULE13_C_ADMIN?[]:['fictional-branch']};
  }
  docs[`${ROOT}/exerciseVideos/${EXERCISE}`]={isActive:true,exerciseName:'Fictional squat',muscleCategory:'Lower Body'};
  for(const [i,id]of publications.entries())docs[`${ROOT}/content/${id}`]=publication(i?'b':'a');
  return docs;
}
const manifest:readonly QueueGenerationItem[]=[{id:'fictional-squat-need',memberId:MODULE13_C_MEMBER,need:{exercise:'squat',objective:'technique_foundations',level:'beginner'},exerciseId:EXERCISE,memberLabel:'Fictional Member Maya',exerciseLabel:'Squat',category:'Lower Body',evidenceStatus:'sufficient_synthetic'}];
const knownUsers=new Set([MODULE13_C_ADMIN,MODULE13_C_MEMBER,MODULE13_C_COACH]);
const mockProvider:RankingProvider=async request=>({text:JSON.stringify({schemaVersion:1,rankings:request.candidates.map((c,i)=>({label:c.label,relevance:i?90:75,reasonCodes:['objective_match'],evidenceRefs:[c.evidence.find(e=>e.kind==='objective_match')!.ref],abstain:false}))}),model:'synthetic-recorded-mock-v1',latencyMillis:0,usage:{inputTokens:null,outputTokens:null,thinkingTokens:null,totalTokens:null}});
export async function createModule13CFixture(options:{store:DocumentStore;clock?:()=>number;grantConsent?:boolean;provider?:RankingProvider|null}){
  const clock=options.clock??(()=>MODULE13_C_NOW),store=options.store;
  const deps:QueueSecurityDependencies={store,clock,localFixture:{fixtureSetId:'module13-c-v1',organizationId:MODULE13_C_ORG},noticePolicies:[notice],
    readAuthIdentity:async uid=>({uid,email:`${uid}@example.invalid`,emailVerified:knownUsers.has(uid),disabled:!knownUsers.has(uid),tokensValidAfterMillis:0})};
  const request={app:{appId:'module13-c-trusted-fixture-injection'},auth:{uid:MODULE13_C_ADMIN,token:{email_verified:true,email:`${MODULE13_C_ADMIN}@example.invalid`,auth_time:100}},data:{schemaVersion:1,organizationId:MODULE13_C_ORG}};
  if(options.grantConsent!==false){
    const grant=createRecommendationConsentV2Command(deps);let revision=0;
    for(const purpose of ['exerciseInsights','recommendationGeneration','recommendationDelivery','externalAiInference'])await grant({...request,auth:{...request.auth,uid:MODULE13_C_MEMBER,token:{...request.auth.token,email:`${MODULE13_C_MEMBER}@example.invalid`}},data:{schemaVersion:2,organizationId:MODULE13_C_ORG,commandId:`fixture-grant-${purpose}`,expectedRevision:revision++,purpose,action:'grant',noticePolicyId:notice.policyId,acceptedNoticeVersion:notice.noticeVersion,acceptedContentVersion:notice.contentVersion}});
  }
  async function engine(item:QueueGenerationItem,kind:RecommendationKind,tx?:Pick<TransactionPort,'get'|'getAll'>,infer=false):Promise<QueueEngineResult>{
    if(digestOf(item)!==digestOf(manifest[0]))throw Error('Unknown compiled synthetic fixture need');
    const facts=new Map<string,unknown>();
    const wrap=(snapshot:Pick<TransactionPort,'get'|'getAll'>)=>({get:async(path:string)=>{const d=await snapshot.get(path);facts.set(path,d??null);return d;}});
    const transact=<T>(work:(snapshot:Pick<TransactionPort,'get'|'getAll'>)=>Promise<T>)=>tx?work(wrap(tx)):store.transact(snapshot=>work(wrap(snapshot)));
    const optionsForB={context:{mode:'synthetic_local' as const,datasetId:'module13-batch-b-v1' as const,organizationId:'synthetic-org' as const,evidenceStatus:item.evidenceStatus},exerciseMapping:{exercise:item.need.exercise,exerciseId:item.exerciseId,version:'synthetic-exercise-v1' as const},...(infer&&options.provider!==null?{provider:options.provider??mockProvider}:{})};
    const recommendation=kind==='trainer'?await recommendTrainerCandidates(item.need,{schemaVersion:1,organizationId:MODULE13_C_ORG,memberId:item.memberId,exerciseId:item.exerciseId,learningObjective:item.need.objective,level:item.need.level,localDate:'2026-11-02',durationMinutes:60},{repository:{transact,listCoachIds:async()=>[MODULE13_C_COACH]},trustedExpertise,clock,
      // Fixed fictional Auth facts only. Canonical account and membership documents
      // are still re-read by B. This function performs no Auth/network effect.
      readIdentity:async uid=>({exists:knownUsers.has(uid),disabled:false,emailVerified:true})},optionsForB):await transact(async snapshot=>{
        const source:ContentCandidateSource={schemaVersion:1,organizationId:MODULE13_C_ORG,sourceVersion:SOURCE,curationVersion:CONFIG,memberAccess:'organization_published_routines',catalog:[{id:EXERCISE,data:await snapshot.get(`${ROOT}/exerciseVideos/${EXERCISE}`)??{}}],publications:await Promise.all(publications.map(async id=>({id,data:await snapshot.get(`${ROOT}/content/${id}`)??{status:'missing'}}))),suitability,compatibleExercises:[]};
        return recommendContentCandidates(item.need,{organizationId:MODULE13_C_ORG,exerciseId:item.exerciseId,objective:item.need.objective,level:item.need.level},source,optionsForB);
      });
    const sourceFingerprint=digestOf({fixtureSetId:'module13-c-v1',item,kind,sourceVersion:SOURCE,configVersion:CONFIG,trustedExpertise,suitability,publications,facts:[...facts].sort(([a],[b])=>a.localeCompare(b))});
    return{recommendation,sourceFingerprint,targetLabels:{[MODULE13_C_COACH]:{label:'Fictional Coach Amira',specialization:'Squat foundations',branchLabel:'Fictional Central Branch'}}};
  }
  const source:QueueGenerationSource={fixtureSetId:'module13-c-v1',sourceVersion:SOURCE,configVersion:CONFIG,validityMillis:86400000,items:structuredClone([...manifest]),inference:'mock_or_recorded_synthetic',recommend:(item,kind,allowInference)=>engine(item,kind,undefined,allowInference===true),validate:async(tx,item,kind,fingerprint)=>(await engine(item,kind,tx)).sourceFingerprint===fingerprint};
  const validateTarget=async(tx:Pick<TransactionPort,'get'|'getAll'>,lead:RecommendationLead):Promise<'valid'|'stale'>=>{
    const run=await tx.get(`${ROOT}/recommendationRuns/${lead.runId}`);
    if(run?.summary===undefined||(run.summary as Record<string,unknown>).status!=='complete')return'stale';
    const item=source.items.find(i=>i.memberId===lead.memberId&&i.exerciseId===lead.exerciseId&&i.need.objective===lead.objective&&i.need.level===lead.level);
    if(!item)return'stale';
    const current=await engine(item,lead.kind,tx);
    if(current.sourceFingerprint!==lead.sourceFingerprint)return'stale';
    if(lead.target.kind==='content')return(current.recommendation.eligibility as ContentCandidateResult)?.candidates.some(c=>digestOf(c.destination)===digestOf(lead.target.kind==='content'?lead.target.destination:null))?'valid':'stale';
    const target=lead.target;return(current.recommendation.eligibility as TrainerCandidateResult)?.candidates.some(c=>c.coachId===target.coachId&&c.availableOptions.some(o=>o.branchId===target.branchId&&o.startAtMillis===target.observedStartAtMillis&&o.endAtMillis===target.observedEndAtMillis))?'valid':'stale';
  };
  return{deps,request,source,validateTarget};
}
