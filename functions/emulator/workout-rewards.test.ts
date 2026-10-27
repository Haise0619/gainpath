import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
import {createHash} from 'node:crypto';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {keyOf} from '../src/platform/idempotency';
import {workoutRewardConfiguration,workoutRewardCommand} from '../src/modules/gamification/workout-rewards';
import {seed,org,auth,adminAuth,now,path} from '../test/reward-journey-fixture';
import {initializeTestEnvironment,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc} from 'firebase/firestore';
import {readFileSync} from 'node:fs';
let app:App,db:Firestore,store:FirestoreStore;
const project='demo-gainpath-workout-rewards',hash=(v:unknown)=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const draft={requestId:'draft',baseRevision:0,points:100,dailyClaimLimit:1,minimumCompletionPercent:100,minimumVerifiedReps:5,minimumTrackedSeconds:3,eligibleRoutineIds:['routine'],difficultyPoints:{Beginner:100,Intermediate:150,Advanced:200}};
const tuple={organizationId:org,exerciseId:'squat',detectorId:'live',detectorVersion:'v1',scoringVersion:'v1',cameraView:'side'};
const admin=(action:string,fields={})=>workoutRewardConfiguration(store,adminAuth,{schemaVersion:1,organizationId:org,action,...fields},()=>now);
const member=(action:string,fields={},future=false)=>workoutRewardCommand(store,auth,{schemaVersion:1,organizationId:org,action,...fields},{clock:()=>now,physicalValidationApproved:future,enabledTuples:future?[tuple]:[]});
beforeAll(()=>{if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18088')throw Error('Local emulator required');app=initializeApp({projectId:project},'workout-rewards');db=getFirestore(app);store=new FirestoreStore(db);});
beforeEach(async()=>{await fetch(`http://127.0.0.1:18088/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});const batch=db.batch();for(const [p,v]of seed().documents)batch.set(db.doc(p),v);await batch.commit();});
afterAll(async()=>{await db?.terminate();if(app)await deleteApp(app);});
it('real transactions version only disabled draft and hardhold never writes Member points',async()=>{
 await Promise.all([admin('saveWorkoutRewardDraft',draft),admin('saveWorkoutRewardDraft',draft)]);
 const p=(await db.doc(path('workoutRewardPolicies','current')).get()).data()!;expect(p.enabled).toBe(false);expect(p.revision).toBe(1);
 expect((await member('status',{attemptId:'local',routineId:'routine',day:1})).status).toBe('disabled');
 await expect(member('claim',{attemptId:'local',expectedPolicyVersion:p.version})).rejects.toMatchObject({code:'failed-precondition'});
 expect((await db.doc(path('rewardBalances','member')).get()).data()?.points).toBe(1000);expect((await db.collection(`orgs/${org}/rewardAwards`).get()).empty).toBe(true);
});
async function evidence(attemptId:string,sessionId:string){
 const batch=db.batch();batch.set(db.doc(path('content','routine')),{schemaVersion:1,kind:'routine',status:'published',publishedAtMillis:now-10000,difficulty:'Advanced',exercises:[{dayNumber:1,exerciseId:'squat',sets:1,reps:5}]});
 batch.set(db.doc(path('verifiedRoutineAttempts',hash(['member',attemptId]))),{schemaVersion:1,organizationId:org,memberId:'member',attemptId,routineId:'routine',day:1,status:'verified_ai_completed',hasManualExercises:false,sessionIds:[sessionId],routinePublishedAtMillis:now-10000});
 batch.set(db.doc(path('workoutSessions',keyOf('member',sessionId))),{schemaVersion:2,memberId:'member',sessionId,publishedRoutineId:'routine',status:'accepted',provenance:'real_camera',repetitions:5,trackedDurationMillis:5000,rejectedDurationMillis:0,startedAtMillis:now-6000,endedAtMillis:now-1000,acceptedAtMillis:now,...tuple});await batch.commit();
}
it('explicitly injected future gate handles concurrent duplicates and different-attempt daily cap atomically',async()=>{
 await admin('saveWorkoutRewardDraft',draft);const p=(await db.doc(path('workoutRewardPolicies','current')).get()).data()!;
 await db.doc(path('workoutRewardReleases','current')).set({schemaVersion:1,organizationId:org,policyVersion:p.version,physicalValidationApproved:true,issuanceApproved:true});
 await evidence('a','one');await evidence('b','two');
 const request={attemptId:'a',expectedPolicyVersion:p.version};
 const results=await Promise.all([member('claim',request,true),member('claim',request,true)]);expect(results[0].awardId).toBe(results[1].awardId);
 await expect(member('claim',{attemptId:'b',expectedPolicyVersion:p.version},true)).rejects.toMatchObject({code:'resource-exhausted'});
 expect((await db.doc(path('rewardBalances','member')).get()).data()?.points).toBe(1100);expect((await db.collection(`orgs/${org}/rewardAwards`).get()).size).toBe(1);
 expect((await db.collection(`orgs/${org}/workoutRewardSessionClaims`).get()).size).toBe(1);
 expect((await db.doc(path('workoutRewardPolicies','current')).get()).data()?.enabled).toBe(false);
});
it('existing Rules deny client-written policies, releases, accepted attempt receipts and reward caps',async()=>{
 const env=await initializeTestEnvironment({projectId:project,firestore:{host:'127.0.0.1',port:18088,rules:readFileSync('../firebase/firestore.rules','utf8')}});
 try{for(const uid of ['member','admin']){const client=env.authenticatedContext(uid,{email_verified:true}).firestore();for(const collection of ['workoutRewardPolicies','workoutRewardReleases','verifiedRoutineAttempts','workoutRewardDailyClaims','workoutRewardSessionClaims'])await assertFails(setDoc(doc(client,path(collection,'forged')),{schemaVersion:1,organizationId:org,memberId:uid,enabled:true}));}}finally{await env.cleanup();}
});
