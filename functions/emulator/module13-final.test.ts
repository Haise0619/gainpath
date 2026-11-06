import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,FieldPath,type Firestore} from 'firebase-admin/firestore';
import {initializeTestEnvironment,type RulesTestEnvironment,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc} from 'firebase/firestore';
import {beforeAll,afterAll,beforeEach,it,expect} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import type {InsightsRequest} from '../src/modules/recommendation/exercise-insights-contracts';
import {exerciseInsightsHandler} from '../src/modules/recommendation/exercise-insights';
import {projectExerciseInsights} from '../src/modules/recommendation/exercise-insights-presentation';
import {defaultRecommendationConfiguration,createRecommendationConfigurationCommand,authorizeRecommendationSession} from '../src/modules/recommendation/recommendation-configuration';
import {createRecommendationConsentV2Command} from '../src/modules/recommendation/recommendation-consent-v2';
import {createRecommendationQueueGeneration} from '../src/modules/recommendation/recommendation-queue-generation';
import {createRecommendationQueueList} from '../src/modules/recommendation/recommendation-queue-reader';
import {createRecommendationLeadDecision} from '../src/modules/recommendation/recommendation-lead-decisions';
import {createRecommendationDelivery} from '../src/modules/recommendation/recommendation-delivery';
import {createMemberRecommendationService,requireRecommendationMember} from '../src/modules/recommendation/recommendation-member-service';
import {createRecommendationNoticeProjector} from '../src/modules/recommendation/module9-recommendation-projection';
import {createRecommendationReadServices} from '../src/modules/recommendation/recommendation-read-services';
import {createRecommendationCallableFacade,type RecommendationCallableHandlers,type RecommendationCallableOperation} from '../src/modules/recommendation/recommendation-callable-readiness';
import {module9MemberCommand} from '../src/modules/coaching/module9-member-service';
import {createModule13FinalFixture,createFinalEvidenceReader,module13FinalDocuments,finalClock,guardModule13Final,FINAL_PROJECT,FINAL_ROOT as ROOT,FINAL_NOW,FINAL_MEMBER,FINAL_ADMIN,FINAL_COACH,FINAL_EXERCISE,FINAL_WINDOW,finalPolicy} from '../test/module13-final-integration.fixture';


let app:App,db:Firestore,env:RulesTestEnvironment,store:FirestoreStore,f:Awaited<ReturnType<typeof createModule13FinalFixture>>,facade:ReturnType<typeof createRecommendationCallableFacade>;
let insightCalls=0,historyReads=0;
const counts:Record<string,number>={};
const memberRequest=(data:unknown):InsightsRequest=>({...f.request,auth:{uid:FINAL_MEMBER,token:{...f.request.auth.token,email:`${FINAL_MEMBER}@example.invalid`}},data});
const query=(kind:'trainer'|'content')=>({schemaVersion:1 as const,organizationId:'gainpath',kind,status:'all' as const,startAtMillis:FINAL_NOW-86400000,endAtMillis:f.deps.clock!(),exerciseId:null,category:null,specialization:null,afterLeadId:null,limit:25});
const size=async(name:string)=>(await db.collection(`${ROOT}/${name}`).get()).size;
function queueReader(){return{readLeads:async(org:string,after:string|null,limit:number)=>{
 guardModule13Final(db);if(org!=='gainpath'||!Number.isSafeInteger(limit)||limit<1||limit>101||(after!==null&&!/^[a-f0-9]{64}$/.test(after)))throw Error('Invalid bounded queue');
 let q=db.collection(ROOT+'/recommendationLeads').orderBy(FieldPath.documentId()).limit(limit);if(after)q=q.startAfter(after);return(await q.get()).docs.map(d=>({id:d.id,data:d.data()}));
}};}
function inboxReader(){return{list:async(org:string,uid:string,after?:string)=>{
 guardModule13Final(db);if(org!=='gainpath'||uid!==FINAL_MEMBER)throw Error('Owned inbox required');
 let q=db.collection(ROOT+'/notifications').where('recipientId','==',uid).orderBy('createdAtMillis','desc').orderBy(FieldPath.documentId(),'desc').limit(31);
 if(after){const cursor=await db.doc(ROOT+'/notifications/'+after).get();if(!cursor.exists||cursor.data()?.recipientId!==uid)throw Error('Owned cursor required');q=q.startAfter(cursor);}
 return(await q.get()).docs.map(d=>({id:d.id,data:d.data()}));
}};}
async function protectedSnapshot(){
 const names=['bookings','consultations','paymentReceipts','payments','rewardWallets','rewardReceipts','rewardTransactions','memberPrograms','workoutSessions'];
 const result=Object.fromEntries(await Promise.all(names.map(async name=>[name,(await db.collection(`${ROOT}/${name}`).get()).docs.map(d=>({id:d.id,data:d.data()}))])));
 const evidencePaths=Object.keys(module13FinalDocuments()).filter(p=>p.includes('/workoutBackups/')||p.includes('/workoutEvidenceCaptures/')).sort();
 result.evidenceSources=await Promise.all(evidencePaths.map(async path=>({id:path,data:(await db.doc(path).get()).data()!})));
 return result;
}
async function insights(request:InsightsRequest){
 guardModule13Final(db);insightCalls++;
 const raw=await exerciseInsightsHandler(request,{...f.deps,clock:f.deps.clock,provisionalPolicy:finalPolicy.provisionalSamplePolicy,consentNoticePolicies:f.deps.noticePolicies,
  reader:{members:async(org,after,limit)=>{
   guardModule13Final(db);if(org!=='gainpath')throw Error('Canonical scope required');
   let q=db.collection(ROOT+'/members').orderBy(FieldPath.documentId()).limit(limit);if(after)q=q.startAfter(after);
   return(await q.get()).docs.map(d=>({id:d.id,data:d.data()}));
  },backups:async()=>{throw Error('Legacy unscoped history is forbidden');},
  consentScopedBackups:async(scope,window,after,limit)=>{
   if(after!==undefined||limit<1||limit>200)throw Error('Bounded synthetic page required');
   const batch=await f.reader.read(scope,window);historyReads+=batch.rows.length;return [...batch.rows].sort((a,b)=>a.id.localeCompare(b.id));
  }}});
 expect(raw.status).toBe('available');expect(raw.groups[0]).toMatchObject({scoredSessions:6,members:2,meanEstimatedFormScore:62});
 const catalog=(await db.collection(ROOT+'/exerciseVideos').limit(1000).get()).docs.map(d=>({id:d.id,data:d.data()}));
 const publications=(await db.collection(ROOT+'/content').limit(500).get()).docs.map(d=>({id:d.id,data:d.data()}));
 // Explicit synthetic disclosure only; does not install production thresholds or disclosure policy.
 return projectExerciseInsights(raw,catalog,publications,defaultRecommendationConfiguration('gainpath'),{policyId:'synthetic-cohort-two',reviewVersion:'fixture-v1',minimumMembers:2});
}
async function seed(){
 guardModule13Final(db);await env.clearFirestore();const batch=db.batch();for(const[path,data]of Object.entries(module13FinalDocuments()))batch.set(db.doc(path),data);await batch.commit();
 f=await createModule13FinalFixture({store,db,clock:finalClock()});
 const reads=createRecommendationReadServices({...f.deps,validateTarget:f.validateTarget});
 const handlers:RecommendationCallableHandlers={
  'admin.insights':insights,'admin.configuration.get':reads.configuration,'admin.configuration.save':createRecommendationConfigurationCommand(f.deps),
  'admin.queue.refresh':createRecommendationQueueGeneration({...f.deps,source:f.source}),
  'admin.queue.list':createRecommendationQueueList({...f.deps,reader:queueReader()}),
  'admin.queue.detail':reads.lead,'admin.queue.status':reads.status,'admin.queue.decide':createRecommendationLeadDecision({...f.deps,validateTarget:f.validateTarget}),
  'member.consent.get':reads.consent,'member.consent.set':createRecommendationConsentV2Command(f.deps),
  'member.recommendation.command':createMemberRecommendationService(f.deps),'delivery.process':createRecommendationDelivery(f.deps)};
 // Fixed test-only composition, independently SDK-bound; no deployable facade activation.
 facade=async(operation,request)=>{
  guardModule13Final(db);
  if(!request.app?.appId||!request.auth)throw Object.assign(Error('Verified context required'),{code:'unauthenticated'});
  const data=request.data as Record<string,unknown>;
  if(!data||data.organizationId!=='gainpath'||Buffer.byteLength(JSON.stringify(data))>16384||['mode','fixtureSetId','enabled','localFixture','localDelivery','capability'].some(k=>Object.hasOwn(data,k)))throw Error('Invalid scoped fixture request');
  const result=await handlers[operation](request);
  guardModule13Final(db);if(Buffer.byteLength(JSON.stringify(result))>262144)throw Error('Bounded result required');return result as never;
 };
 insightCalls=0;historyReads=0;for(const key of Object.keys(counts))delete counts[key];
}
async function prepare(kind:'trainer'|'content'){
 const result=await facade('admin.queue.refresh',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',kind,commandId:`refresh-${kind}`,continuation:null}});expect(result.summary.generated).toBe(1);
 const lead=(await facade('admin.queue.list',{...f.request,data:query(kind)})).leads[0];
 const prepared=await facade('admin.queue.decide',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',leadId:lead.leadId,commandId:`send-${kind}`,expectedRevision:lead.revision,action:'send',reason:null}});
 return{lead,id:prepared.recipientRecommendationId!};
}
async function inbox(afterId?:string){
 const request=memberRequest({});const result=await module9MemberCommand(store,request.auth!,{schemaVersion:1,organizationId:'gainpath',action:'inbox',...(afterId?{afterId}:{})},f.deps.clock,
 {...inboxReader(),projectRecommendation:await createRecommendationNoticeProjector(f.deps,request)});
 if(!('records'in result))throw Error('Expected existing Module9 inbox');return result;
}
beforeAll(async()=>{
 guardModule13Final();app=initializeApp({projectId:FINAL_PROJECT},'module13-final-local');db=getFirestore(app);store=new FirestoreStore(db);guardModule13Final(db);
 env=await initializeTestEnvironment({projectId:FINAL_PROJECT,firestore:{host:'127.0.0.1',port:18117,rules:readFileSync('../firebase/firestore.rules','utf8')}});
});
beforeEach(seed);
afterAll(async()=>{await env?.cleanup();await db?.terminate();if(app)await deleteApp(app);});

it('protects current read contracts and evidence-backed canonical Insights',async()=>{
 const now=f.deps.clock!();const result=await facade('admin.insights',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',startAtMillis:now-30*86400000,endAtMillis:now}});
 expect(result).toMatchObject({mode:'descriptive_only',privacy:{state:'applied'}});expect(result.content).toHaveLength(1);expect(result.content[0].publishedTutorials).toBe(2);expect(result.groups[0].metrics.meanEstimatedFormScore).toBe(62);expect(historyReads).toBeGreaterThan(0);
 expect(await facade('admin.configuration.get',f.request)).toMatchObject({revision:0,policies:[],activation:{generation:false,externalAi:false,matching:false,delivery:false}});
 const consent=await facade('member.consent.get',memberRequest({schemaVersion:2,organizationId:'gainpath'}));expect(consent?.purposes.recommendationDelivery.granted).toBe(true);
 const{lead}=await prepare('trainer');expect((await facade('admin.queue.detail',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',leadId:lead.leadId}})).lead.leadId).toBe(lead.leadId);
 expect((await facade('admin.queue.status',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',runId:lead.runId}})).summary.status).toBe('complete');
});
it('rejects cross-role, wrong organization, absent App Check and forged activation before exposing read state',async()=>{
 await expect(facade('admin.configuration.get',{...f.request,app:undefined})).rejects.toMatchObject({code:'unauthenticated'});
 await expect(facade('admin.configuration.get',memberRequest({schemaVersion:1,organizationId:'gainpath'}))).rejects.toMatchObject({code:'permission-denied'});
 await expect(facade('member.consent.get',{...f.request,data:{schemaVersion:2,organizationId:'gainpath'}})).rejects.toMatchObject({code:'permission-denied'});
 await expect(facade('admin.configuration.get',{...f.request,data:{schemaVersion:1,organizationId:'foreign'}})).rejects.toThrow();
 await expect(facade('admin.configuration.get',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',enabled:true}})).rejects.toThrow();
});
it('same-lifetime delivery duplicate/concurrent retries remain once-only and revoke current detail',async()=>{
 const{id}=await prepare('content'),request={...f.request,data:{schemaVersion:1,organizationId:'gainpath',recommendationId:id}};
 const first=await facade('delivery.process',request);expect(await Promise.all([facade('delivery.process',request),facade('delivery.process',request)])).toEqual([first,first]);expect(await size('notifications')).toBe(1);
 const command={schemaVersion:1,organizationId:'gainpath',recommendationId:id,action:'get',commandId:null,expectedRevision:null};
 expect((await facade('member.recommendation.command',memberRequest(command))).state).toBe('available');
 const c=(await db.doc(`${ROOT}/recommendationConsent/${FINAL_MEMBER}`).get()).data()!;
 await facade('member.consent.set',memberRequest({schemaVersion:2,organizationId:'gainpath',commandId:'revoke',expectedRevision:c.revision,purpose:'recommendationDelivery',action:'revoke'}));
 expect(await facade('member.recommendation.command',memberRequest(command))).toMatchObject({state:'unavailable',target:null,explanations:[]});
 await expect(facade('delivery.process',request)).rejects.toThrow();expect(await size('notifications')).toBe(1);
});
it('unchanged Rules protect canonical private collections and direct notification mutation',async()=>{
 const{id}=await prepare('trainer');await facade('delivery.process',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',recommendationId:id}});
 for(const uid of [FINAL_MEMBER,FINAL_ADMIN,'foreign']){
  const client=env.authenticatedContext(uid,{email_verified:true}).firestore();
  for(const name of ['recommendationConsent','recommendationLeads','recommendationRecipients','recommendationDeliveryReceipts','recommendationMemberCommandReceipts']){
   const path=`${ROOT}/${name}/${name==='recommendationConsent'?FINAL_MEMBER:id}`;
   await assertFails(getDoc(doc(client,path)));await assertFails(setDoc(doc(client,path),{injected:true}));
  }
  for(const path of [`${ROOT}/recommendationEvidenceBindings/${id}`,`${ROOT}/recommendationEvidencePolicies/${FINAL_EXERCISE}`,`${ROOT}/members/${FINAL_MEMBER}/workoutEvidenceCaptures/capture-0`]){
   await assertFails(getDoc(doc(client,path)));await assertFails(setDoc(doc(client,path),{injected:true}));
  }
  await assertFails(setDoc(doc(client,`${ROOT}/notifications/recommendation-${id}`),{read:true}));
 }
});

it('proves persisted canonical evidence origin and revision deduplication through repeated Refresh and Dismiss',async()=>{
 const refresh=(commandId:string)=>facade('admin.queue.refresh',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',kind:'content',commandId,continuation:null}});
 expect((await refresh('evidence-first')).summary.generated).toBe(1);
 const lead=(await facade('admin.queue.list',{...f.request,data:query('content')})).leads[0];
 expect(lead).toMatchObject({exerciseId:FINAL_EXERCISE,objective:'technique_foundations',evidence:{scoredSessions:3,estimatedFormScorePercent:62,coverage:.8,sourceVersion:'validated-workout-evidence-v1'},ranking:{origin:'ai_reranked',model:'synthetic-structured-mock-v1'}});
 const binding=(await db.doc(`${ROOT}/recommendationEvidenceBindings/${lead.sourceFingerprint}`).get()).data()!;
 expect(binding.provenance).toMatchObject({origin:'validated_workout_evidence',duplicateRecords:1,scope:{organizationId:'gainpath',memberId:FINAL_MEMBER}});
 expect(binding.need).toEqual({exercise:'squat',objective:'technique_foundations',level:'beginner'});
 expect(await store.transact(tx=>f.source.validateLead(tx,lead))).toBe(true);
 expect((await refresh('evidence-second')).summary.generated).toBe(0);
 const command={schemaVersion:1,organizationId:'gainpath',leadId:lead.leadId,commandId:'dismiss-evidence',expectedRevision:1,action:'dismiss' as const,reason:'Guidance already discussed in synthetic review.'};
 const dismissed=await facade('admin.queue.decide',{...f.request,data:command});
 expect(await facade('admin.queue.decide',{...f.request,data:command})).toEqual(dismissed);
 expect(dismissed.status).toBe('dismissed');expect((await refresh('evidence-third')).summary.generated).toBe(0);
 expect(await size('recommendationLeads')).toBe(1);expect(await size('recommendationRecipients')).toBe(0);
 expect(f.reader.trace.payloadReads).toBeGreaterThan(0);expect(f.reader.trace.paths.some(p=>p.includes('session-excluded'))).toBe(false);
 const payload=JSON.stringify(f.providerPayloads);for(const forbidden of [FINAL_MEMBER,'fictional-session','formScorePercent','poseMetrics','sourceFingerprint','payloadJson','memberId'])expect(payload).not.toContain(forbidden);
});

it('blocks policy/source/provenance changes at Send and never creates prepared recipients',async()=>{
 const result=await facade('admin.queue.refresh',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',kind:'trainer',commandId:'stale-source-refresh',continuation:null}});expect(result.summary.generated).toBe(1);
 const lead=(await facade('admin.queue.list',{...f.request,data:query('trainer')})).leads[0];
 await db.doc(`${ROOT}/recommendationEvidencePolicies/${FINAL_EXERCISE}`).update({reviewVersion:'synthetic-policy-revised'});
 const decision=await facade('admin.queue.decide',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',leadId:lead.leadId,commandId:'stale-source-send',expectedRevision:1,action:'send',reason:null}});
 expect(decision).toMatchObject({status:'stale',outcome:'blocked',recipientRecommendationId:null});expect(await size('recommendationRecipients')).toBe(0);
});

it('denies missing purpose before reading any workout payload',async()=>{
 const consent=(await db.doc(`${ROOT}/recommendationConsent/${FINAL_MEMBER}`).get()).data()!;
 await facade('member.consent.set',memberRequest({schemaVersion:2,organizationId:'gainpath',commandId:'revoke-before-source',expectedRevision:consent.revision,purpose:'exerciseInsights',action:'revoke'}));
 const before=f.reader.trace.payloadReads;
 const result=await facade('admin.queue.refresh',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',kind:'content',commandId:'missing-purpose-refresh',continuation:null}});
 expect(result.summary).toMatchObject({generated:0,abstained:1,abstentionReasons:{missing_consent:1}});expect(f.reader.trace.payloadReads).toBe(before);expect(await size('recommendationLeads')).toBe(0);
});

it('refuses missing source records and partial Insights after a later Member source failure',async()=>{
 await db.doc(`${ROOT}/members/${FINAL_MEMBER}/workoutBackups/session-fictional-session-0`).delete();
 await expect(facade('admin.queue.refresh',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',kind:'content',commandId:'failed-source-refresh',continuation:null}})).rejects.toThrow();
 expect(await size('recommendationLeads')).toBe(0);expect(await size('recommendationRecipients')).toBe(0);
 const original=module13FinalDocuments();await db.doc(`${ROOT}/members/${FINAL_MEMBER}/workoutBackups/session-fictional-session-0`).set(original[`${ROOT}/members/${FINAL_MEMBER}/workoutBackups/session-fictional-session-0`]);
 await db.doc(`${ROOT}/members/fictional-member-peer/workoutBackups/session-fictional-session-0`).delete();
 await expect(facade('admin.insights',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',...FINAL_WINDOW}})).rejects.toMatchObject({code:'failed-precondition'});
 expect(await size('recommendationLeads')).toBe(0);
});

it('rejects forged capture ownership and refuses unbounded or foreign reads before payload access',async()=>{
 const before=f.reader.trace.payloadReads;
 await expect(f.reader.read({organizationId:'foreign',memberId:FINAL_MEMBER},{startAtMillis:FINAL_NOW-86400000,endAtMillis:FINAL_NOW})).rejects.toThrow();
 expect(f.reader.trace.payloadReads).toBe(before);
 await db.doc(`${ROOT}/members/${FINAL_MEMBER}/workoutEvidenceCaptures/capture-0`).update({memberId:'foreign-member'});
 await expect(facade('admin.queue.refresh',{...f.request,data:{schemaVersion:1,organizationId:'gainpath',kind:'content',commandId:'forged-source-refresh',continuation:null}})).rejects.toThrow();
 expect(await size('recommendationLeads')).toBe(0);
});

it('revocation during awaited metadata query prevents every subsequent workout payload read',async()=>{
 const guarded=createFinalEvidenceReader(db,async()=>{
  const c=(await db.doc(`${ROOT}/recommendationConsent/${FINAL_MEMBER}`).get()).data()!;
  await facade('member.consent.set',memberRequest({schemaVersion:2,organizationId:'gainpath',commandId:'revoke-during-capture-query',expectedRevision:c.revision,purpose:'exerciseInsights',action:'revoke'}));
 });
 await expect(guarded.read({organizationId:'gainpath',memberId:FINAL_MEMBER},FINAL_WINDOW)).rejects.toThrow();expect(guarded.trace.metadataQueries).toBe(1);expect(guarded.trace.payloadReads).toBe(0);expect(await size('recommendationLeads')).toBe(0);
});

it('over-limit metadata refuses the complete source before any workout payload',async()=>{
 const batch=db.batch();for(let i=0;i<101;i++)batch.set(db.doc(`${ROOT}/members/${FINAL_MEMBER}/workoutEvidenceCaptures/extra-${i}`),{capturedAtMillis:FINAL_NOW-86400000});await batch.commit();
 const before=f.reader.trace.payloadReads;await expect(f.reader.read({organizationId:'gainpath',memberId:FINAL_MEMBER},FINAL_WINDOW)).rejects.toMatchObject({code:'resource-exhausted'});expect(f.reader.trace.payloadReads).toBe(before);expect(await size('recommendationLeads')).toBe(0);
});

it.skipIf(process.env.MODULE13_FINAL_CLIENT_UI!=='1')('actual Admin Insights review Send hands off both kinds to actual Member current routes in one backend lifetime',async()=>{
 const unchanged=await protectedSnapshot(),notices:Record<string,string>={},derivations:unknown[]=[];
 const server=createServer(async(req,res)=>{
  res.setHeader('Content-Type','application/json');
  try{
   guardModule13Final(db);if(req.socket.remoteAddress!=='127.0.0.1')throw Error('Loopback required');
   if(req.method==='GET'&&req.url==='/health'){res.end(JSON.stringify({fixtureOnly:true,nowMillis:f.deps.clock!(),notices}));return;}
   const role=req.headers['x-gainpath-fixture-role'];
   if(req.method!=='POST'||req.url!=='/rpc'||req.headers['x-gainpath-fixture-session']!=='module13-final-local'||!['admin','member'].includes(String(role))){res.statusCode=403;res.end(JSON.stringify({error:{code:'permission-denied'}}));return;}
   let body='';for await(const chunk of req){body+=chunk.toString();if(Buffer.byteLength(body)>16384)throw Error('Bounded request required');}
   const payload=JSON.parse(body);if(!payload||Object.keys(payload).sort().join(',')!=='data,method')throw Error('Invalid RPC');
   counts[`${role}.${payload.method}`]=(counts[`${role}.${payload.method}`]??0)+1;
   const request={...(role==='member'?memberRequest({}):f.request),data:payload.data};let result:unknown;
   const adminMethods:Record<string,RecommendationCallableOperation>={insights:'admin.insights',configuration:'admin.configuration.get',refresh:'admin.queue.refresh',list:'admin.queue.list',detail:'admin.queue.detail',decide:'admin.queue.decide'};
   if(role==='admin'&&adminMethods[payload.method])result=await facade(adminMethods[payload.method],request);
   else if(role==='member'&&payload.method==='member')result=await facade('member.recommendation.command',request);
   else if(role==='member'&&payload.method==='inbox')result=await inbox(payload.data.afterId??undefined);
   else if(role==='member'&&['coach','routine'].includes(payload.method)){
    const auth=await authorizeRecommendationSession(request,f.deps);await store.transact(tx=>requireRecommendationMember(tx,auth,'gainpath'));
    const id=payload.data[payload.method==='coach'?'coachId':'routineId'];if(payload.method==='coach'?id!==FINAL_COACH:!['fictional-routine-a','fictional-routine-b'].includes(id))throw Error('Unknown fixture source');
    const data=(await db.doc(`${ROOT}/${payload.method==='coach'?'coaches':'content'}/${id}`).get()).data();if(data?.status!=='published')throw Error('Source unavailable');result=data;
   }else if(role==='admin'&&payload.method==='withdraw'&&payload.data.kind==='trainer'){await db.doc(`${ROOT}/coaches/${FINAL_COACH}`).update({status:'inactive'});result={withdrawn:true};}
   else throw Error('Unknown fixture operation');
   res.end(JSON.stringify({result}));
  }catch(error){const code=typeof error==='object'&&error&&'code'in error?String(error.code):'unavailable';res.end(JSON.stringify({error:{code,message:'Local synthetic operation failed.'}}));}
 });
 await new Promise<void>((done,reject)=>{server.once('error',reject);server.listen(18118,'127.0.0.1',done);});
 async function flutter(appName:string,test:string){
  return new Promise<number>((done,reject)=>{
   const child=spawn('C:/flutter/bin/cache/dart-sdk/bin/dart.exe',[resolve('C:/flutter/bin/cache/flutter_tools.snapshot'),'test',test,'--no-pub','--reporter','expanded'],{cwd:resolve(`../apps/${appName}`),env:{...process.env,MODULE13_FINAL_GATEWAY:'127.0.0.1:18118'},stdio:'inherit'});
   child.once('error',reject);child.once('exit',code=>done(code??1));
  });
 }
 try{
  expect(await flutter('admin_web','test/emulator/module13_final_admin_emulator_test.dart')).toBe(0);
  expect(counts['admin.detail']).toBe(2); // Both actual View details buttons fetch current protected state.
  expect(insightCalls).toBeGreaterThan(0);expect(historyReads).toBeGreaterThan(0);expect(await size('notifications')).toBe(0);expect(await size('recommendationRecipients')).toBe(2);
  for(const kind of ['trainer','content'] as const){
   const lead=(await facade('admin.queue.list',{...f.request,data:query(kind)})).leads[0];expect(lead.status).toBe('sent');
   const binding=(await db.doc(ROOT+'/recommendationEvidenceBindings/'+lead.sourceFingerprint).get()).data()!;
   expect(lead.evidence).toMatchObject({scoredSessions:3,estimatedFormScorePercent:62,coverage:.8,sourceVersion:'validated-workout-evidence-v1'});
   expect(binding.provenance).toMatchObject({origin:'validated_workout_evidence',duplicateRecords:1,scope:{organizationId:'gainpath',memberId:FINAL_MEMBER}});
   expect(binding.need).toEqual({exercise:'squat',objective:'technique_foundations',level:'beginner'});
   derivations.push({kind,leadId:lead.leadId,exerciseId:lead.exerciseId,evidence:lead.evidence,need:binding.need,provenance:binding.provenance,ranking:lead.ranking});
   const id=lead.decision!.recipientRecommendationId!,request={...f.request,data:{schemaVersion:1,organizationId:'gainpath',recommendationId:id}};
   const delivered=await facade('delivery.process',request);expect(await facade('delivery.process',request)).toEqual(delivered);notices[kind]=delivered.notificationId;
  }
  expect(await flutter('mobile','test/emulator/module13_final_member_emulator_test.dart')).toBe(0);
  expect(await size('notifications')).toBe(2);expect(await size('recommendationDeliveryReceipts')).toBe(2);expect(await size('recommendationMemberCommandReceipts')).toBe(4);
  const recipients=(await db.collection(`${ROOT}/recommendationRecipients`).get()).docs.map(d=>d.data());
  expect(recipients.find(r=>r.kind==='trainer')).toMatchObject({status:'delivered',revision:3,memberReadAtMillis:expect.any(Number),acknowledgedAtMillis:expect.any(Number),dismissedAtMillis:null});
  expect(recipients.find(r=>r.kind==='content')).toMatchObject({status:'delivered',revision:3,memberReadAtMillis:expect.any(Number),acknowledgedAtMillis:null,dismissedAtMillis:expect.any(Number)});
  expect((await db.collection(`${ROOT}/notifications`).get()).docs.every(d=>d.data().read===true)).toBe(true);expect(await protectedSnapshot()).toEqual(unchanged);
  mkdirSync('../build/module13-final',{recursive:true});writeFileSync('../build/module13-final/combined-client-proof.json',JSON.stringify({projectId:FINAL_PROJECT,firestoreHost:'127.0.0.1:18117',gatewayHost:'127.0.0.1:18118',fixtureOnly:true,realTokenValidation:false,appCheckAttestation:false,sameBackendLifetime:true,actualAdminWidget:true,actualMemberWidget:true,currentAdminDetailChecks:counts['admin.detail'],counts,insightCalls,historyReads,insightMode:'validated_synthetic_evidence_descriptive',learningNeedOrigin:'validated_workout_evidence',compiledLearningNeed:false,canonicalExerciseId:FINAL_EXERCISE,derivations,sourcePaths:f.reader.trace.paths,providerPayloads:f.providerPayloads,provider:'synthetic recorded mock only; no live calls',preparedBeforeDelivery:true,recipientCount:2,notificationCount:2,deliveryReceiptCount:2,memberCommandReceiptCount:4,bothRead:true,trainerAcknowledged:true,contentDismissed:true,protectedCollectionsUnchanged:true},null,2));
 }finally{await new Promise<void>((done,reject)=>server.close(error=>error?reject(error):done()));}
},360000);
