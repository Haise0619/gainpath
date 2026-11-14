import {readFileSync} from 'node:fs';
import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {initializeTestEnvironment,assertFails,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc} from 'firebase/firestore';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {keyOf} from '../src/platform/idempotency';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {acknowledgeWorkoutConsent,submitWorkoutSession,ENABLED_WORKOUT_TUPLES} from '../src/modules/workouts/workout-service';
import {createRecommendationConsentV2Command} from '../src/modules/recommendation/recommendation-consent-v2';
import {createCanonicalRecommendationLifecycle,type ReviewedCanonicalRuntime} from '../src/modules/recommendation/canonical-recommendation-lifecycle';
import {createCanonicalRecommendationBackend,CANONICAL_RECOMMENDATION_RELEASE} from '../src/modules/recommendation/canonical-recommendation-backend';
import {createAcceptedWorkoutRecommendationHandler,createCanonicalDeliveryRecovery} from '../src/modules/recommendation/canonical-recommendation-events';
import {deriveReviewedAcceptedSuggestion,type ReviewedAcceptedDerivationPolicy,type CanonicalPersonalizationCandidate} from '../src/modules/recommendation/canonical-reviewed-derivation';
import {createCanonicalNoticeProjector} from '../src/modules/recommendation/canonical-notice-projection';
import {module9MemberCommand} from '../src/modules/coaching/module9-member-service';
import {time,actor,tuple,submission,consentCommand,workoutSeeds} from '../test/workout-fixture';

const projectId='demo-gainpath-module13-c',host='127.0.0.1:18111',org='gainpath',member=actor.uid;
let app:App,db:Firestore,store:FirestoreStore,environment:RulesTestEnvironment;
let sourceReads=0;
const auth={uid:member,token:{email_verified:true,email:`${member}@example.invalid`,auth_time:100}};
const admin={uid:'canonical-admin',token:{email_verified:true,email:'canonical-admin@example.invalid',auth_time:100}};
const notice={policyId:'emulator-reviewed-notice',noticeVersion:'v1',contentVersion:'v1',history:{mode:'from_grant' as const}};
const fresh=async(uid:string)=>({uid,email:`${uid}@example.invalid`,emailVerified:true,disabled:false,tokensValidAfterMillis:0});
const request=(operation:string,data:Record<string,unknown>,identity=auth)=>({auth:identity,app:{appId:'emulator-verified-app'},data:{schemaVersion:1,operation,data:{schemaVersion:1,organizationId:org,...data}}});
const acceptedId=keyOf(member,submission.sessionId);
const reviewedPolicy:ReviewedAcceptedDerivationPolicy={policyVersion:'emulator-only-squat-v2-policy',organizationId:org,exerciseLabel:'Squat',
 metricBinding:{reviewId:'emulator-only-binding',acceptedSchemaVersion:2,attemptMeasure:'completed_repetitions_lower_bound',localDateOffsetMinutes:480,compatibility:{...tuple,metricSchemaVersion:1,mode:'not_applicable',scoreSupport:'scored',cameraView:'side'}},
 sample:{schemaVersion:1,revision:'emulator-only',minimumScoredSessions:3,minimumDistinctDays:3,minimumAssessedAttempts:24,minimumTrackingCoverage:.75},maximumAgeMillis:7*86400000,attentionBelow:65,need:{exercise:'squat',objective:'technique_foundations',level:'beginner'}};
const candidates:CanonicalPersonalizationCandidate[]=[{id:'guide',kind:'content',exercise:'squat',objectives:['technique_foundations'],levels:['beginner'],goals:['generalFitness'],deterministicScore:80,target:{label:'Squat tutorial',target:{kind:'content',destination:{kind:'published_routine_exercise_tutorial',organizationId:org,routineId:'routine-1',exerciseIndex:0,exerciseId:tuple.exerciseId,dayNumber:1}}}}];
const runtime:ReviewedCanonicalRuntime={reviewId:'emulator-only-reviewed-runtime',enabledTuples:[tuple],notices:[notice],
  maximumAgeMillis:7*86400000,expiresAfterMillis:86400000,cooldownMillis:3600000,
  listAcceptedIds:async(tx,organizationId,memberId)=>{sourceReads++;const rows=await db.collection(`orgs/${organizationId}/workoutSessions`).where('memberId','==',memberId).get();return rows.docs.map(d=>d.id);},
  derive:(sessions,now,profile)=>deriveReviewedAcceptedSuggestion({organizationId:org,memberId:member},sessions,now,reviewedPolicy,profile,candidates),
  resolveTarget:async(tx,organizationId,suggestion)=>{const publication=await tx.get(`orgs/${organizationId}/content/routine-1`);return publication?.status==='published'?{target:suggestion.target,label:'Squat tutorial',specialization:null,imageUrl:null,photoPath:null}:null;},
  listIds:async(tx,organizationId,memberId,afterId)=>{let q=db.collection(`orgs/${organizationId}/canonicalRecommendations`).orderBy('__name__');if(memberId)q=q.where('memberId','==',memberId);if(afterId)q=q.startAfter(afterId);return(await q.limit(25).get()).docs.map(d=>d.id);},
};
const deps=()=>({store,runtime,clock:()=>time+1000,readAuthIdentity:fresh});
const lifecycle=()=>createCanonicalRecommendationLifecycle(deps());
const accepted=()=>createAcceptedWorkoutRecommendationHandler(deps())({organizationId:org,memberId:member,acceptedId});
async function grantAll(){let revision=0;for(const purpose of ['exerciseInsights','recommendationGeneration','recommendationDelivery'])await createRecommendationConsentV2Command({store,clock:()=>time-4*86400000,readAuthIdentity:fresh,noticePolicies:[notice]})({auth,app:{appId:'emulator'},data:{schemaVersion:2,organizationId:org,commandId:`grant-${purpose}`,expectedRevision:revision++,purpose,action:'grant',noticePolicyId:notice.policyId,acceptedNoticeVersion:'v1',acceptedContentVersion:'v1'}});}
async function seed(){await environment.clearFirestore();sourceReads=0;const batch=db.batch();for(const[p,d]of Object.entries(workoutSeeds))batch.set(db.doc(p),d);
  batch.set(db.doc(`orgs/${org}`),{status:'active'});
  batch.set(db.doc(`orgs/${org}/members/${member}`),{organizationId:org,userId:member,role:'member',status:'active',branchIds:[]});
  batch.set(db.doc(`users/${admin.uid}`),{organizationId:org,role:'admin'});
  batch.set(db.doc(`orgs/${org}/members/${admin.uid}`),{organizationId:org,userId:admin.uid,role:'admin',status:'active',branchIds:[]});await batch.commit();
  await grantAll();const consent=await acknowledgeWorkoutConsent(store,actor,consentCommand,()=>time-4*86400000);
  for(let day=2;day>=0;day--) await submitWorkoutSession(store,actor,{...submission,requestId:day?'prior-upload-'+day:submission.requestId,sessionId:day?'prior-session-'+day:submission.sessionId,startedAtMillis:submission.startedAtMillis-day*86400000,endedAtMillis:submission.endedAtMillis-day*86400000,formScorePercent:45,consentAcknowledgementId:consent.acknowledgementId},{clock:()=>time,enabledTuples:[tuple]});
}
beforeAll(async()=>{if(process.env.FIRESTORE_EMULATOR_HOST!==host||process.env.GCLOUD_PROJECT!==projectId||process.env.GOOGLE_CLOUD_PROJECT!==projectId)throw Error('Dedicated loopback demo emulator required; no live fallback.');
  app=initializeApp({projectId},'canonical-recommendation-emulator');db=getFirestore(app);store=new FirestoreStore(db);
  environment=await initializeTestEnvironment({projectId,firestore:{host:'127.0.0.1',port:18111,rules:readFileSync('../firebase/firestore.rules','utf8')}});});
beforeEach(seed);
afterAll(async()=>{await environment?.cleanup();await db?.terminate();if(app)await deleteApp(app);});

it('keeps real production tuple and canonical gates disabled, with owned empty list and no synthetic fallback',async()=>{
  expect(ENABLED_WORKOUT_TUPLES).toEqual([]);expect(CANONICAL_RECOMMENDATION_RELEASE.enabled).toBe(false);
  const backend=createCanonicalRecommendationBackend({store,clock:()=>time+1000,readAuthIdentity:fresh});
  expect(await backend(request('session.access',{}))).toMatchObject({enabled:false,mode:'accepted_workout'});
  expect(await backend(request('member.recommendation.list',{history:false,afterId:null}))).toMatchObject({enabled:false,recommendations:[],nextAfterId:null});
  expect(sourceReads).toBe(0);
});
it('concurrent accepted events create one stable review, prepared crash recovers once, Member gets delivered detail',async()=>{
  const results=await Promise.all([accepted(),accepted()]);const id=results[0].id!;expect(results[1].id).toBe(id);
  expect((await db.collection(`orgs/${org}/canonicalRecommendations`).get()).size).toBe(1);
  expect(await lifecycle().member(auth,org,id,'get',null,null)).toMatchObject({state:'not_delivered',target:null});
  await lifecycle().decide(admin,org,id,1,'admin-send','send');
  expect((await db.doc(`orgs/${org}/canonicalRecommendations/${id}`).get()).data()?.status).toBe('prepared');
  const recovery=createCanonicalDeliveryRecovery(deps());expect(await recovery(org,[id])).toEqual([{id,status:'delivered'}]);
  await Promise.all([lifecycle().deliver(org,id),lifecycle().deliver(org,id)]);
  expect((await db.collection(`orgs/${org}/notifications`).get()).size).toBe(1);
  expect((await db.collection(`orgs/${org}/canonicalRecommendationDeliveries`).get()).size).toBe(1);
  const backend=createCanonicalRecommendationBackend(deps());const list=await backend(request('member.recommendation.list',{history:false,afterId:null})) as {recommendations:Record<string,unknown>[]};
  expect(list.recommendations).toHaveLength(1);expect(list.recommendations[0]).toMatchObject({mode:'accepted_workout',state:'available',kind:'content',revision:3});
  const read=await backend(request('member.recommendation.command',{recommendationId:id,action:'read',commandId:'member-read',expectedRevision:3})) as Record<string,unknown>;
  expect(read.readAtMillis).toBe(time+1000);expect(read.acknowledgedAtMillis).toBeNull();
  expect(await backend(request('member.recommendation.command',{recommendationId:id,action:'read',commandId:'member-read',expectedRevision:3}))).toEqual(read);
  const dismissed=await lifecycle().member(auth,org,id,'dismiss',4,'member-dismiss') as Record<string,unknown>;expect(dismissed.state).toBe('dismissed');
  expect(await lifecycle().member(auth,org,id,'read',3,'member-read')).toMatchObject({state:'dismissed',target:null});
});
it('rechecks current consent before every history scan and recovery, leaving revoked work private',async()=>{
  const id=(await accepted()).id!;await lifecycle().decide(admin,org,id,1,'send-before-revoke','send');sourceReads=0;
  await createRecommendationConsentV2Command(deps())({auth,app:{appId:'emulator'},data:{schemaVersion:2,organizationId:org,commandId:'revoke-generation',expectedRevision:3,purpose:'recommendationGeneration',action:'revoke'}});
  await expect(accepted()).rejects.toMatchObject({code:'failed-precondition'});
  expect(await createCanonicalDeliveryRecovery(deps())(org,[id])).toEqual([{id,status:'blocked'}]);expect(sourceReads).toBe(0);
  expect((await db.collection(`orgs/${org}/notifications`).get()).empty).toBe(true);
});
it('rejects forged provenance without the genuine acceptance receipt and rejects client Rules writes',async()=>{
  await db.doc(`orgs/${org}/commandReceipts/${keyOf('submitWorkoutSession',member,submission.requestId)}`).delete();
  await expect(accepted()).rejects.toMatchObject({code:'failed-precondition'});
  const client=environment.authenticatedContext(member,{email_verified:true}).firestore();
  await assertFails(setDoc(doc(client,`orgs/${org}/canonicalRecommendations/${'a'.repeat(64)}`),{mode:'accepted_workout',memberId:member,status:'delivered'}));
  await assertFails(getDoc(doc(client,`orgs/${org}/canonicalRecommendations/${'a'.repeat(64)}`)));
});
it('cross-member reads and obsolete target changes fail closed without delivery',async()=>{
  const id=(await accepted()).id!;
  await expect(lifecycle().decide({...admin,uid:member},org,id,1,'bad-role','send')).rejects.toMatchObject({code:'permission-denied'});
  await db.doc(`orgs/${org}/content/routine-1`).update({status:'draft'});
  await expect(lifecycle().decide(admin,org,id,1,'changed-target','send')).rejects.toMatchObject({code:'failed-precondition'});
  expect((await db.collection(`orgs/${org}/notifications`).get()).empty).toBe(true);
});
it('a notification-commit failure leaves prepared state intact and recovery handles response loss',async()=>{
  const id=(await accepted()).id!;await lifecycle().decide(admin,org,id,1,'send-before-fault','send');
  const faultStore={transact:<T>(work:(tx:import('../src/platform/firestore/store').TransactionPort)=>Promise<T>)=>store.transact(tx=>work({...tx,
    create:(p:string,data:object)=>{if(p.includes('/notifications/'))throw Error('Injected notification commit failure');tx.create(p,data);}}))};
  await expect(createCanonicalRecommendationLifecycle({...deps(),store:faultStore}).deliver(org,id)).rejects.toThrow('Injected notification');
  expect((await db.doc(`orgs/${org}/canonicalRecommendations/${id}`).get()).data()?.status).toBe('prepared');
  expect((await db.collection(`orgs/${org}/notifications`).get()).empty).toBe(true);
  await lifecycle().deliver(org,id);expect(await lifecycle().deliver(org,id)).toEqual({id,status:'delivered'});
});
it('concurrent Admin send/dismiss decisions converge to one decision, and stale revisions abort',async()=>{
  const id=(await accepted()).id!;
  const results=await Promise.allSettled([lifecycle().decide(admin,org,id,1,'concurrent-send','send'),lifecycle().decide(admin,org,id,1,'concurrent-dismiss','dismiss')]);
  expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);
  expect(results.filter(r=>r.status==='rejected')).toHaveLength(1);
  expect((await db.collection(`orgs/${org}/canonicalRecommendationCommands`).get()).size).toBe(1);
});
it('Auth/App Check, fresh identity, strict envelope and cross-organization ownership are enforced',async()=>{
  const backend=createCanonicalRecommendationBackend(deps());
  await expect(backend({...request('session.access',{}),app:undefined})).rejects.toMatchObject({code:'unauthenticated'});
  await expect(backend(request('session.access',{memberId:'other-member'}))).rejects.toMatchObject({code:'invalid-argument'});
  await expect(backend(request('session.access',{organizationId:'other-org'}))).rejects.toMatchObject({code:'permission-denied'});
  await expect(createCanonicalRecommendationBackend({...deps(),readAuthIdentity:async uid=>({...await fresh(uid),disabled:true})})(request('session.access',{}))).rejects.toMatchObject({code:'unauthenticated'});
  expect(sourceReads).toBe(0);
});

it('preserves redacted Admin history after privacy revocation and permits cleanup dismissal',async()=>{
 const id=(await accepted()).id!;
 await createRecommendationConsentV2Command(deps())({auth,app:{appId:'emulator'},data:{schemaVersion:2,organizationId:org,commandId:'revoke-history',expectedRevision:3,purpose:'recommendationGeneration',action:'revoke'}});
 sourceReads=0;expect(await lifecycle().adminDetail(admin,org,id)).toMatchObject({id,status:'withdrawn',redacted:true});expect(sourceReads).toBe(0);
 await expect(lifecycle().decide(admin,org,id,1,'blocked-send','send')).rejects.toMatchObject({code:'failed-precondition'});
 expect(await lifecycle().decide(admin,org,id,1,'cleanup-dismiss','dismiss')).toMatchObject({status:'dismissed'});
});

it('projects genuine inbox notices through current consent and hides withdrawn destinations',async()=>{
 const id=(await accepted()).id!;await lifecycle().decide(admin,org,id,1,'send-inbox','send');await lifecycle().deliver(org,id);
 const projectRecommendation=await createCanonicalNoticeProjector(deps(),request('member.recommendation.list',{history:false,afterId:null}));
 const reader={projectRecommendation,list:async()=> (await db.collection(`orgs/${org}/notifications`).get()).docs.map(d=>({id:d.id,data:d.data()}))};
 const inbox=await module9MemberCommand(store,auth,{schemaVersion:1,organizationId:org,action:'inbox'},()=>time+1000,reader);
 expect(inbox).toMatchObject({records:[{recommendation:{recommendationId:id,state:'available',kind:'content'}}]});
 await createRecommendationConsentV2Command(deps())({auth,app:{appId:'emulator'},data:{schemaVersion:2,organizationId:org,commandId:'revoke-inbox',expectedRevision:3,purpose:'recommendationDelivery',action:'revoke'}});
 sourceReads=0;expect(await module9MemberCommand(store,auth,{schemaVersion:1,organizationId:org,action:'inbox'},()=>time+1000,reader)).toMatchObject({records:[{recommendation:{state:'withdrawn',target:null}}]});expect(sourceReads).toBe(0);
});

it('never resurfaces pre-grant Admin evidence after revoke and regrant',async()=>{
 const id=(await accepted()).id!;await lifecycle().decide(admin,org,id,1,'grant-bound-send','send');await lifecycle().deliver(org,id);
 const consent=createRecommendationConsentV2Command({...deps(),noticePolicies:[notice]});
 await consent({auth,app:{appId:'emulator'},data:{schemaVersion:2,organizationId:org,commandId:'withdraw-old-grant',expectedRevision:3,purpose:'recommendationGeneration',action:'revoke'}});
 await consent({auth,app:{appId:'emulator'},data:{schemaVersion:2,organizationId:org,commandId:'new-grant',expectedRevision:4,purpose:'recommendationGeneration',action:'grant',noticePolicyId:notice.policyId,acceptedNoticeVersion:'v1',acceptedContentVersion:'v1'}});
 const detail=await lifecycle().adminDetail(admin,org,id);expect(detail).toMatchObject({status:'withdrawn',redacted:true});expect(detail).not.toHaveProperty('suggestion');
 expect(await lifecycle().member(auth,org,id,'get',null,null)).toMatchObject({state:'withdrawn',target:null});
});
it('suppresses another pending review for the same guidance need during its reviewed cooldown',async()=>{
 await accepted();const consent=(await db.doc(`orgs/${org}/workoutSessions/${acceptedId}`).get()).data()!.consentAcknowledgementId;
 await submitWorkoutSession(store,actor,{...submission,requestId:'later-upload',sessionId:'later-session',formScorePercent:44,consentAcknowledgementId:consent},{clock:()=>time,enabledTuples:[tuple]});
 const later=keyOf(member,'later-session');expect(await createAcceptedWorkoutRecommendationHandler(deps())({organizationId:org,memberId:member,acceptedId:later})).toMatchObject({status:'suppressed'});
 expect((await db.collection(`orgs/${org}/canonicalRecommendations`).get()).size).toBe(1);
});
