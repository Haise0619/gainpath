import {FieldPath,type Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import type {DocumentData,DocumentStore,TransactionPort} from '../../platform/firestore/store';
import {digestOf,keys,object} from '../workouts/workout-backup-validation';
import {listWorkoutBackups,type BackupStore} from '../workouts/workout-backup';
import {recommendTrainerCandidates,recommendContentCandidates} from './recommendation-candidate-service';
import {createEvidenceDrivenQueueSource,type EvidenceQueueMember} from './evidence-queue-source';
import type {AttestedWorkoutEvidenceBatch,ReviewedEvidenceLearningPolicy} from './evidence-learning-need';
import {createCurrentRecommendationTargetResolver} from './recommendation-target-resolver';
import {readRecommendationMemberState,type QueueSecurityDependencies} from './recommendation-queue-security';
import {evaluateRecommendationConsentV2} from './recommendation-consent-v2';
import type {FreshAuthIdentity,InsightsRequest,EvidenceScope,EvidenceRow} from './exercise-insights-contracts';
import {exerciseInsightsHandler} from './exercise-insights';
import {projectExerciseInsights} from './exercise-insights-presentation';
import {defaultRecommendationConfiguration,parseRecommendationConfiguration} from './recommendation-configuration';
import type {QueueEngineResult,QueueGenerationItem} from './recommendation-queue-generation';
import type {RecommendationLead,RecommendationKind} from './recommendation-queue-contracts';
import type {TrustedTrainerExpertise} from './trainer-candidate-eligibility';
import type {CuratedContentSuitability} from './content-candidate-eligibility';
import type {RankingProvider} from './recommendation-ranking-contracts';
import type {Module13DemoManifest} from './demo-access-policy';
import {requireFypQueryRoot} from '../dataset/fyp-scope';

const ROOT='orgs/gainpath';
type ReadTx=Pick<TransactionPort,'get'|'getAll'>;
interface DemoSource {schemaVersion:1;seedId:string;clockMillis:number;bookingDate:string;window:{startAtMillis:number;endAtMillis:number};members:EvidenceQueueMember[];coachIds:string[];publicationIds:string[];catalogIds:string[];expertisePaths:string[];suitabilityPaths:string[];policyByMember:Record<string,string>;policyPaths:Record<string,string>}
const unavailable=()=>new DomainError('failed-precondition','The controlled demo source requires review.');
/** Data queries are bound to one immutable server-owned source manifest in the
 * named database. No collection-group/default-database fallbacks exist. */
export async function createModule13DemoDataAdapters(options:{db:Firestore;manifest:Pick<Module13DemoManifest,'seedId'|'memberIds'|'coachIds'|'recordPaths'|'noticePolicies'>;store:DocumentStore;deps:QueueSecurityDependencies;readAuthIdentity:(uid:string)=>Promise<FreshAuthIdentity>;clock:()=>number;
 queryRoot?:string;
 observations?:{read:(scope:EvidenceScope,window:DemoSource['window'],generation:boolean)=>Promise<AttestedWorkoutEvidenceBatch>;revalidate:(tx:ReadTx,scope:EvidenceScope,revision:string,policyFingerprint:string)=>Promise<boolean>};
}){
 const{db,manifest,store,deps,readAuthIdentity,clock}=options;
 const queryRoot=options.queryRoot??ROOT;
 if(queryRoot!==ROOT){if(!options.observations)throw unavailable();requireFypQueryRoot(deps.fypCapability,queryRoot);}
 const logical=(path:string)=>queryRoot===ROOT?path:path.startsWith(queryRoot+'/')?ROOT+path.slice(queryRoot.length):(()=>{throw unavailable();})();
 const storedSource=await store.transact(async tx=>await tx.get('module13DemoSource/current')) as unknown as DemoSource;
 const source=storedSource&&queryRoot!==ROOT?{...storedSource,expertisePaths:storedSource.expertisePaths.map(logical),suitabilityPaths:storedSource.suitabilityPaths.map(logical),policyPaths:Object.fromEntries(Object.entries(storedSource.policyPaths).map(([id,path])=>[id,logical(path)]))}:storedSource;
 if(!source||source.schemaVersion!==1||source.seedId!==manifest.seedId||!Array.isArray(source.members)||source.members.length>20||source.members.some(m=>!manifest.memberIds.includes(m.memberId))||source.coachIds.some(id=>!manifest.coachIds.includes(id)))throw unavailable();
 const approvedPaths=new Set(manifest.recordPaths);
 const readRows=(paths:string[],tx?:ReadTx)=>{if(paths.length>500||paths.some(p=>!approvedPaths.has(p)))throw unavailable();const work=async(t:ReadTx)=>Promise.all(paths.map(async p=>({id:p.split('/').at(-1)!,data:await t.get(p)??{}})));return tx?work(tx):store.transact(work);};
 const policies=await readRows(Object.values(source.policyPaths));
 // Auth calls are awaited once per protected request before retryable datastore
 // work. Eligibility revalidation uses this fresh immutable request snapshot;
 // no network/Auth side effect is executed inside a Firestore transaction.
 const coachIdentities=Object.fromEntries(await Promise.all([...source.coachIds,...manifest.memberIds].map(async uid=>{
  try{const u=await readAuthIdentity(uid);return[uid,{exists:true,disabled:u.disabled,emailVerified:u.emailVerified}];}catch{return[uid,{exists:false,disabled:true,emailVerified:false}];}
 }))) as Record<string,{exists:boolean;disabled:boolean;emailVerified:boolean}>;
 const reviewedPolicies=policies.map(p=>{const a=p.data as unknown as ReviewedEvidenceLearningPolicy;return{policyId:a.policyId,reviewVersion:a.reviewVersion,compatibility:a.compatibility,provisionalSamplePolicy:a.provisionalSamplePolicy,attentionThreshold:a.attentionThreshold,cohortEligibility:null};});
 const policyFor=async(scope:EvidenceScope,tx?:ReadTx)=>{
  const id=source.policyByMember[scope.memberId],path=source.policyPaths[id];if(!path)return null;
  const work=async(t:ReadTx)=>{const config=await t.get(`${ROOT}/recommendationConfiguration/current`);if(!config||!parseRecommendationConfiguration(config,'gainpath').policies.some(p=>p.policyId===id))return null;return await t.get(path);};
  return (tx?await work(tx):await store.transact(work)) as unknown as ReviewedEvidenceLearningPolicy|null;
 };
 async function permitted(tx:ReadTx,scope:EvidenceScope,window:DemoSource['window'],generation:boolean){
  const purposes=generation?['exerciseInsights','recommendationGeneration'] as const:['exerciseInsights'] as const;
  const state=await readRecommendationMemberState(tx,scope,clock(),manifest.noticePolicies,[...purposes]);
  const c=await tx.get(`${ROOT}/recommendationConsent/${scope.memberId}`);
  for(const p of purposes){const d=evaluateRecommendationConsentV2(c,scope,clock(),manifest.noticePolicies,p);if(!d.allowed||d.historyStartAtMillis===undefined||window.startAtMillis<d.historyStartAtMillis)throw new DomainError('permission-denied','Current history scope does not authorize this demo query.');}
  if(!state.eligible)throw new DomainError('permission-denied','Current demo source purpose required.');return state.fingerprint;
 }
 async function readEvidence(scope:EvidenceScope,window:DemoSource['window'],generation=true):Promise<AttestedWorkoutEvidenceBatch>{
  if(options.observations)return options.observations.read(scope,window,generation);
  if(scope.organizationId!=='gainpath'||!manifest.memberIds.includes(scope.memberId)||!Number.isSafeInteger(window.startAtMillis)||!Number.isSafeInteger(window.endAtMillis)||window.endAtMillis>clock()||window.endAtMillis<=window.startAtMillis||window.endAtMillis-window.startAtMillis>90*86400000)throw unavailable();
  const identity=await readAuthIdentity(scope.memberId);if(identity.disabled||!identity.emailVerified)throw new DomainError('permission-denied','Current demo identity required.');
  const initial=await store.transact(tx=>permitted(tx,scope,window,generation));
  const query=await db.collection(`${ROOT}/members/${scope.memberId}/workoutEvidenceCaptures`).where('seedId','==',manifest.seedId).where('capturedAtMillis','>=',window.startAtMillis).where('capturedAtMillis','<',window.endAtMillis).orderBy('capturedAtMillis').orderBy(FieldPath.documentId()).limit(101).get();
  if(query.size>100)throw new DomainError('resource-exhausted','Demo evidence source exceeds its bounded page.');
  const metadata:{id:string;data:DocumentData}[]=[],rows:EvidenceRow[]=[],attestations:AttestedWorkoutEvidenceBatch['attestations']=[];
  for(const snapshot of query.docs){
   const metadataPath=snapshot.ref.path;if(!approvedPaths.has(metadataPath))throw unavailable();
   const pair=await store.transact(async tx=>{
    if(await permitted(tx,scope,window,generation)!==initial)throw new DomainError('aborted','Demo source permission changed.');
    const a=await tx.get(metadataPath);if(!a||digestOf(a)!==digestOf(snapshot.data())||a.organizationId!==scope.organizationId||a.memberId!==scope.memberId||a.rowId!==snapshot.id||a.seedId!==manifest.seedId||a.trust!=='synthetic_emulator_attested'||typeof a.backupPath!=='string'||!a.backupPath.startsWith(`${ROOT}/members/${scope.memberId}/workoutBackups/`)||!approvedPaths.has(a.backupPath))throw unavailable();
    const data=await tx.get(a.backupPath);if(!data)throw unavailable();return{a,data};
   });
   metadata.push({id:snapshot.id,data:pair.a});rows.push({id:snapshot.id,data:pair.data});
   const{schemaVersion:_schema,seedId:_seed,backupPath:_path,...a}=pair.a;attestations.push(a as unknown as AttestedWorkoutEvidenceBatch['attestations'][number]);
  }
  return{schemaVersion:1,scope:{...scope},window:{...window},sourceRevision:digestOf({metadata,rows}),rows,attestations};
 }
 const payloads:unknown[]=[];
 const provider:RankingProvider=async payload=>{payloads.push(structuredClone(payload));return{text:JSON.stringify({schemaVersion:1,rankings:payload.candidates.map((c,i)=>({label:c.label,relevance:i===1?94:70-i,reasonCodes:['objective_match'],evidenceRefs:[c.evidence.find(e=>e.kind==='objective_match')!.ref],abstain:false}))}),model:'gainpath-demo-structured-mock-v1',latencyMillis:0,usage:{inputTokens:null,outputTokens:null,thinkingTokens:null,totalTokens:null}};};
 async function engine(item:QueueGenerationItem,kind:RecommendationKind,tx?:ReadTx,inference=false):Promise<QueueEngineResult>{
  const facts=new Map<string,unknown>(),wrap=(t:ReadTx):ReadTx=>({get:async p=>{const data=await t.get(p);facts.set(p,data??null);return data;}});
  const transact=<T>(work:(t:ReadTx)=>Promise<T>)=>tx?work(wrap(tx)):store.transact(t=>work(wrap(t)));
  const expertiseRows=await readRows(source.expertisePaths,tx),suitabilityRows=await readRows(source.suitabilityPaths,tx);
  const trustedExpertise=expertiseRows.map(r=>r.data as unknown as TrustedTrainerExpertise),suitability=suitabilityRows.map(r=>r.data as unknown as CuratedContentSuitability);
  const ranking={context:{mode:'synthetic_local' as const,datasetId:'module13-batch-b-v1' as const,organizationId:'gainpath' as const,evidenceStatus:item.evidenceStatus},exerciseMapping:{exercise:item.need.exercise,exerciseId:item.exerciseId,version:'synthetic-exercise-v1' as const},...(inference?{provider}:{})};
  const result=kind==='trainer'?await recommendTrainerCandidates(item.need,{schemaVersion:1,organizationId:'gainpath',memberId:item.memberId,exerciseId:item.exerciseId,learningObjective:item.need.objective,level:item.need.level,localDate:source.bookingDate,durationMinutes:60},{repository:{transact,listCoachIds:async()=>[...source.coachIds]},trustedExpertise,clock,readIdentity:async uid=>{if(!manifest.coachIds.includes(uid)&&uid!==item.memberId)throw unavailable();return coachIdentities[uid];}},ranking):await transact(async t=>recommendContentCandidates(item.need,{organizationId:'gainpath',exerciseId:item.exerciseId,objective:item.need.objective,level:item.need.level},{schemaVersion:1,organizationId:'gainpath',sourceVersion:manifest.seedId,curationVersion:'demo-curation-v1',memberAccess:'organization_published_routines',catalog:await readRows(source.catalogIds.map(id=>`${ROOT}/exerciseVideos/${id}`),t),publications:await readRows(source.publicationIds.map(id=>`${ROOT}/content/${id}`),t),suitability,compatibleExercises:[]},ranking));
  const displays=await transact(async t=>{
   const d:QueueEngineResult['targetLabels']={};for(const id of source.coachIds){const p=await t.get(`${ROOT}/coaches/${id}`);if(p&&typeof p.displayName==='string')d[id]={label:p.displayName,specialization:typeof p.specialty==='string'?p.specialty:null,branchLabel:'Demo Training Branch'};}return d;
  });
  return{recommendation:result,sourceFingerprint:digestOf({need:item.need,exerciseId:item.exerciseId,kind,expertiseRows,suitabilityRows,coachIdentities:kind==='trainer'?coachIdentities:null,facts:[...facts].sort(([a],[b])=>a.localeCompare(b))}),targetLabels:displays};
 }
 const queueSource=createEvidenceDrivenQueueSource({...deps,organizationId:'gainpath',members:source.members,window:source.window,validityMillis:86400000,readEvidence,readPolicy:scope=>policyFor(scope),recommend:(item,kind,infer)=>engine(item,kind,undefined,infer),validateCandidates:async(tx,item,kind,fingerprint)=>(await engine(item,kind,tx)).sourceFingerprint===fingerprint,revalidateEvidence:async(tx,scope,revision,policyFingerprint)=>{
  if(options.observations)return options.observations.revalidate(tx,scope,revision,policyFingerprint);
  const paths=manifest.recordPaths.filter(p=>p.startsWith(`${ROOT}/members/${scope.memberId}/workoutEvidenceCaptures/`));
  const metadata:{id:string;data:DocumentData}[]=[],rows:EvidenceRow[]=[];
  for(const path of paths){const a=await tx.get(path);if(!a||typeof a.capturedAtMillis!=='number'||a.capturedAtMillis<source.window.startAtMillis||a.capturedAtMillis>=source.window.endAtMillis)continue;if(a.seedId!==manifest.seedId||typeof a.backupPath!=='string'||!approvedPaths.has(a.backupPath))return false;metadata.push({id:path.split('/').at(-1)!,data:a});}
  metadata.sort((a,b)=>Number(a.data.capturedAtMillis)-Number(b.data.capturedAtMillis)||a.id.localeCompare(b.id));for(const m of metadata){const data=await tx.get(String(m.data.backupPath));if(!data)return false;rows.push({id:m.id,data});}
  return digestOf({metadata,rows})===revision&&digestOf(await policyFor(scope,tx))===policyFingerprint;
 }});
 const validateTarget=async(tx:ReadTx,lead:RecommendationLead):Promise<'valid'|'stale'>=>await queueSource.validateLead(tx,lead)?'valid':'stale';
 const resolveTarget=createCurrentRecommendationTargetResolver({organizationId:'gainpath',revalidateEligibility:validateTarget});
 const readLeads=async(org:string,after:string|null,limit:number)=>{
  if(org!=='gainpath'||!Number.isSafeInteger(limit)||limit<1||limit>101||(after!==null&&!/^[a-f0-9]{64}$/.test(after)))throw unavailable();
  let q=db.collection(`${queryRoot}/recommendationLeads`).orderBy(FieldPath.documentId()).limit(limit);if(after)q=q.startAfter(after);
  const docs=(await q.get()).docs;return store.transact(tx=>Promise.all(docs.map(async d=>({id:d.id,data:await tx.get(logical(d.ref.path))??{}}))));
 };
 const listInbox=async(org:string,uid:string,after?:string)=>{
  if(org!=='gainpath'||!manifest.memberIds.includes(uid))throw unavailable();
  let q=db.collection(`${queryRoot}/notifications`).where('recipientId','==',uid).orderBy('createdAtMillis','desc').orderBy(FieldPath.documentId(),'desc').limit(31);
  if(after){const cursor=await db.doc(`${queryRoot}/notifications/${after}`).get();if(!cursor.exists||cursor.data()?.recipientId!==uid)throw unavailable();q=q.startAfter(cursor);}
  const docs=(await q.get()).docs;return store.transact(tx=>Promise.all(docs.map(async d=>({id:d.id,data:await tx.get(logical(d.ref.path))??{}}))));
 };
 async function insights(request:InsightsRequest){
  const reader={members:async(org:string,after:string|undefined,limit:number)=>{if(org!=='gainpath'||!Number.isSafeInteger(limit)||limit<1||limit>251)throw unavailable();return readRows(manifest.memberIds.slice().sort().filter(id=>!after||id>after).slice(0,limit).map(id=>`${ROOT}/members/${id}`));},backups:async()=>{throw unavailable();},consentScopedBackups:async(scope:EvidenceScope,window:DemoSource['window'],after:string|undefined,limit:number)=>{if(!Number.isSafeInteger(limit)||limit<1||limit>25)throw unavailable();const b=await readEvidence(scope,window,false);return b.rows.slice().sort((a,b)=>a.id.localeCompare(b.id)).filter(r=>!after||r.id>after).slice(0,limit);}};
  const raw=await exerciseInsightsHandler(request,{...deps,reader,consentNoticePolicies:manifest.noticePolicies,provisionalPolicy:reviewedPolicies[0]?.provisionalSamplePolicy??null});
  const config=await store.transact(async tx=>{const c=await tx.get(`${ROOT}/recommendationConfiguration/current`);return c?parseRecommendationConfiguration(c,'gainpath'):defaultRecommendationConfiguration('gainpath');});
  return projectExerciseInsights(raw,await readRows(source.catalogIds.map(id=>`${ROOT}/exerciseVideos/${id}`)),await readRows(source.publicationIds.map(id=>`${ROOT}/content/${id}`)),config,{policyId:'demo-only-cohort-v1',reviewVersion:manifest.seedId,minimumMembers:2});
 }
 async function workoutHistory(request:InsightsRequest){
  if(queryRoot!==ROOT)throw unavailable(); // Cohort history MUST use the separate truthful reader.
  const q=object(request.data);keys(q,['schemaVersion','organizationId','afterKey','backupConsented']);if(q.schemaVersion!==1||q.organizationId!=='gainpath'||q.backupConsented!==true||q.afterKey!==null&&typeof q.afterKey!=='string')throw unavailable();
  const uid=request.auth!.uid;
  const backupStore:BackupStore={transact:work=>store.transact(work),list:async(prefix,after,limit,kind)=>{
   if(prefix!==`${ROOT}/members/${uid}/workoutBackups`||limit>3)throw unavailable();
   // The demo deliberately includes a duplicate revision for A1 evidence tests.
   // The existing history cursor is the canonical backup key, not a revision
   // document ID. Validate owned rows, then expose only canonical head paths.
   const docs=(await db.collection(prefix).orderBy(FieldPath.documentId()).startAt(kind+'-').endAt(kind+'-\uf8ff').limit(101).get()).docs;if(docs.length>100)throw unavailable();
   return store.transact(async t=>{const rows=await Promise.all(docs.map(async d=>({id:d.id,data:await t.get(d.ref.path)})));return rows.filter(r=>r.data&&r.data.key===r.id&&(!after||r.id>after)).slice(0,limit).map(r=>r.data!);});
  }};
  return listWorkoutBackups(backupStore,request.auth,{schemaVersion:1,organizationId:'gainpath',memberId:uid,consented:q.backupConsented,after:q.afterKey,maxPoseMetricsSchemaVersion:6});
 }
 return{source,queueSource,validateTarget,resolveTarget,reviewedPolicies,insights,queueReader:{readLeads},inboxReader:{list:listInbox},workoutHistory,readRows,providerPayloads:payloads};
}
