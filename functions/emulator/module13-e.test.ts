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
import {createRecommendationCallableFacade,mintRecommendationEmulatorCapability,validateRecommendationEmulatorRequest,type RecommendationCallableHandlers,type RecommendationCallableOperation} from '../src/modules/recommendation/recommendation-callable-readiness';
import {module9MemberCommand} from '../src/modules/coaching/module9-member-service';
import {createModule13ESource,module13EFixtureDocuments,module13ELogicalClock,guardModule13E,createModule13EQueueReader,createModule13EInboxReader,MODULE13_E_PROJECT,MODULE13_E_ROOT as ROOT} from '../test/module13-e-integration.fixture';
import {MODULE13_C_NOW,MODULE13_C_MEMBER,MODULE13_C_ADMIN,MODULE13_C_COACH} from '../test/module13-c-integration.fixture';

let app:App,db:Firestore,env:RulesTestEnvironment,store:FirestoreStore,f:Awaited<ReturnType<typeof createModule13ESource>>,facade:ReturnType<typeof createRecommendationCallableFacade>;
let insightCalls=0,historyReads=0;
const counts:Record<string,number>={};
const memberRequest=(data:unknown):InsightsRequest=>({...f.request,auth:{uid:MODULE13_C_MEMBER,token:{...f.request.auth.token,email:`${MODULE13_C_MEMBER}@example.invalid`}},data});
const query=(kind:'trainer'|'content')=>({schemaVersion:1 as const,organizationId:'synthetic-org',kind,status:'all' as const,startAtMillis:MODULE13_C_NOW-86400000,endAtMillis:f.deps.clock!(),exerciseId:null,category:null,specialization:null,afterLeadId:null,limit:25});
const size=async(name:string)=>(await db.collection(`${ROOT}/${name}`).get()).size;
async function protectedSnapshot(){
 const names=['bookings','consultations','paymentReceipts','payments','rewardWallets','rewardReceipts','rewardTransactions','memberPrograms','workoutSessions'];
 return Object.fromEntries(await Promise.all(names.map(async name=>[name,(await db.collection(`${ROOT}/${name}`).get()).docs.map(d=>({id:d.id,data:d.data()}))])));
}
async function insights(request:InsightsRequest){
 guardModule13E(db);insightCalls++;
 const raw=await exerciseInsightsHandler(request,{...f.deps,clock:Date.now,consentNoticePolicies:f.deps.noticePolicies,
  reader:{members:async(org,after,limit)=>{
   guardModule13E(db);if(org!=='synthetic-org')throw Error('Fixture scope required');
   let q=db.collection(`${ROOT}/members`).orderBy(FieldPath.documentId()).limit(limit);if(after)q=q.startAfter(after);
   return(await q.get()).docs.map(d=>({id:d.id,data:d.data()}));
  },backups:async()=>{historyReads++;throw Error('Legacy unscoped history read is forbidden');},
  consentScopedBackups:async()=>{historyReads++;throw Error('No capture-attested source is composed');}}});
 // A whole prior-month query predates from-grant consent. No history is fetched.
 expect(raw.status).toBe('no_consented_members');expect(historyReads).toBe(0);
 const catalog=(await db.collection(`${ROOT}/exerciseVideos`).limit(1000).get()).docs.map(d=>({id:d.id,data:d.data()}));
 const publications=(await db.collection(`${ROOT}/content`).limit(500).get()).docs.map(d=>({id:d.id,data:d.data()}));
 return projectExerciseInsights(raw,catalog,publications,defaultRecommendationConfiguration('synthetic-org'));
}
async function seed(){
 guardModule13E(db);await env.clearFirestore();const batch=db.batch();for(const[path,data]of Object.entries(module13EFixtureDocuments()))batch.set(db.doc(path),data);await batch.commit();
 f=await createModule13ESource({store,clock:module13ELogicalClock()});
 const reads=createRecommendationReadServices({...f.deps,validateTarget:f.validateTarget});
 const handlers:RecommendationCallableHandlers={
  'admin.insights':insights,'admin.configuration.get':reads.configuration,'admin.configuration.save':createRecommendationConfigurationCommand(f.deps),
  'admin.queue.refresh':createRecommendationQueueGeneration({...f.deps,source:f.source}),
  'admin.queue.list':createRecommendationQueueList({...f.deps,reader:createModule13EQueueReader(db)}),
  'admin.queue.detail':reads.lead,'admin.queue.status':reads.status,'admin.queue.decide':createRecommendationLeadDecision({...f.deps,validateTarget:f.validateTarget}),
  'member.consent.get':reads.consent,'member.consent.set':createRecommendationConsentV2Command(f.deps),
  'member.recommendation.command':createMemberRecommendationService(f.deps),'delivery.process':createRecommendationDelivery(f.deps)};
 // Fixed TEST-ONLY composition: all closures above use this one verified SDK/store.
 // The deployable facade stays permanently disabled; no injected-handler activation.
 const capability=mintRecommendationEmulatorCapability(db);
 facade=async(operation,request)=>{
  validateRecommendationEmulatorRequest(capability,operation,request);
  const result=await handlers[operation](request);
  validateRecommendationEmulatorRequest(capability,operation,request);
  if(Buffer.byteLength(JSON.stringify(result))>262144)throw Error('Bounded E result required');
  return result as never;
 };
 insightCalls=0;historyReads=0;for(const key of Object.keys(counts))delete counts[key];
}
async function prepare(kind:'trainer'|'content'){
 const result=await facade('admin.queue.refresh',{...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',kind,commandId:`refresh-${kind}`,continuation:null}});expect(result.summary.generated).toBe(1);
 const lead=(await facade('admin.queue.list',{...f.request,data:query(kind)})).leads[0];
 const prepared=await facade('admin.queue.decide',{...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',leadId:lead.leadId,commandId:`send-${kind}`,expectedRevision:lead.revision,action:'send',reason:null}});
 return{lead,id:prepared.recipientRecommendationId!};
}
async function inbox(afterId?:string){
 const request=memberRequest({});const result=await module9MemberCommand(store,request.auth!,{schemaVersion:1,organizationId:'synthetic-org',action:'inbox',...(afterId?{afterId}:{})},f.deps.clock,
 {...createModule13EInboxReader(db),projectRecommendation:await createRecommendationNoticeProjector(f.deps,request)});
 if(!('records'in result))throw Error('Expected existing Module9 inbox');return result;
}
beforeAll(async()=>{
 guardModule13E();app=initializeApp({projectId:MODULE13_E_PROJECT},'module13-e-local');db=getFirestore(app);store=new FirestoreStore(db);guardModule13E(db);
 env=await initializeTestEnvironment({projectId:MODULE13_E_PROJECT,firestore:{host:'127.0.0.1',port:18115,rules:readFileSync('../firebase/firestore.rules','utf8')}});
});
beforeEach(seed);
afterAll(async()=>{await env?.cleanup();await db?.terminate();if(app)await deleteApp(app);});

it('protects current read contracts and catalog-only Insights without historical payload access',async()=>{
 const now=Date.now();const result=await facade('admin.insights',{...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',startAtMillis:now-30*86400000,endAtMillis:now}});
 expect(result).toMatchObject({mode:'descriptive_only',groups:[],privacy:{state:'review_required'}});expect(result.content).toHaveLength(1);expect(result.content[0].publishedTutorials).toBe(2);expect(historyReads).toBe(0);
 expect(await facade('admin.configuration.get',f.request)).toMatchObject({revision:0,policies:[],activation:{generation:false,externalAi:false,matching:false,delivery:false}});
 const consent=await facade('member.consent.get',memberRequest({schemaVersion:2,organizationId:'synthetic-org'}));expect(consent?.purposes.recommendationDelivery.granted).toBe(true);
 const{lead}=await prepare('trainer');expect((await facade('admin.queue.detail',{...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',leadId:lead.leadId}})).lead.leadId).toBe(lead.leadId);
 expect((await facade('admin.queue.status',{...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',runId:lead.runId}})).summary.status).toBe('complete');
});
it('rejects cross-role, wrong organization, absent App Check and forged activation before exposing read state',async()=>{
 await expect(facade('admin.configuration.get',{...f.request,app:undefined})).rejects.toMatchObject({code:'unauthenticated'});
 await expect(facade('admin.configuration.get',memberRequest({schemaVersion:1,organizationId:'synthetic-org'}))).rejects.toMatchObject({code:'permission-denied'});
 await expect(facade('member.consent.get',{...f.request,data:{schemaVersion:2,organizationId:'synthetic-org'}})).rejects.toMatchObject({code:'permission-denied'});
 await expect(facade('admin.configuration.get',{...f.request,data:{schemaVersion:1,organizationId:'foreign'}})).rejects.toThrow();
 await expect(facade('admin.configuration.get',{...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',enabled:true}})).rejects.toThrow();
});
it('same-lifetime delivery duplicate/concurrent retries remain once-only and revoke current detail',async()=>{
 const{id}=await prepare('content'),request={...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',recommendationId:id}};
 const first=await facade('delivery.process',request);expect(await Promise.all([facade('delivery.process',request),facade('delivery.process',request)])).toEqual([first,first]);expect(await size('notifications')).toBe(1);
 const command={schemaVersion:1,organizationId:'synthetic-org',recommendationId:id,action:'get',commandId:null,expectedRevision:null};
 expect((await facade('member.recommendation.command',memberRequest(command))).state).toBe('available');
 const c=(await db.doc(`${ROOT}/recommendationConsent/${MODULE13_C_MEMBER}`).get()).data()!;
 await facade('member.consent.set',memberRequest({schemaVersion:2,organizationId:'synthetic-org',commandId:'revoke',expectedRevision:c.revision,purpose:'recommendationDelivery',action:'revoke'}));
 expect(await facade('member.recommendation.command',memberRequest(command))).toMatchObject({state:'unavailable',target:null,explanations:[]});
 await expect(facade('delivery.process',request)).rejects.toThrow();expect(await size('notifications')).toBe(1);
});
it('unchanged Rules protect E private collections and direct notification mutation',async()=>{
 const{id}=await prepare('trainer');await facade('delivery.process',{...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',recommendationId:id}});
 for(const uid of [MODULE13_C_MEMBER,MODULE13_C_ADMIN,'foreign']){
  const client=env.authenticatedContext(uid,{email_verified:true}).firestore();
  for(const name of ['recommendationConsent','recommendationLeads','recommendationRecipients','recommendationDeliveryReceipts','recommendationMemberCommandReceipts']){
   const path=`${ROOT}/${name}/${name==='recommendationConsent'?MODULE13_C_MEMBER:id}`;
   await assertFails(getDoc(doc(client,path)));await assertFails(setDoc(doc(client,path),{injected:true}));
  }await assertFails(setDoc(doc(client,`${ROOT}/notifications/recommendation-${id}`),{read:true}));
 }
});

it.skipIf(process.env.MODULE13_E_CLIENT_UI!=='1')('actual Admin Insights review Send hands off both kinds to actual Member current routes in one backend lifetime',async()=>{
 const unchanged=await protectedSnapshot(),notices:Record<string,string>={};
 const server=createServer(async(req,res)=>{
  res.setHeader('Content-Type','application/json');
  try{
   guardModule13E(db);if(req.socket.remoteAddress!=='127.0.0.1')throw Error('Loopback required');
   if(req.method==='GET'&&req.url==='/health'){res.end(JSON.stringify({fixtureOnly:true,nowMillis:f.deps.clock!(),notices}));return;}
   const role=req.headers['x-gainpath-fixture-role'];
   if(req.method!=='POST'||req.url!=='/rpc'||req.headers['x-gainpath-fixture-session']!=='module13-e-local'||!['admin','member'].includes(String(role))){res.statusCode=403;res.end(JSON.stringify({error:{code:'permission-denied'}}));return;}
   let body='';for await(const chunk of req){body+=chunk.toString();if(Buffer.byteLength(body)>16384)throw Error('Bounded request required');}
   const payload=JSON.parse(body);if(!payload||Object.keys(payload).sort().join(',')!=='data,method')throw Error('Invalid RPC');
   counts[`${role}.${payload.method}`]=(counts[`${role}.${payload.method}`]??0)+1;
   const request={...(role==='member'?memberRequest({}):f.request),data:payload.data};let result:unknown;
   const adminMethods:Record<string,RecommendationCallableOperation>={insights:'admin.insights',configuration:'admin.configuration.get',refresh:'admin.queue.refresh',list:'admin.queue.list',detail:'admin.queue.detail',decide:'admin.queue.decide'};
   if(role==='admin'&&adminMethods[payload.method])result=await facade(adminMethods[payload.method],request);
   else if(role==='member'&&payload.method==='member')result=await facade('member.recommendation.command',request);
   else if(role==='member'&&payload.method==='inbox')result=await inbox(payload.data.afterId??undefined);
   else if(role==='member'&&['coach','routine'].includes(payload.method)){
    const auth=await authorizeRecommendationSession(request,f.deps);await store.transact(tx=>requireRecommendationMember(tx,auth,'synthetic-org'));
    const id=payload.data[payload.method==='coach'?'coachId':'routineId'];if(payload.method==='coach'?id!==MODULE13_C_COACH:!['fictional-routine-a','fictional-routine-b'].includes(id))throw Error('Unknown fixture source');
    const data=(await db.doc(`${ROOT}/${payload.method==='coach'?'coaches':'content'}/${id}`).get()).data();if(data?.status!=='published')throw Error('Source unavailable');result=data;
   }else if(role==='admin'&&payload.method==='withdraw'&&payload.data.kind==='trainer'){await db.doc(`${ROOT}/coaches/${MODULE13_C_COACH}`).update({status:'inactive'});result={withdrawn:true};}
   else throw Error('Unknown fixture operation');
   res.end(JSON.stringify({result}));
  }catch(error){const code=typeof error==='object'&&error&&'code'in error?String(error.code):'unavailable';res.end(JSON.stringify({error:{code,message:'Local E operation failed.'}}));}
 });
 await new Promise<void>((done,reject)=>{server.once('error',reject);server.listen(18116,'127.0.0.1',done);});
 async function flutter(appName:string,test:string){
  return new Promise<number>((done,reject)=>{
   const child=spawn('C:/flutter/bin/cache/dart-sdk/bin/dart.exe',[resolve('C:/flutter/bin/cache/flutter_tools.snapshot'),'test',test,'--no-pub','--reporter','expanded'],{cwd:resolve(`../apps/${appName}`),env:{...process.env,MODULE13_E_GATEWAY:'127.0.0.1:18116'},stdio:'inherit'});
   child.once('error',reject);child.once('exit',code=>done(code??1));
  });
 }
 try{
  expect(await flutter('admin_web','test/emulator/module13_e_admin_emulator_test.dart')).toBe(0);
  expect(counts['admin.detail']).toBe(2); // Both actual View details buttons fetch current protected state.
  expect(insightCalls).toBeGreaterThan(0);expect(historyReads).toBe(0);expect(await size('notifications')).toBe(0);expect(await size('recommendationRecipients')).toBe(2);
  for(const kind of ['trainer','content'] as const){
   const lead=(await facade('admin.queue.list',{...f.request,data:query(kind)})).leads[0];expect(lead.status).toBe('sent');
   const id=lead.decision!.recipientRecommendationId!,request={...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',recommendationId:id}};
   const delivered=await facade('delivery.process',request);expect(await facade('delivery.process',request)).toEqual(delivered);notices[kind]=delivered.notificationId;
  }
  expect(await flutter('mobile','test/emulator/module13_e_member_emulator_test.dart')).toBe(0);
  expect(await size('notifications')).toBe(2);expect(await size('recommendationDeliveryReceipts')).toBe(2);expect(await size('recommendationMemberCommandReceipts')).toBe(4);
  const recipients=(await db.collection(`${ROOT}/recommendationRecipients`).get()).docs.map(d=>d.data());
  expect(recipients.find(r=>r.kind==='trainer')).toMatchObject({status:'delivered',revision:3,memberReadAtMillis:expect.any(Number),acknowledgedAtMillis:expect.any(Number),dismissedAtMillis:null});
  expect(recipients.find(r=>r.kind==='content')).toMatchObject({status:'delivered',revision:3,memberReadAtMillis:expect.any(Number),acknowledgedAtMillis:null,dismissedAtMillis:expect.any(Number)});
  expect((await db.collection(`${ROOT}/notifications`).get()).docs.every(d=>d.data().read===true)).toBe(true);expect(await protectedSnapshot()).toEqual(unchanged);
  mkdirSync('../build/module13-e',{recursive:true});writeFileSync('../build/module13-e/combined-client-proof.json',JSON.stringify({projectId:MODULE13_E_PROJECT,firestoreHost:'127.0.0.1:18115',gatewayHost:'127.0.0.1:18116',fixtureOnly:true,realTokenValidation:false,appCheckAttestation:false,sameBackendLifetime:true,actualAdminWidget:true,actualMemberWidget:true,currentAdminDetailChecks:counts['admin.detail'],counts,insightCalls,historyReads,insightMode:'catalog_only_no_consented_members',compiledNeedBridge:'existing C fictional need; no approved production threshold or automatic insight-derived eligibility',provider:'synthetic recorded mock only; no live calls',preparedBeforeDelivery:true,recipientCount:2,notificationCount:2,deliveryReceiptCount:2,memberCommandReceiptCount:4,bothRead:true,trainerAcknowledged:true,contentDismissed:true,protectedCollectionsUnchanged:true},null,2));
 }finally{await new Promise<void>((done,reject)=>server.close(error=>error?reject(error):done()));}
},360000);
