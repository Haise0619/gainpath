import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {spawn} from 'node:child_process';
import {createServer,type Server} from 'node:http';
import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {assertFails,initializeTestEnvironment,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,getDocs,collection} from 'firebase/firestore';
import {beforeAll,afterAll,beforeEach,it,expect} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {createRecommendationQueueGeneration} from '../src/modules/recommendation/recommendation-queue-generation';
import {createRecommendationQueueList} from '../src/modules/recommendation/recommendation-queue-reader';
import {createRecommendationLeadDecision} from '../src/modules/recommendation/recommendation-lead-decisions';
import {createRecommendationConsentV2Command,type RecommendationPurpose} from '../src/modules/recommendation/recommendation-consent-v2';
import {createFirestoreRecommendationQueueReader} from '../src/modules/recommendation/firestore-recommendation-queue';
import {createRecommendationReadServices} from '../src/modules/recommendation/recommendation-read-services';
import {createCurrentRecommendationTargetResolver} from '../src/modules/recommendation/recommendation-target-resolver';
import type {RecommendationLead,RecommendationKind} from '../src/modules/recommendation/recommendation-queue-contracts';
import {createModule13CFixture,module13CFixtureDocuments,MODULE13_C_NOW,MODULE13_C_MEMBER,MODULE13_C_ADMIN,MODULE13_C_COACH} from '../test/module13-c-integration.fixture';

const projectId='demo-gainpath-module13-c',host='127.0.0.1:18111',ROOT='orgs/synthetic-org';
let app:App,db:Firestore,env:RulesTestEnvironment,f:Awaited<ReturnType<typeof createModule13CFixture>>,store:FirestoreStore;
const guard=()=>{if(process.env.FIRESTORE_EMULATOR_HOST!==host||process.env.GCLOUD_PROJECT!==projectId||process.env.GOOGLE_CLOUD_PROJECT!==projectId)throw Error('Dedicated loopback demo emulator required; no production fallback.');};
const generate=()=>createRecommendationQueueGeneration({...f.deps,source:f.source});
const decide=()=>createRecommendationLeadDecision({...f.deps,validateTarget:f.validateTarget});
const reader=()=>createFirestoreRecommendationQueueReader({firestore:db,localReview:{mode:'synthetic_emulator_only'}});
const list=()=>createRecommendationQueueList({...f.deps,reader:reader()});
const refresh=(kind:RecommendationKind,commandId=`refresh-${kind}`)=>generate()({...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',kind,commandId,continuation:null}});
const query=(kind:RecommendationKind,patch:Record<string,unknown>={})=>({...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',kind,status:'all',startAtMillis:MODULE13_C_NOW-86400000,endAtMillis:f.deps.clock!(),exerciseId:null,category:null,specialization:null,afterLeadId:null,limit:25,...patch}});
const decision=(lead:RecommendationLead,commandId:string,action:'send'|'dismiss'='send')=>({...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',leadId:lead.leadId,commandId,expectedRevision:lead.revision,action,reason:action==='dismiss'?'Already reviewed with fictional Member':null}});
const lead=async(kind:RecommendationKind)=>{await refresh(kind);return(await list()(query(kind))).leads[0];};
async function revoke(purpose:RecommendationPurpose){
  const consent=(await db.doc(`${ROOT}/recommendationConsent/${MODULE13_C_MEMBER}`).get()).data()!;
  return createRecommendationConsentV2Command(f.deps)({...f.request,auth:{...f.request.auth,uid:MODULE13_C_MEMBER,token:{...f.request.auth.token,email:`${MODULE13_C_MEMBER}@example.invalid`}},data:{schemaVersion:2,organizationId:'synthetic-org',commandId:`revoke-${purpose}`,expectedRevision:consent.revision,purpose,action:'revoke'}});
}
async function regrant(purpose:RecommendationPurpose){
  const consent=(await db.doc(`${ROOT}/recommendationConsent/${MODULE13_C_MEMBER}`).get()).data()!;
  return createRecommendationConsentV2Command(f.deps)({...f.request,auth:{...f.request.auth,uid:MODULE13_C_MEMBER,token:{...f.request.auth.token,email:`${MODULE13_C_MEMBER}@example.invalid`}},data:{schemaVersion:2,organizationId:'synthetic-org',commandId:`regrant-${purpose}`,expectedRevision:consent.revision,purpose,action:'grant',noticePolicyId:'fictional-notice',acceptedNoticeVersion:'v1',acceptedContentVersion:'v1'}});
}
async function seed(clock?:()=>number){
  let tick=0;clock??=()=>MODULE13_C_NOW+tick++;
  guard();await env.clearFirestore();const batch=db.batch();for(const[p,d]of Object.entries(module13CFixtureDocuments()))batch.set(db.doc(p),d);await batch.commit();
  f=await createModule13CFixture({store,clock});
}
beforeAll(async()=>{
  guard();app=initializeApp({projectId},'module13-c-local');db=getFirestore(app);store=new FirestoreStore(db);
  env=await initializeTestEnvironment({projectId,firestore:{host:'127.0.0.1',port:18111,rules:readFileSync('../firebase/firestore.rules','utf8')}});
});
afterAll(async()=>{await env?.cleanup();await db?.terminate();if(app)await deleteApp(app);});
beforeEach(()=>seed());

it('persists current B Trainer and Content generation, minimal review projections, run summaries and idempotent Refresh',async()=>{
  for(const kind of ['trainer','content'] as const){
    const first=await refresh(kind),replay=await refresh(kind);expect(replay).toEqual(first);
    expect(first.summary).toMatchObject({status:'complete',processed:1,generated:1,abstained:0});
    const page=await list()(query(kind));expect(page.leads).toHaveLength(1);expect(page.generation).toEqual(first.summary);
    expect(page.leads[0]).toMatchObject({kind,status:'pending',memberLabel:'Fictional Member Maya',ranking:{origin:kind==='trainer'?'deterministic_single_candidate':'ai_reranked'}});
    expect(JSON.stringify(page)).not.toMatch(/payloadJson|tutorialSteps|rawStructuredResponse|usageMetadata/);
    const duplicate=await refresh(kind,`second-${kind}`);expect(duplicate.summary.generated).toBe(0);
  }
  expect((await db.collection(`${ROOT}/recommendationLeads`).get()).size).toBe(2);
  expect((await db.collection(`${ROOT}/notifications`).get()).empty).toBe(true);
  expect((await db.collection(`${ROOT}/workoutSessions`).get()).empty).toBe(true);
});
it('prepares recipient, audit, versioned decision and receipt atomically, with no actual notification; retries replay',async()=>{
  const target=await lead('trainer'),request=decision(target,'prepare-once');
  const result=await decide()(request);expect(result).toMatchObject({status:'sent',outcome:'prepared',revision:2,deliveryStatus:'prepared_local'});
  expect(await decide()(request)).toEqual(result);
  const documents=await Promise.all(['recommendationCommandReceipts','recommendationDecisionAudits','recommendationRecipients'].map(c=>db.collection(`${ROOT}/${c}`).get()));
  documents.forEach(s=>expect(s.size).toBe(1));
  expect(documents[2].docs[0].data()).toMatchObject({memberId:MODULE13_C_MEMBER,status:'prepared',memberReadAtMillis:null,acknowledgedAtMillis:null,notificationDraft:{read:false,recommendationId:result.recipientRecommendationId}});
  expect((await db.doc(`${ROOT}/recommendationLeads/${target.leadId}`).get()).data()).toMatchObject({status:'sent',revision:2});
  expect((await db.collection(`${ROOT}/notifications`).get()).empty).toBe(true);
});
it('reports current no-eligible-candidate abstentions for unpublished content and withdrawn Coach, without queue writes',async()=>{
  await db.doc(`${ROOT}/content/fictional-routine-a`).update({status:'draft'});
  await db.doc(`${ROOT}/content/fictional-routine-b`).update({status:'draft'});
  await db.doc(`${ROOT}/coaches/${MODULE13_C_COACH}`).update({status:'withdrawn'});
  for(const kind of ['trainer','content'] as const){
    const result=await refresh(kind);expect(result.summary).toMatchObject({status:'complete',candidateCount:0,generated:0,abstained:1,abstentionReasons:{no_eligible_candidates:1}});
    expect((await list()(query(kind))).leads).toEqual([]);
  }
  expect((await db.collection(`${ROOT}/recommendationLeads`).get()).empty).toBe(true);
  expect((await db.collection(`${ROOT}/recommendationRecipients`).get()).empty).toBe(true);
});
it('regrant makes the old consent fingerprint stale; a new Refresh renews the same lead at revision 3 with a refresh audit',async()=>{
  const original=await lead('content');await revoke('recommendationDelivery');await regrant('recommendationDelivery');
  expect(await decide()(decision(original,'stale-after-regrant'))).toMatchObject({status:'stale',revision:2,outcome:'blocked'});
  expect((await refresh('content','renew-after-regrant')).summary.generated).toBe(1);
  const renewed=(await list()(query('content'))).leads[0];
  expect(renewed).toMatchObject({leadId:original.leadId,status:'pending',revision:3,decision:null,createdAtMillis:original.createdAtMillis});
  expect(renewed.memberFingerprint).not.toBe(original.memberFingerprint);expect(renewed.runId).not.toBe(original.runId);
  const audits=await db.collection(`${ROOT}/recommendationRefreshAudits`).get();expect(audits.size).toBe(1);
  expect(audits.docs[0].data()).toMatchObject({previousStatus:'stale',previousRevision:2,revision:3,leadId:original.leadId});
  await expect(decide()(decision(original,'stale-ui-after-renewal'))).rejects.toMatchObject({code:'aborted'});
  expect(await decide()(decision(renewed,'send-renewed'))).toMatchObject({outcome:'prepared',revision:4});
  expect((await db.collection(`${ROOT}/recommendationRecipients`).get()).size).toBe(1);
});
it('an expired content lead cannot Send and can be safely renewed by a new Refresh without duplicating its stable ID',async()=>{
  let epoch=MODULE13_C_NOW;await seed(()=>epoch++);
  const original=await lead('content');epoch=original.expiresAtMillis+1;
  expect(await decide()(decision(original,'expired-send'))).toMatchObject({status:'expired',revision:2,outcome:'blocked'});
  expect((await refresh('content','renew-expired')).summary.generated).toBe(1);
  const renewed=(await list()(query('content'))).leads[0];
  expect(renewed).toMatchObject({leadId:original.leadId,revision:3,status:'pending',decision:null});expect(renewed.expiresAtMillis).toBeGreaterThan(original.expiresAtMillis);
  expect((await db.collection(`${ROOT}/recommendationLeads`).get()).size).toBe(1);
  expect((await db.collection(`${ROOT}/recommendationRefreshAudits`).get()).size).toBe(1);
  expect((await db.collection(`${ROOT}/recommendationRecipients`).get()).empty).toBe(true);
});
it.each(['insufficient','unsupported','missing_consent'] as const)('persists an explicit %s abstention without calling candidate sources',async reason=>{
  if(reason==='missing_consent')await revoke('recommendationGeneration');else f.source.items[0].evidenceStatus=reason;
  f.source.recommend=async()=>{throw Error('Abstention must precede source access');};
  const result=await refresh('content');const key=reason==='missing_consent'?reason:`${reason}_evidence`;
  expect(result.summary).toMatchObject({status:'complete',generated:0,abstained:1,abstentionReasons:{[key]:1}});
  expect((await db.collection(`${ROOT}/recommendationLeads`).get()).empty).toBe(true);
});
it('records semantic abstention from the mocked B ranker separately from an empty eligible catalog',async()=>{
  f=await createModule13CFixture({store,clock:f.deps.clock,grantConsent:false,provider:async request=>({text:JSON.stringify({schemaVersion:1,rankings:request.candidates.map(c=>({label:c.label,relevance:0,reasonCodes:[],evidenceRefs:[],abstain:true}))}),model:'synthetic-recorded-abstention',latencyMillis:0,usage:{inputTokens:null,outputTokens:null,thinkingTokens:null,totalTokens:null}})});
  const result=await refresh('content');expect(result.summary).toMatchObject({candidateCount:2,generated:0,abstained:1,abstentionReasons:{semantic_abstention:1,no_eligible_candidates:0}});
});
it('a conflicting existing recipient aborts every decision write and leaves the pending revision intact',async()=>{
  const target=await lead('trainer');
  // Same stable business key is shared by lead and prepared recipient.
  await db.doc(`${ROOT}/recommendationRecipients/${target.leadId}`).set({syntheticConflict:true});
  await expect(decide()(decision(target,'conflicting-recipient'))).rejects.toMatchObject({code:'aborted'});
  expect((await db.doc(`${ROOT}/recommendationLeads/${target.leadId}`).get()).data()).toMatchObject({status:'pending',revision:1,decision:null});
  expect((await db.collection(`${ROOT}/recommendationCommandReceipts`).get()).empty).toBe(true);
  expect((await db.collection(`${ROOT}/recommendationDecisionAudits`).get()).empty).toBe(true);
});
it('resolves concurrent Send/Send and Send/Dismiss with exactly one durable decision',async()=>{
  for(const kind of ['trainer','content'] as const){
    const target=await lead(kind);const result=await Promise.allSettled([decide()(decision(target,`${kind}-a`)),decide()(decision(target,`${kind}-b`,kind==='trainer'?'send':'dismiss'))]);
    expect(result.filter(r=>r.status==='fulfilled')).toHaveLength(1);expect(result.filter(r=>r.status==='rejected')).toHaveLength(1);
  }
  expect((await db.collection(`${ROOT}/recommendationCommandReceipts`).get()).size).toBe(2);
  expect((await db.collection(`${ROOT}/recommendationDecisionAudits`).get()).size).toBe(2);
  expect((await db.collection(`${ROOT}/recommendationRecipients`).get()).size).toBeLessThanOrEqual(2);
});
it('concurrent refresh lease admits only one invocation and dismissed input never recreates',async()=>{
  const original=f.source.recommend;let enter!:()=>void,release!:()=>void;
  const entered=new Promise<void>(r=>enter=r),hold=new Promise<void>(r=>release=r);
  f.source.recommend=async(...args)=>{enter();await hold;return original(...args);};
  const first=refresh('content','refresh-held');await entered;
  await expect(refresh('content','refresh-competing')).rejects.toMatchObject({code:'aborted'});release();await first;f.source.recommend=original;
  const target=(await list()(query('content'))).leads[0];await decide()(decision(target,'dismiss','dismiss'));
  expect((await refresh('content','after-dismiss')).summary.generated).toBe(0);
  expect((await list()(query('content'))).leads[0]).toMatchObject({status:'dismissed',revision:2});
});
it('revoked independent external AI purpose still permits deterministic generation without inference',async()=>{
  await revoke('externalAiInference');
  const result=await refresh('content');expect(result.summary.generated).toBe(1);
  expect((await list()(query('content'))).leads[0].ranking).toMatchObject({origin:'deterministic_fallback',model:null,fallbackReason:'provider_not_configured'});
});
it('revocation during inference aborts the page with no partial leads and an explicit failed run',async()=>{
  const original=f.source.recommend;
  f.source.recommend=async(...args)=>{const result=await original(...args);await revoke('recommendationGeneration');return result;};
  await expect(refresh('content')).rejects.toMatchObject({code:'aborted'});
  expect((await db.collection(`${ROOT}/recommendationLeads`).get()).empty).toBe(true);
  expect((await db.doc(`${ROOT}/recommendationGenerationState/content`).get()).data()).toMatchObject({summary:{status:'failed'}});
});
it.each(['consent','coach','publication','run'] as const)('blocks Send for revoked/stale %s with no recipient',async source=>{
  const target=await lead(source==='coach'?'trainer':'content');
  if(source==='consent')await revoke('recommendationDelivery');
  if(source==='coach')await db.doc(`${ROOT}/coaches/${MODULE13_C_COACH}`).update({status:'withdrawn'});
  if(source==='publication'&&target.target.kind==='content')await db.doc(`${ROOT}/content/${target.target.destination.routineId}`).update({status:'draft'});
  if(source==='run')await db.doc(`${ROOT}/recommendationRuns/${target.runId}`).update({'summary.status':'failed'});
  expect(await decide()(decision(target,`stale-${source}`))).toMatchObject({outcome:'blocked',status:source==='consent'?'revoked':'stale',deliveryStatus:'not_prepared'});
  expect((await db.collection(`${ROOT}/recommendationRecipients`).get()).empty).toBe(true);
});
it('canonical Admin denial, cross-org request and scope substituted adapter fail before queue exposure',async()=>{
  await refresh('trainer');
  await expect(list()({...query('trainer'),app:undefined})).rejects.toMatchObject({code:'unauthenticated'});
  await expect(list()({...query('trainer'),auth:{...f.request.auth,uid:MODULE13_C_MEMBER,token:{...f.request.auth.token,email:`${MODULE13_C_MEMBER}@example.invalid`}}})).rejects.toMatchObject({code:'permission-denied'});
  await expect(list()(query('trainer',{organizationId:'foreign-org'}))).rejects.toMatchObject({code:'failed-precondition'});
  await expect(reader().readLeads('foreign-org',null,1)).rejects.toMatchObject({code:'permission-denied'});
  await db.doc(`users/${MODULE13_C_ADMIN}`).update({organizationId:'foreign-org'});
  await expect(list()(query('trainer'))).rejects.toMatchObject({code:'permission-denied'});
});
it('actual adapter orders by document ID, honors bounded cursor and excludes foreign organization docs',async()=>{
  await refresh('trainer');await refresh('content');const first=await reader().readLeads('synthetic-org',null,1),second=await reader().readLeads('synthetic-org',first[0].id,1);
  expect(first).toHaveLength(1);expect(second).toHaveLength(1);expect(first[0].id<second[0].id).toBe(true);
  await db.doc('orgs/foreign-org/recommendationLeads/foreign').set({secret:'foreign'});
  expect(await reader().readLeads('synthetic-org',second[0].id,1)).toEqual([]);
  for(const limit of [0,102])await expect(reader().readLeads('synthetic-org',null,limit)).rejects.toMatchObject({code:'invalid-argument'});
});
it('unchanged checked-in Rules deny client reads/writes to every queue, run, receipt, audit and recipient path',async()=>{
  const target=await lead('trainer');
  const paths=[`recommendationLeads/${target.leadId}`,'recommendationRuns/run','recommendationRefreshLocks/trainer','recommendationGenerationState/trainer','recommendationCommandReceipts/receipt','recommendationDecisionAudits/audit','recommendationRefreshAudits/audit','recommendationRecipients/recipient'];
  for(const uid of [MODULE13_C_MEMBER,MODULE13_C_ADMIN,'foreign-user']){
    const client=env.authenticatedContext(uid,{email_verified:true}).firestore();
    for(const path of paths){await assertFails(getDoc(doc(client,`${ROOT}/${path}`)));await assertFails(setDoc(doc(client,`${ROOT}/${path}`),{injected:true}));}
    await assertFails(getDocs(collection(client,`${ROOT}/recommendationLeads`)));
  }
  const source=readFileSync('src/index.ts','utf8');expect(source).not.toMatch(/createRecommendationQueueGeneration|createRecommendationLeadDecision|createFirestoreRecommendationQueueReader/);
});

it.skipIf(process.env.MODULE13_C_ADMIN_UI!=='1')('actual Flutter Admin Refresh, Send and Dismiss persist through explicit fixture gateway',async()=>{
  await seed(Date.now);guard();
  const server:Server=createServer(async(req,res)=>{
    res.setHeader('Content-Type','application/json');
    try{
      guard();if(req.socket.remoteAddress!=='127.0.0.1')throw Error('Loopback only');
      if(req.method==='GET'&&req.url==='/health'){res.end(JSON.stringify({fixtureOnly:true,nowMillis:Date.now()}));return;}
      if(req.method!=='POST'||req.url!=='/rpc'||req.headers['x-gainpath-fixture-session']!=='module13-c-local-admin'){res.statusCode=403;res.end(JSON.stringify({error:{code:'permission-denied',message:'Explicit local fixture session required.'}}));return;}
      let body='';for await(const chunk of req){body+=chunk.toString();if(Buffer.byteLength(body)>16384)throw Error('Bounded request required');}
      const payload=JSON.parse(body);if(!payload||Object.keys(payload).sort().join(',')!=='data,method')throw Error('Invalid RPC');
      const command={...f.request,data:payload.data};let result:unknown;
      if(payload.method==='list')result=await list()(command);else if(payload.method==='refresh')result=await generate()(command);else if(payload.method==='decide')result=await decide()(command);
      // E hardening: View details uses the fresh protected read, not cached list data.
      else if(payload.method==='detail')result=await createRecommendationReadServices({...f.deps,localDelivery:{fixtureSetId:'module13-d-v1'},resolveTarget:createCurrentRecommendationTargetResolver({revalidateEligibility:f.validateTarget}),validateTarget:f.validateTarget}).lead(command);
      else throw Error('Unknown method');
      res.end(JSON.stringify({result}));
    }catch(error){const code=typeof error==='object'&&error&&'code'in error?String(error.code):'unavailable';res.end(JSON.stringify({error:{code,message:'Local synthetic recommendation operation failed.'}}));}
  });
  await new Promise<void>((resolve,reject)=>{server.once('error',reject);server.listen(18112,'127.0.0.1',resolve);});
  try{
    const flutter=process.env.MODULE13_C_FLUTTER_BIN??'C:/flutter/bin/cache/dart-sdk/bin/dart.exe';
    const tool=resolve('C:/flutter/bin/cache/flutter_tools.snapshot');
    const exitCode=await new Promise<number>((done,reject)=>{
      const child=spawn(flutter,[tool,'test','test/emulator/module13_queue_emulator_test.dart','--no-pub','--reporter','expanded'],{cwd:resolve('../apps/admin_web'),env:{...process.env,MODULE13_C_GATEWAY:'127.0.0.1:18112'},stdio:'inherit'});child.once('error',reject);child.once('exit',code=>done(code??1));
    });
    expect(exitCode).toBe(0);
    expect((await db.collection(`${ROOT}/recommendationRecipients`).get()).size).toBe(1);
    expect((await db.collection(`${ROOT}/recommendationDecisionAudits`).get()).size).toBe(2);
    expect((await db.collection(`${ROOT}/notifications`).get()).empty).toBe(true);
  }finally{await new Promise<void>((resolve,reject)=>server.close(error=>error?reject(error):resolve()));}
},180000);
