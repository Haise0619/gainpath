/** Dedicated canonical-identity synthetic integration. Never imported by index.ts. */
import {Firestore,FieldPath} from 'firebase-admin/firestore';
import {DomainError} from '../src/platform/errors';
import type {DocumentData,DocumentStore,TransactionPort} from '../src/platform/firestore/store';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {session,row,modelVersion} from './exercise-insights-fixture';
import {trainerFixture,expertise,now as bookingNow} from './trainer-candidate.fixture';
import {createRecommendationConsentV2Command,evaluateRecommendationConsentV2,type ReviewedConsentNoticePolicy} from '../src/modules/recommendation/recommendation-consent-v2';
import {recommendContentCandidates,recommendTrainerCandidates} from '../src/modules/recommendation/recommendation-candidate-service';
import {createCurrentRecommendationTargetResolver} from '../src/modules/recommendation/recommendation-target-resolver';
import type {QueueGenerationItem,QueueEngineResult} from '../src/modules/recommendation/recommendation-queue-generation';
import type {RecommendationKind,RecommendationLead} from '../src/modules/recommendation/recommendation-queue-contracts';
import {readRecommendationMemberState,type QueueSecurityDependencies} from '../src/modules/recommendation/recommendation-queue-security';
import type {RankingProvider} from '../src/modules/recommendation/recommendation-ranking-contracts';
import {createEvidenceDrivenQueueSource} from '../src/modules/recommendation/evidence-queue-source';
import type {AttestedWorkoutEvidenceBatch,ReviewedEvidenceLearningPolicy} from '../src/modules/recommendation/evidence-learning-need';

export const FINAL_PROJECT='demo-gainpath-module13-final',FINAL_HOST='127.0.0.1:18117',FINAL_ROOT='orgs/gainpath';
export const FINAL_NOW=Date.parse('2026-11-02T00:00:00Z'),FINAL_MEMBER='fictional-member',FINAL_ADMIN='fictional-admin',FINAL_COACH='fictional-coach',FINAL_EXERCISE='F3b8xIr8ynBDd3gEICKX';
export const FINAL_WINDOW={startAtMillis:FINAL_NOW-30*86400000,endAtMillis:FINAL_NOW};
export const finalNotice:ReviewedConsentNoticePolicy={policyId:'synthetic-final-notice',noticeVersion:'v1',contentVersion:'v1',history:{mode:'retained',earliestAtMillis:FINAL_NOW-40*86400000}};
export const finalPolicy:ReviewedEvidenceLearningPolicy={schemaVersion:1,mode:'synthetic_reviewed',policyId:'synthetic-squat-education',reviewVersion:'fixture-v1',compatibility:{exerciseId:FINAL_EXERCISE,metricSchemaVersion:1,scoringVersion:'bodyweight-squat-side-v1',detectorId:'blazepose-tflite',detectorVersion:modelVersion,cameraView:'side',mode:'not_applicable',scoreSupport:'scored'},provisionalSamplePolicy:{schemaVersion:1,revision:'synthetic-three-days-v1',minimumScoredSessions:3,minimumDistinctDays:3,minimumAssessedAttempts:30,minimumTrackingCoverage:.8},attentionThreshold:{operator:'score_below',estimatedFormScorePercent:65},objective:'technique_foundations',level:'beginner',maximumAgeMillis:7*86400000};
export function guardModule13Final(db?:Firestore):void{
 const fail=()=>{throw new DomainError('failed-precondition','Dedicated canonical synthetic emulator required.');};
 if(process.env.FIRESTORE_EMULATOR_HOST!==FINAL_HOST||process.env.GCLOUD_PROJECT!==FINAL_PROJECT||process.env.GOOGLE_CLOUD_PROJECT!==FINAL_PROJECT)fail();
 if(db){const binding=db as unknown as {projectId:unknown;_settings:Record<string,unknown>};if(!(db instanceof Firestore)||binding.projectId!==FINAL_PROJECT||binding._settings.servicePath!=='127.0.0.1'||binding._settings.port!==18117||binding._settings.ssl!==false)fail();}
}
export function finalClock(){const started=Date.now();return()=>FINAL_NOW+1000+Date.now()-started;}
function rename(value:unknown):any{
 if(typeof value==='string'){for(const[a,b]of Object.entries({'org-1':'gainpath','member-1':FINAL_MEMBER,'coach-1':FINAL_COACH,'staff-1':'fictional-staff','branch-1':'fictional-branch','branch-2':'fictional-other-branch','2026-10-02':'2026-11-03'}))value=(value as string).replaceAll(a,b);return value;}
 if(typeof value==='number'&&value>=bookingNow)return value+FINAL_NOW-bookingNow;
 if(Array.isArray(value))return value.map(rename);
 if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[rename(k),rename(v)]));
 return value;
}
function publication(suffix:string):DocumentData{return{schemaVersion:1,kind:'routine',status:'published',sourceBlueprintId:`fictional-blueprint-${suffix}`,title:`Fictional squat lesson ${suffix}`,estimatedMinutes:10,difficulty:'Beginner',exercises:[{exerciseId:FINAL_EXERCISE,name:`Fictional squat tutorial ${suffix.toUpperCase()}`,sets:2,reps:5,dayNumber:1,tutorialSteps:[{title:'Stance',description:suffix==='a'?'Practice foundational squat stance with controlled depth and steady movement.':'Practice beginner squat technique using patient step-by-step foundations and controlled movement.'}]}]};}
const publications=['fictional-routine-a','fictional-routine-b'];
const suitability=publications.map((id,i)=>({id:`fictional-curation-${i}`,publicationId:id,exerciseIndex:0,publicationDigest:digestOf(publication(i?'b':'a')),objectives:['technique_foundations' as const],levels:['beginner' as const]}));
const trustedExpertise=[{...rename(expertise),teachingFocus:'Fictional beginner squat foundations.'}];
export function module13FinalDocuments():Record<string,DocumentData>{
 const docs:Record<string,DocumentData>={};for(const[p,d]of trainerFixture().store.documents)docs[rename(p)]=rename(d);
 Object.assign(docs[`${FINAL_ROOT}/coaches/${FINAL_COACH}`],{displayName:'Fictional Coach Amira',bio:'Fictional reviewed educational profile.',specialty:'Squat foundations'});
 for(const[uid,role]of [[FINAL_ADMIN,'admin'],[FINAL_MEMBER,'member'],[FINAL_COACH,'coach'],['fictional-member-peer','member']]){
  docs[`users/${uid}`]={...docs[`users/${uid}`],organizationId:'gainpath',role};
  docs[`${FINAL_ROOT}/members/${uid}`]={...docs[`${FINAL_ROOT}/members/${uid}`],organizationId:'gainpath',userId:uid,role,status:'active',branchIds:role==='admin'?[]:['fictional-branch']};
 }
 docs[`${FINAL_ROOT}/exerciseVideos/${FINAL_EXERCISE}`]={isActive:true,exerciseName:'Squat',muscleCategory:'Lower Body'};
 for(const[i,id]of publications.entries())docs[`${FINAL_ROOT}/content/${id}`]=publication(i?'b':'a');
 docs[`${FINAL_ROOT}/recommendationEvidencePolicies/${FINAL_EXERCISE}`]=structuredClone(finalPolicy) as unknown as DocumentData;
 for(const memberId of [FINAL_MEMBER,'fictional-member-peer']){
  for(const[i,score]of [58,62,66].entries()){
   const p=session(`fictional-session-${i}`,score,new Date(FINAL_NOW-(3-i)*86400000).toISOString());p.userId=memberId;
   const backup=row(p,`capture-${i}`).data;backup.updatedAtMillis=FINAL_NOW-1000;
   const backupPath=`${FINAL_ROOT}/members/${memberId}/workoutBackups/${backup.key}`;
   docs[backupPath]=backup;
   docs[`${FINAL_ROOT}/members/${memberId}/workoutEvidenceCaptures/capture-${i}`]={schemaVersion:1,rowId:`capture-${i}`,organizationId:'gainpath',memberId,recordKey:backup.key,digest:backup.digest,updatedAtMillis:backup.updatedAtMillis,capturedAtMillis:Date.parse(p.endedAt as string),trust:'synthetic_emulator_attested',backupPath};
   if(i===0){
    const old=structuredClone(p);
    const oldBackup=row(old,'capture-old').data;oldBackup.updatedAtMillis=FINAL_NOW-2000;
    const oldPath=`${backupPath}/revisions/fictional-previous`;docs[oldPath]=oldBackup;
    docs[`${FINAL_ROOT}/members/${memberId}/workoutEvidenceCaptures/capture-old`]={...docs[`${FINAL_ROOT}/members/${memberId}/workoutEvidenceCaptures/capture-0`],rowId:'capture-old',digest:oldBackup.digest,updatedAtMillis:oldBackup.updatedAtMillis,backupPath:oldPath};
   }
  }
  // Poisoned out-of-scope payload proves that capture-window queries precede payload reads.
  const excludedPath=`${FINAL_ROOT}/members/${memberId}/workoutBackups/session-excluded`;
  docs[excludedPath]={payloadJson:'MUST NEVER BE READ',classification:'provisional_member_backup'};
  docs[`${FINAL_ROOT}/members/${memberId}/workoutEvidenceCaptures/capture-excluded`]={schemaVersion:1,rowId:'capture-excluded',organizationId:'gainpath',memberId,recordKey:'session-excluded',digest:'0'.repeat(64),updatedAtMillis:FINAL_NOW-1000,capturedAtMillis:FINAL_NOW-50*86400000,trust:'synthetic_emulator_attested',backupPath:excludedPath};
 }
 return docs;
}
export function createFinalEvidenceReader(db:Firestore,afterMetadata?:()=>Promise<void>){
 const store=new FirestoreStore(db);
 const trace={metadataQueries:0,payloadReads:0,paths:[] as string[],windows:[] as {startAtMillis:number;endAtMillis:number}[]};
 const read=async(scope:{organizationId:string;memberId:string},window:{startAtMillis:number;endAtMillis:number}):Promise<AttestedWorkoutEvidenceBatch>=>{
  guardModule13Final(db);if(scope.organizationId!=='gainpath'||![FINAL_MEMBER,'fictional-member-peer'].includes(scope.memberId)||!Number.isSafeInteger(window.startAtMillis)||!Number.isSafeInteger(window.endAtMillis)||window.startAtMillis<FINAL_NOW-40*86400000||window.endAtMillis>FINAL_NOW+86400000||window.endAtMillis<=window.startAtMillis||window.endAtMillis-window.startAtMillis>90*86400000)throw new DomainError('permission-denied','Invalid permitted synthetic source scope.');
  const purposeState=async(tx:Pick<TransactionPort,'get'|'getAll'>)=>{
   const state=await readRecommendationMemberState(tx,scope,Date.now(),[finalNotice],['exerciseInsights','recommendationGeneration']);
   const consent=await tx.get(`${FINAL_ROOT}/recommendationConsent/${scope.memberId}`);
   const decisions=['exerciseInsights','recommendationGeneration'].map(p=>evaluateRecommendationConsentV2(consent,scope,Date.now(),[finalNotice],p as 'exerciseInsights'|'recommendationGeneration'));
   if(!state.eligible||decisions.some(d=>!d.allowed||d.historyStartAtMillis===undefined||window.startAtMillis<d.historyStartAtMillis))throw new DomainError('permission-denied','Current scoped recommendation permission required.');
   return state;
  };
  const before=await store.transact(purposeState);
  trace.metadataQueries++;trace.windows.push({...window});
  const snapshot=await db.collection(`${FINAL_ROOT}/members/${scope.memberId}/workoutEvidenceCaptures`).where('capturedAtMillis','>=',window.startAtMillis).where('capturedAtMillis','<',window.endAtMillis).orderBy('capturedAtMillis').orderBy(FieldPath.documentId()).limit(101).get();
  if(snapshot.size>100)throw new DomainError('resource-exhausted','Bounded evidence source exceeded.');
  await afterMetadata?.();
  const metadata=snapshot.docs.map(d=>({id:d.id,data:d.data()})),rows:AttestedWorkoutEvidenceBatch['rows'][number][]=[],attestations:AttestedWorkoutEvidenceBatch['attestations'][number][]=[];
  for(const m of metadata){const a=m.data,prefix=`${FINAL_ROOT}/members/${scope.memberId}/workoutBackups/`;if(a.schemaVersion!==1||a.organizationId!==scope.organizationId||a.memberId!==scope.memberId||a.rowId!==m.id||a.trust!=='synthetic_emulator_attested'||typeof a.backupPath!=='string'||!a.backupPath.startsWith(prefix)||a.backupPath.includes('..'))throw new DomainError('failed-precondition','Invalid trusted capture metadata.');
   const head=await store.transact(async tx=>{
    const current=await purposeState(tx);if(current.fingerprint!==before.fingerprint)throw new DomainError('aborted','Source permission changed.');
    trace.paths.push(a.backupPath);trace.payloadReads++;return tx.get(a.backupPath);
   });if(!head)throw new DomainError('failed-precondition','Missing attested source.');rows.push({id:m.id,data:head});
   const {backupPath:_path,schemaVersion:_schema,...attestation}=a;attestations.push(attestation as unknown as AttestedWorkoutEvidenceBatch['attestations'][number]);
  }
  return{schemaVersion:1,scope:{...scope},window:{...window},rows,attestations,sourceRevision:digestOf({metadata,rows})};
 };
 return{read,trace};
}

export async function createModule13FinalFixture(options:{store:DocumentStore;db:Firestore;clock?:()=>number}){
 const {store,db}=options,clock=options.clock??finalClock(),reader=createFinalEvidenceReader(db),known=new Set([FINAL_ADMIN,FINAL_MEMBER,FINAL_COACH,'fictional-member-peer']);
 const deps:QueueSecurityDependencies={store,clock,localFixture:{fixtureSetId:'module13-c-v1',organizationId:'gainpath'},noticePolicies:[finalNotice],readAuthIdentity:async uid=>({uid,email:`${uid}@example.invalid`,emailVerified:known.has(uid),disabled:!known.has(uid),tokensValidAfterMillis:0})};
 const request={app:{appId:'synthetic-final-appcheck-context'},auth:{uid:FINAL_ADMIN,token:{email_verified:true,email:`${FINAL_ADMIN}@example.invalid`,auth_time:100}},data:{schemaVersion:1,organizationId:'gainpath'}};
 const grant=createRecommendationConsentV2Command({...deps,clock:()=>FINAL_NOW-5*86400000});
 for(const uid of [FINAL_MEMBER,'fictional-member-peer']){let revision=0;for(const purpose of ['exerciseInsights','recommendationGeneration','recommendationDelivery','externalAiInference'])await grant({...request,auth:{...request.auth,uid,token:{...request.auth.token,email:`${uid}@example.invalid`}},data:{schemaVersion:2,organizationId:'gainpath',commandId:`synthetic-grant-${purpose}`,expectedRevision:revision++,purpose,action:'grant',noticePolicyId:finalNotice.policyId,acceptedNoticeVersion:finalNotice.noticeVersion,acceptedContentVersion:finalNotice.contentVersion}});}
 const providerPayloads:unknown[]=[];
 const provider:RankingProvider=async payload=>{providerPayloads.push(structuredClone(payload));return{text:JSON.stringify({schemaVersion:1,rankings:payload.candidates.map((c,i)=>({label:c.label,relevance:i?90:75,reasonCodes:['objective_match'],evidenceRefs:[c.evidence.find(e=>e.kind==='objective_match')!.ref],abstain:false}))}),model:'synthetic-structured-mock-v1',latencyMillis:0,usage:{inputTokens:null,outputTokens:null,thinkingTokens:null,totalTokens:null}};};
 async function engine(item:QueueGenerationItem,kind:RecommendationKind,tx?:Pick<TransactionPort,'get'|'getAll'>,infer=false):Promise<QueueEngineResult>{
  const facts=new Map<string,unknown>(),wrap=(snapshot:Pick<TransactionPort,'get'|'getAll'>)=>({get:async(path:string)=>{const d=await snapshot.get(path);facts.set(path,d??null);return d;}});
  const transact=<T>(work:(snapshot:Pick<TransactionPort,'get'|'getAll'>)=>Promise<T>)=>tx?work(wrap(tx)):store.transact(snapshot=>work(wrap(snapshot)));
  const optionsForB={context:{mode:'synthetic_local' as const,datasetId:'module13-batch-b-v1' as const,organizationId:'gainpath' as const,evidenceStatus:item.evidenceStatus},exerciseMapping:{exercise:item.need.exercise,exerciseId:item.exerciseId,version:'synthetic-exercise-v1' as const},...(infer?{provider}:{})};
  const recommendation=kind==='trainer'?await recommendTrainerCandidates(item.need,{schemaVersion:1,organizationId:'gainpath',memberId:item.memberId,exerciseId:item.exerciseId,learningObjective:item.need.objective,level:item.need.level,localDate:'2026-11-03',durationMinutes:60},{repository:{transact,listCoachIds:async()=>[FINAL_COACH]},trustedExpertise,clock,readIdentity:async uid=>({exists:known.has(uid),disabled:false,emailVerified:true})},optionsForB):await transact(async snapshot=>recommendContentCandidates(item.need,{organizationId:'gainpath',exerciseId:item.exerciseId,objective:item.need.objective,level:item.need.level},{schemaVersion:1,organizationId:'gainpath',sourceVersion:'canonical-published-synthetic-v1',curationVersion:'synthetic-curation-v1',memberAccess:'organization_published_routines',catalog:[{id:FINAL_EXERCISE,data:await snapshot.get(`${FINAL_ROOT}/exerciseVideos/${FINAL_EXERCISE}`)??{}}],publications:await Promise.all(publications.map(async id=>({id,data:await snapshot.get(`${FINAL_ROOT}/content/${id}`)??{status:'missing'}}))),suitability,compatibleExercises:[]},optionsForB));
  return{recommendation,sourceFingerprint:digestOf({kind,need:item.need,exerciseId:item.exerciseId,trustedExpertise,suitability,facts:[...facts].sort(([a],[b])=>a.localeCompare(b))}),targetLabels:{[FINAL_COACH]:{label:'Fictional Coach Amira',specialization:'Squat foundations',branchLabel:'Fictional Central Branch'}}};
 }
 const source=createEvidenceDrivenQueueSource({...deps,organizationId:'gainpath',members:[{memberId:FINAL_MEMBER,memberLabel:'Fictional Member Maya',exerciseId:FINAL_EXERCISE,exerciseLabel:'Squat',category:'Lower Body'}],window:FINAL_WINDOW,validityMillis:86400000,store,readAuthIdentity:deps.readAuthIdentity,clock,noticePolicies:[finalNotice],readEvidence:reader.read,readPolicy:async()=>((await db.doc(`${FINAL_ROOT}/recommendationEvidencePolicies/${FINAL_EXERCISE}`).get()).data()??null) as ReviewedEvidenceLearningPolicy|null,
  revalidateEvidence:async(tx,scope,sourceRevision,policyFingerprint)=>{
   // Every possible fixture capture is known to the reviewed source manifest; no transaction query or payload scan.
   const ids=['capture-0','capture-1','capture-2','capture-old'],metadata:{id:string;data:DocumentData}[]=[],rows:{id:string;data:DocumentData|undefined}[]=[];
   for(const id of ids){const a=await tx.get(`${FINAL_ROOT}/members/${scope.memberId}/workoutEvidenceCaptures/${id}`);if(!a||typeof a.backupPath!=='string'||!a.backupPath.startsWith(`${FINAL_ROOT}/members/${scope.memberId}/workoutBackups/`))return false;metadata.push({id,data:a});rows.push({id,data:await tx.get(a.backupPath)});}
   metadata.sort((a,b)=>Number(a.data.capturedAtMillis)-Number(b.data.capturedAtMillis)||a.id.localeCompare(b.id));rows.sort((a,b)=>metadata.findIndex(m=>m.id===a.id)-metadata.findIndex(m=>m.id===b.id));
   return digestOf({metadata,rows})===sourceRevision&&digestOf(await tx.get(`${FINAL_ROOT}/recommendationEvidencePolicies/${FINAL_EXERCISE}`))===policyFingerprint;
  },recommend:(item,kind,allow)=>engine(item,kind,undefined,allow),validateCandidates:async(tx,item,kind,fingerprint)=>(await engine(item,kind,tx)).sourceFingerprint===fingerprint});
 const validateTarget=async(tx:Pick<TransactionPort,'get'|'getAll'>,lead:RecommendationLead):Promise<'valid'|'stale'>=>await source.validateLead(tx,lead)?'valid':'stale';
 return{deps:{...deps,localDelivery:{fixtureSetId:'module13-d-v1' as const},resolveTarget:createCurrentRecommendationTargetResolver({organizationId:'gainpath',revalidateEligibility:validateTarget})},request,source,validateTarget,reader,providerPayloads};
}
