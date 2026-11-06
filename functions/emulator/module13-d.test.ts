import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {assertFails,initializeTestEnvironment,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc} from 'firebase/firestore';
import {beforeAll,afterAll,beforeEach,it,expect} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import type {DocumentStore,TransactionPort} from '../src/platform/firestore/store';
import {module9MemberCommand} from '../src/modules/coaching/module9-member-service';
import {createRecommendationQueueGeneration} from '../src/modules/recommendation/recommendation-queue-generation';
import {createRecommendationQueueList} from '../src/modules/recommendation/recommendation-queue-reader';
import {createRecommendationLeadDecision} from '../src/modules/recommendation/recommendation-lead-decisions';
import {createRecommendationDelivery} from '../src/modules/recommendation/recommendation-delivery';
import {createMemberRecommendationService,requireRecommendationMember} from '../src/modules/recommendation/recommendation-member-service';
import {authorizeRecommendationSession} from '../src/modules/recommendation/recommendation-configuration';
import {createRecommendationNoticeProjector} from '../src/modules/recommendation/module9-recommendation-projection';
import {createRecommendationConsentV2Command,type RecommendationPurpose} from '../src/modules/recommendation/recommendation-consent-v2';
import type {RecommendationKind} from '../src/modules/recommendation/recommendation-queue-contracts';
import {createModule13DFixture,module13DFixtureDocuments,guardModule13D,createModule13DQueueReader,createModule13DInboxReader,module13DLogicalClock,MODULE13_D_PROJECT,MODULE13_D_ROOT as ROOT} from '../test/module13-d-integration.fixture';
import {MODULE13_C_NOW,MODULE13_C_MEMBER,MODULE13_C_ADMIN,MODULE13_C_COACH} from '../test/module13-c-integration.fixture';

let app:App,db:Firestore,env:RulesTestEnvironment,store:FirestoreStore,f:Awaited<ReturnType<typeof createModule13DFixture>>;
const refresh=(kind:RecommendationKind,commandId=`refresh-${kind}`)=>createRecommendationQueueGeneration({...f.deps,source:f.source})({...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',kind,commandId,continuation:null}});
const query=(kind:RecommendationKind)=>({...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',kind,status:'all',startAtMillis:MODULE13_C_NOW-86400000,endAtMillis:f.deps.clock!(),exerciseId:null,category:null,specialization:null,afterLeadId:null,limit:25}});
const list=()=>createRecommendationQueueList({...f.deps,reader:createModule13DQueueReader(db)});
const decide=()=>createRecommendationLeadDecision({...f.deps,validateTarget:f.validateTarget});
const deliveryRequest=(id:string)=>({...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',recommendationId:id}});
const memberRequest=(id:string,action='get',revision:number|null=null,commandId:string|null=null)=>({...f.request,auth:{uid:MODULE13_C_MEMBER,token:{...f.request.auth.token,email:`${MODULE13_C_MEMBER}@example.invalid`}},data:{schemaVersion:1,organizationId:'synthetic-org',recommendationId:id,action,expectedRevision:revision,commandId}});
const deliver=(id:string)=>createRecommendationDelivery(f.deps)(deliveryRequest(id));
const member=(id:string,action='get',revision:number|null=null,commandId:string|null=null)=>createMemberRecommendationService(f.deps)(memberRequest(id,action,revision,commandId));
async function inbox(afterId?:string){
  const request=memberRequest('unused');
  const result=await module9MemberCommand(store,request.auth,{schemaVersion:1,organizationId:'synthetic-org',action:'inbox',...(afterId?{afterId}:{})},f.deps.clock,
    {...createModule13DInboxReader(db),projectRecommendation:await createRecommendationNoticeProjector(f.deps,request)});
  if(!('records' in result))throw Error('Expected actual Module9 inbox response');return result;
}
async function prepare(kind:RecommendationKind){
  const generated=await refresh(kind);expect(generated.summary).toMatchObject({status:'complete',generated:1});
  const lead=(await list()(query(kind))).leads[0];
  const prepared=await decide()({...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',leadId:lead.leadId,commandId:`prepare-${kind}`,expectedRevision:lead.revision,action:'send',reason:null}});
  expect(prepared.outcome).toBe('prepared');return{lead,id:prepared.recipientRecommendationId!};
}
async function revoke(purpose:RecommendationPurpose){
  const consent=(await db.doc(`${ROOT}/recommendationConsent/${MODULE13_C_MEMBER}`).get()).data()!;
  const request=memberRequest('unused');
  return createRecommendationConsentV2Command(f.deps)({...request,data:{schemaVersion:2,organizationId:'synthetic-org',commandId:`revoke-${purpose}`,expectedRevision:consent.revision,purpose,action:'revoke'}});
}
const size=async(path:string)=>(await db.collection(`${ROOT}/${path}`).get()).size;
async function noDelivery(id:string){expect(await size('notifications')).toBe(0);expect(await size('recommendationDeliveryReceipts')).toBe(0);expect((await db.doc(`${ROOT}/recommendationRecipients/${id}`).get()).data()?.status).toBe('prepared');}
async function protectedSnapshot(){
  const names=['bookings','consultations','paymentReceipts','payments','rewardWallets','rewardReceipts','rewardTransactions','memberPrograms','workoutSessions'];
  return Object.fromEntries(await Promise.all(names.map(async name=>[name,(await db.collection(`${ROOT}/${name}`).get()).docs.map(d=>({id:d.id,data:d.data()}))])));
}
async function seed(clock=module13DLogicalClock()){
  guardModule13D(db);await env.clearFirestore();const batch=db.batch();for(const[path,data]of Object.entries(module13DFixtureDocuments()))batch.set(db.doc(path),data);await batch.commit();
  f=await createModule13DFixture({store,clock});
}
beforeAll(async()=>{
  guardModule13D();app=initializeApp({projectId:MODULE13_D_PROJECT},'module13-d-local');db=getFirestore(app);store=new FirestoreStore(db);
  env=await initializeTestEnvironment({projectId:MODULE13_D_PROJECT,firestore:{host:'127.0.0.1',port:18113,rules:readFileSync('../firebase/firestore.rules','utf8')}});
});
beforeEach(()=>seed());
afterAll(async()=>{await env?.cleanup();await db?.terminate();if(app)await deleteApp(app);});

it.each(['trainer','content'] as const)('persists actual B/C %s preparation, atomic D delivery, typed Module9 inbox and separate read/ack/dismiss',async kind=>{
  const unchanged=await protectedSnapshot(),{lead,id}=await prepare(kind);
  expect(lead.ranking.origin).toBe(kind==='trainer'?'deterministic_single_candidate':'ai_reranked');
  expect(await member(id)).toMatchObject({state:'not_delivered',target:null});expect((await inbox()).records).toEqual([]);
  const receipt=await deliver(id);expect(receipt.status).toBe('delivered');
  expect(await size('notifications')).toBe(1);expect(await size('recommendationDeliveryReceipts')).toBe(1);
  const page=await inbox();expect(page.records).toHaveLength(1);expect(page.records[0]).toMatchObject({id:receipt.notificationId,read:false,recommendation:{recommendationId:id,kind,state:'available'}});
  expect(JSON.stringify(page)).not.toMatch(/sourceFingerprint|memberFingerprint|tutorialSteps|estimatedFormScore|rawStructuredResponse/);
  expect(await member(id,'resolve')).toMatchObject({state:'available',target:lead.target});
  const ack=await member(id,'acknowledge',1,'ack-once');expect(ack).toMatchObject({revision:2,readAtMillis:null,acknowledgedAtMillis:expect.any(Number)});
  expect((await inbox()).records[0].read).toBe(false);expect(await member(id,'acknowledge',1,'ack-once')).toEqual(ack);
  const read=await member(id,'read',2,'read-once');expect(read).toMatchObject({revision:3,readAtMillis:expect.any(Number)});expect((await inbox()).records[0].read).toBe(true);
  expect(await member(id,'dismiss',3,'dismiss-once')).toMatchObject({state:'dismissed',revision:4,target:null});
  expect(await deliver(id)).toEqual(receipt);expect(await size('notifications')).toBe(1);expect(await protectedSnapshot()).toEqual(unchanged);
});
it('replays a lost delivery response and simultaneous workers as exactly one notification and receipt',async()=>{
  const{id}=await prepare('content');await deliver(id); // First response intentionally discarded.
  const results=await Promise.all([deliver(id),deliver(id),deliver(id)]);expect(results[0]).toEqual(results[1]);expect(results[1]).toEqual(results[2]);
  expect(await size('notifications')).toBe(1);expect(await size('recommendationDeliveryReceipts')).toBe(1);
});
it('two first-time concurrent delivery workers atomically converge',async()=>{
  const{id}=await prepare('trainer');const results=await Promise.all([deliver(id),deliver(id)]);expect(results[0]).toEqual(results[1]);
  expect(await size('notifications')).toBe(1);expect(await size('recommendationDeliveryReceipts')).toBe(1);
});
it.each(['consent','inactive','coach','publication','expired'] as const)('blocks prepared %s changes without a false delivery',async reason=>{
  const{lead,id}=await prepare(reason==='coach'?'trainer':'content');
  if(reason==='consent')await revoke('recommendationDelivery');
  if(reason==='inactive')await db.doc(`${ROOT}/members/${MODULE13_C_MEMBER}`).update({status:'inactive'});
  if(reason==='coach')await db.doc(`${ROOT}/coaches/${MODULE13_C_COACH}`).update({status:'inactive'});
  if(reason==='publication'&&lead.target.kind==='content')await db.doc(`${ROOT}/content/${lead.target.destination.routineId}`).update({status:'draft'});
  if(reason==='expired')f.deps.clock=()=>lead.expiresAtMillis+1;
  await expect(deliver(id)).rejects.toMatchObject({code:'failed-precondition'});await noDelivery(id);
});
it.each(['consent','coach','publication','expired'] as const)('redacts delivered %s from details, resolve, inbox and old retries',async reason=>{
  const{lead,id}=await prepare(reason==='coach'?'trainer':'content');await deliver(id);await member(id,'read',1,'read');
  if(reason==='consent')await revoke('recommendationDelivery');
  if(reason==='coach')await db.doc(`${ROOT}/coaches/${MODULE13_C_COACH}`).update({status:'inactive'});
  if(reason==='publication'&&lead.target.kind==='content')await db.doc(`${ROOT}/content/${lead.target.destination.routineId}`).update({status:'draft'});
  if(reason==='expired')f.deps.clock=()=>lead.expiresAtMillis+1;
  for(const action of ['get','resolve'])expect(await member(id,action)).toMatchObject({state:reason==='expired'?'expired':'unavailable',target:null,exerciseLabel:null,explanations:[]});
  const replay=await member(id,'read',1,'read');expect(replay.target).toBeNull();
  expect((await inbox()).records[0]).toMatchObject({recommendation:{state:reason==='expired'?'expired':'unavailable'}});
  expect(await size('notifications')).toBe(1);
});
it('denies wrong Member, wrong organization and missing App Check before exposing details',async()=>{
  const{id}=await prepare('trainer');await deliver(id);
  const request=memberRequest(id),service=createMemberRecommendationService(f.deps);
  await expect(service({...request,auth:f.request.auth})).rejects.toMatchObject({code:'permission-denied'});
  await expect(service({...request,data:{...request.data,organizationId:'foreign-org'}})).rejects.toMatchObject({code:'failed-precondition'});
  await expect(service({...request,app:undefined})).rejects.toMatchObject({code:'unauthenticated'});
  await db.doc(`users/${MODULE13_C_MEMBER}`).update({organizationId:'foreign-org'});
  await expect(service(request)).rejects.toMatchObject({code:'permission-denied'});
});
it('source and precommit transaction failures create no partial recipient, receipt or notice changes',async()=>{
  const{id}=await prepare('trainer');
  await expect(createRecommendationDelivery({...f.deps,resolveTarget:async()=>{throw Error('private source failure');}})(deliveryRequest(id))).rejects.toMatchObject({code:'unavailable',message:expect.not.stringContaining('private')});await noDelivery(id);
  // Real emulator transaction reads execute; force failure after staging every write, before commit.
  const failStore:DocumentStore={transact:work=>store.transact(async tx=>{
    let wrote=false;const wrapped:TransactionPort={...tx,create:(p,d)=>{wrote=true;tx.create(p,d);},set:(p,d)=>{wrote=true;tx.set(p,d);}};
    const result=await work(wrapped);if(wrote)throw Error('private precommit failure');return result;
  })};
  await expect(createRecommendationDelivery({...f.deps,store:failStore})(deliveryRequest(id))).rejects.toMatchObject({code:'unavailable'});await noDelivery(id);
  expect((await deliver(id)).status).toBe('delivered');expect(await size('notifications')).toBe(1);
});
it('simultaneous Member acknowledgment/dismiss commands enforce expected revision and one durable winner',async()=>{
  const{id}=await prepare('trainer');await deliver(id);
  const results=await Promise.allSettled([member(id,'acknowledge',1,'ack-race'),member(id,'dismiss',1,'dismiss-race')]);
  expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);expect(results.filter(r=>r.status==='rejected')).toHaveLength(1);expect(await size('recommendationMemberCommandReceipts')).toBe(1);
  expect((await db.doc(`${ROOT}/notifications/recommendation-${id}`).get()).data()?.read).toBe(false);
});
it('bounded existing Module9 pagination keeps an older delivered recommendation reachable',async()=>{
  const{id}=await prepare('trainer');await deliver(id);const now=f.deps.clock!();
  const batch=db.batch();for(let i=0;i<32;i++)batch.set(db.doc(`${ROOT}/notifications/newer-${i.toString().padStart(2,'0')}`),{schemaVersion:1,recipientId:MODULE13_C_MEMBER,type:'announcement',title:'Fictional gym announcement',message:'Fixture notice',createdAtMillis:now+1000+i,read:false});await batch.commit();
  const first=await inbox();expect(first.records).toHaveLength(30);expect(first.nextAfterId).toBeTruthy();
  const next=await inbox(first.nextAfterId!);expect(next.records.some(n=>n.id===`recommendation-${id}`)).toBe(true);expect(next.nextAfterId).toBeNull();expect((await member(id)).state).toBe('available');
});
it('actual SDK project/endpoint/TLS gates reject foreign bindings and fixture composition defaults off',async()=>{
  const{id}=await prepare('trainer');
  await expect(createRecommendationDelivery({...f.deps,localDelivery:undefined})(deliveryRequest(id))).rejects.toMatchObject({code:'failed-precondition'});
  for(const binding of [{projectId:'production',_settings:{servicePath:'127.0.0.1',port:18113,ssl:false}},{projectId:MODULE13_D_PROJECT,_settings:{servicePath:'remote.invalid',port:18113,ssl:false}},{projectId:MODULE13_D_PROJECT,_settings:{servicePath:'127.0.0.1',port:18113,ssl:true}}])expect(()=>guardModule13D(binding as unknown as Firestore)).toThrow();
});
it('unchanged Rules deny every client protected-state read/write and direct notification mutations',async()=>{
  const{id}=await prepare('trainer');await deliver(id);
  const paths=[`recommendationRecipients/${id}`,`recommendationDeliveryReceipts/${id}`,'recommendationMemberCommandReceipts/injected'];
  for(const uid of [MODULE13_C_MEMBER,MODULE13_C_ADMIN,'foreign-user']){
    const client=env.authenticatedContext(uid,{email_verified:true}).firestore();
    for(const path of paths){await assertFails(getDoc(doc(client,`${ROOT}/${path}`)));await assertFails(setDoc(doc(client,`${ROOT}/${path}`),{injected:true}));}
    await assertFails(setDoc(doc(client,`${ROOT}/notifications/recommendation-${id}`),{read:true}));
  }
  // Existing owner-readable notifications are not relied on to prove purpose consent enforcement.
  expect(readFileSync('src/index.ts','utf8')).not.toMatch(/createRecommendationDelivery|createMemberRecommendationService/);
});

it.skipIf(process.env.MODULE13_D_MEMBER_UI!=='1')('actual Flutter Member inbox opens current Coach and tutorial through HTTP backend and Firestore',async()=>{
  await seed();const logicalStartedAtMillis=f.deps.clock!(),hostStartedAtMillis=Date.now();
  const unchanged=await protectedSnapshot();const methods:Record<string,number>={};
  const server=createServer(async(req,res)=>{
    res.setHeader('Content-Type','application/json');
    try{
      guardModule13D(db);if(req.socket.remoteAddress!=='127.0.0.1')throw Error('Loopback required');
      if(req.method==='GET'&&req.url==='/health'){res.end(JSON.stringify({fixtureOnly:true,nowMillis:f.deps.clock!()}));return;}
      const role=req.headers['x-gainpath-fixture-role'];
      if(req.method!=='POST'||req.url!=='/rpc'||req.headers['x-gainpath-fixture-session']!=='module13-d-local'||!['admin','member'].includes(String(role))){res.statusCode=403;res.end(JSON.stringify({error:{code:'permission-denied',message:'Explicit local fixture session required.'}}));return;}
      let body='';for await(const chunk of req){body+=chunk.toString();if(Buffer.byteLength(body)>16384)throw Error('Bounded request required');}
      const payload=JSON.parse(body);if(!payload||Object.keys(payload).sort().join(',')!=='data,method')throw Error('Invalid RPC');
      methods[payload.method]=(methods[payload.method]??0)+1;
      const request={...(role==='member'?memberRequest('unused'):f.request),data:payload.data};let result:unknown;
      if(role==='admin'){
        if(payload.method==='refresh')result=await createRecommendationQueueGeneration({...f.deps,source:f.source})(request);
        else if(payload.method==='list')result=await list()(request);
        else if(payload.method==='decide')result=await decide()(request);
        else if(payload.method==='deliver')result=await createRecommendationDelivery(f.deps)(request);
        else if(payload.method==='withdraw'){
          if(payload.data.kind==='trainer')await db.doc(`${ROOT}/coaches/${MODULE13_C_COACH}`).update({status:'inactive'});
          else if(payload.data.kind==='content')for(const routine of ['fictional-routine-a','fictional-routine-b'])await db.doc(`${ROOT}/content/${routine}`).update({status:'draft'});
          else throw Error('Unknown fixture target');result={withdrawn:true};
        }else throw Error('Unknown Admin method');
      }else{
        if(payload.method==='member')result=await createMemberRecommendationService(f.deps)(request);
        else if(payload.method==='inbox')result=await inbox(payload.data.afterId??undefined);
        else if(payload.method==='coach'||payload.method==='routine'){
          // Current source data is fetched from Firestore, never reconstructed from stale lead labels.
          const auth=await authorizeRecommendationSession(request,f.deps);
          await store.transact(tx=>requireRecommendationMember(tx,auth,'synthetic-org'));
          const key=payload.method==='coach'?'coachId':'routineId',id=payload.data[key];
          const valid=payload.method==='coach'?id===MODULE13_C_COACH:['fictional-routine-a','fictional-routine-b'].includes(id);
          if(!valid)throw Error('Unknown fixture source');
          const data=(await db.doc(`${ROOT}/${payload.method==='coach'?'coaches':'content'}/${id}`).get()).data();
          if(data?.status!=='published')throw Error('Source unavailable');result=data;
        }else throw Error('Unknown Member method');
      }
      res.end(JSON.stringify({result}));
    }catch(error){const code=typeof error==='object'&&error&&'code'in error?String(error.code):'unavailable';res.end(JSON.stringify({error:{code,message:'Local synthetic recommendation operation failed.'}}));}
  });
  await new Promise<void>((done,reject)=>{server.once('error',reject);server.listen(18114,'127.0.0.1',done);});
  try{
    const flutter=process.env.MODULE13_D_FLUTTER_BIN??'C:/flutter/bin/cache/dart-sdk/bin/dart.exe';
    const exitCode=await new Promise<number>((done,reject)=>{
      const child=spawn(flutter,[resolve('C:/flutter/bin/cache/flutter_tools.snapshot'),'test','test/emulator/module13_member_emulator_test.dart','--no-pub','--reporter','expanded'],{cwd:resolve('../apps/mobile'),env:{...process.env,MODULE13_D_GATEWAY:'127.0.0.1:18114'},stdio:'inherit'});
      child.once('error',reject);child.once('exit',code=>done(code??1));
    });
    expect(exitCode).toBe(0);expect(await size('recommendationRecipients')).toBe(2);expect(await size('notifications')).toBe(2);expect(await size('recommendationDeliveryReceipts')).toBe(2);
    expect(methods.refresh).toBe(2);expect(methods.decide).toBe(2);expect(methods.coach).toBeGreaterThan(0);expect(methods.routine).toBeGreaterThan(0);expect(methods.member).toBeGreaterThan(0);
    expect(methods.deliver).toBe(4);expect(await size('recommendationMemberCommandReceipts')).toBe(4);
    const recipients=(await db.collection(`${ROOT}/recommendationRecipients`).get()).docs.map(d=>d.data());
    const trainer=recipients.find(r=>r.kind==='trainer')!,content=recipients.find(r=>r.kind==='content')!;
    expect(trainer).toMatchObject({status:'delivered',revision:3,memberReadAtMillis:expect.any(Number),acknowledgedAtMillis:expect.any(Number),dismissedAtMillis:null});
    expect(content).toMatchObject({status:'delivered',revision:3,memberReadAtMillis:expect.any(Number),acknowledgedAtMillis:null,dismissedAtMillis:expect.any(Number)});
    expect((await db.collection(`${ROOT}/notifications`).get()).docs.every(d=>d.data().read===true)).toBe(true);
    expect(await protectedSnapshot()).toEqual(unchanged);
    mkdirSync('../build/module13-d',{recursive:true});writeFileSync('../build/module13-d/member-integration-proof.json',JSON.stringify({projectId:MODULE13_D_PROJECT,fixtureOnly:true,realTokenValidation:false,appCheckAttestation:false,calendar:'logical 2026-11-01 plus elapsed host time',logicalStartedAtMillis,hostStartedAtMillis,methods,recipientCount:2,notificationCount:2,deliveryReceiptCount:2,memberCommandReceiptCount:4,bothRead:true,trainerAcknowledged:true,contentDismissed:true,readAndDecisionIndependent:true,protectedCollectionsUnchanged:true,actualFlutterExistingDestinations:true},null,2));
  }finally{await new Promise<void>((done,reject)=>server.close(error=>error?reject(error):done()));}
},240000);
