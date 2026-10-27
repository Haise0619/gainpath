import {beforeEach,expect,it} from 'vitest';
import {workoutRewardConfiguration,workoutRewardCommand,defaultWorkoutRewardDraft} from '../src/modules/gamification/workout-rewards';
import {seed,org,auth,adminAuth,now,path} from './reward-journey-fixture';
import {createHash} from 'node:crypto';
import {keyOf} from '../src/platform/idempotency';
import {buildPointsHistory} from '../src/modules/gamification/points-history';
let store:ReturnType<typeof seed>;
const admin=(action:string,fields={})=>workoutRewardConfiguration(store,adminAuth,{schemaVersion:1,organizationId:org,action,...fields},()=>now);
const member=(action:string,fields={},options={})=>workoutRewardCommand(store,auth,{schemaVersion:1,organizationId:org,action,...fields},{clock:()=>now,...options});
const fields={requestId:'save',baseRevision:0,points:100,dailyClaimLimit:1,minimumCompletionPercent:100,minimumVerifiedReps:5,minimumTrackedSeconds:3,eligibleRoutineIds:['routine'],difficultyPoints:{Beginner:100,Intermediate:150,Advanced:200}};
beforeEach(()=>{store=seed();});
it('unconfigured defaults are draft100/day1, AI-only, no multipliers or writes',async()=>{
 const before=JSON.stringify([...store.documents]);expect((await admin('workoutRewardOverview')).draft).toMatchObject({points:100,dailyClaimLimit:1,enabled:false,difficultyMultipliersEnabled:false,eligibilityMode:'verified_ai_only'});expect(defaultWorkoutRewardDraft().points).toBe(100);expect(JSON.stringify([...store.documents])).toBe(before);
});
it('Admin saves only a disabled versioned draft; retries once and stale revisions abort',async()=>{
 await admin('saveWorkoutRewardDraft',fields);await admin('saveWorkoutRewardDraft',fields);
 const first=store.documents.get(path('workoutRewardPolicies','current'))!;expect(first).toMatchObject({revision:1,enabled:false,difficultyMultipliersEnabled:false,points:100});
 expect([...store.documents.keys()].filter(k=>k.includes('/versions/'))).toHaveLength(1);
 await admin('saveWorkoutRewardDraft',{...fields,requestId:'edit',baseRevision:1,points:120});expect(store.documents.get(path('workoutRewardPolicies','current'))).toMatchObject({revision:2,points:120});
 await expect(admin('saveWorkoutRewardDraft',{...fields,requestId:'stale'})).rejects.toMatchObject({code:'aborted'});
 expect(store.documents.has(path('rewardPolicies','current'))).toBe(false);
});
it('forbids activation fields, invalid config and unauthorized role without writes',async()=>{
 for(const patch of [{enabled:true},{points:0},{dailyClaimLimit:0},{minimumCompletionPercent:101},{eligibleRoutineIds:['routine','routine']},{difficultyPoints:{Beginner:100}}])await expect(admin('saveWorkoutRewardDraft',{...fields,...patch})).rejects.toThrow();
 await expect(workoutRewardConfiguration(store,auth,{schemaVersion:1,organizationId:org,action:'saveWorkoutRewardDraft',...fields},()=>now)).rejects.toMatchObject({code:'permission-denied'});
 expect(store.documents.has(path('workoutRewardPolicies','current'))).toBe(false);
});
it('production hold wins over any persisted enabled policy and accepted-looking attempt',async()=>{
 await admin('saveWorkoutRewardDraft',fields);
 store.documents.set(path('workoutRewardPolicies','current'),{...store.documents.get(path('workoutRewardPolicies','current')),enabled:true});
 const before=store.documents.get(path('rewardBalances','member'))?.points;
 expect(await member('status',{attemptId:'attempt',routineId:'routine',day:1})).toMatchObject({status:'disabled',reason:'physical_validation_required'});
 await expect(member('claim',{attemptId:'attempt',expectedPolicyVersion:'anything'})).rejects.toMatchObject({code:'failed-precondition'});
 expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(before);
});
it('manual and provisional completion have no trusted attempt evidence',async()=>{
 await admin('saveWorkoutRewardDraft',fields);
 await expect(member('claim',{attemptId:'local-only',expectedPolicyVersion:'draft'}, {physicalValidationApproved:true})).rejects.toThrow();
 expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(1000);
});
const digest=(v:unknown)=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const tuple={organizationId:org,exerciseId:'squat',detectorId:'live',detectorVersion:'v1',scoringVersion:'v1',cameraView:'side'};
async function accepted(attemptId='attempt',sessionId='capture'){
 if(!store.documents.has(path('workoutRewardPolicies','current')))await admin('saveWorkoutRewardDraft',fields);
 const p=store.documents.get(path('workoutRewardPolicies','current'))!;
 store.documents.set(path('workoutRewardReleases','current'),{schemaVersion:1,organizationId:org,policyVersion:p.version,physicalValidationApproved:true,issuanceApproved:true});
 store.documents.set(path('content','routine'),{schemaVersion:1,kind:'routine',status:'published',publishedAtMillis:now-10000,difficulty:'Advanced',exercises:[{dayNumber:1,exerciseId:'squat',sets:1,reps:5}]});
 store.documents.set(path('verifiedRoutineAttempts',digest(['member',attemptId])),{schemaVersion:1,organizationId:org,memberId:'member',attemptId,routineId:'routine',day:1,status:'verified_ai_completed',hasManualExercises:false,sessionIds:[sessionId],routinePublishedAtMillis:now-10000});
 store.documents.set(path('workoutSessions',keyOf('member',sessionId)),{schemaVersion:2,memberId:'member',sessionId,publishedRoutineId:'routine',status:'accepted',provenance:'real_camera',repetitions:5,trackedDurationMillis:5000,rejectedDurationMillis:0,startedAtMillis:now-6000,endedAtMillis:now-1000,acceptedAtMillis:now,...tuple});
 return {attemptId,expectedPolicyVersion:p.version};
}
const futureGate={physicalValidationApproved:true,enabledTuples:[tuple]};
it('future injected release atomically credits once per attempt and records unchanged base points despite advanced difficulty',async()=>{
 const request=await accepted();const [a,b]=await Promise.all([member('claim',request,futureGate),member('claim',request,futureGate)]);
 expect(a.awardId).toBe(b.awardId);expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(1100);
 const awards=[...store.documents].filter(([k])=>k.includes('/rewardAwards/'));expect(awards).toHaveLength(1);
 expect(awards[0][1]).toMatchObject({points:100,premiumBonus:false,routineDifficulty:'Advanced',difficultyMultipliersEnabled:false,policyVersion:request.expectedPolicyVersion});
 expect(awards[0][1].policySnapshot).toMatchObject({points:100,enabled:false});
 expect(buildPointsHistory(org,'member',1100,now,{claims:[],adjustments:[],redemptions:[],awards:[{id:awards[0][1].awardId as string,data:awards[0][1]}]}).entries[0].points).toBe(100);
});
it('future daily cap covers different attempts and all policy versions, while used sessions cannot earn twice',async()=>{
 const first=await accepted();await member('claim',first,futureGate);
 await expect(member('claim',await accepted('second','second-capture'),futureGate)).rejects.toMatchObject({code:'resource-exhausted'});
 await expect(member('claim',await accepted('reused','capture'),futureGate)).rejects.toMatchObject({code:'failed-precondition'});
 expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(1100);
});
it('future claims reject mixed/manual attempts, provisional evidence, stale policy and prescribed requirements',async()=>{
 const request=await accepted(),evidencePath=path('verifiedRoutineAttempts',digest(['member','attempt']));
 store.documents.set(evidencePath,{...store.documents.get(evidencePath),hasManualExercises:true});await expect(member('claim',request,futureGate)).rejects.toThrow();
 await accepted();store.documents.set(path('workoutSessions',keyOf('member','capture')),{...store.documents.get(path('workoutSessions',keyOf('member','capture'))),status:'provisional'});await expect(member('claim',request,futureGate)).rejects.toThrow();
 await accepted();await expect(member('claim',{...request,expectedPolicyVersion:'old'},futureGate)).rejects.toMatchObject({code:'aborted'});
 store.documents.set(path('workoutSessions',keyOf('member','capture')),{...store.documents.get(path('workoutSessions',keyOf('member','capture'))),repetitions:1});await expect(member('claim',request,futureGate)).rejects.toThrow();
 expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(1000);
});
it('confirmed claims recover after policy changes or a hold without another credit',async()=>{
 const request=await accepted();await member('claim',request,futureGate);
 store.documents.set(path('workoutRewardPolicies','current'),{invalid:true});
 expect(await member('claim',request)).toMatchObject({status:'already_awarded',draftPoints:100});
 expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(1100);
});
it('future daily counters reset only by Malaysia calendar day and never reset for a policy edit',async()=>{
 const first=await accepted();await member('claim',first,futureGate);
 const next=await accepted('next-day','next-capture'),nextNow=now+86400000;
 const sessionPath=path('workoutSessions',keyOf('member','next-capture'));
 store.documents.set(sessionPath,{...store.documents.get(sessionPath),startedAtMillis:nextNow-6000,endedAtMillis:nextNow-1000,acceptedAtMillis:nextNow});
 expect(await member('claim',next,{...futureGate,clock:()=>nextNow})).toMatchObject({status:'awarded',draftPoints:100});
 expect([...store.documents.keys()].filter(p=>p.includes('/workoutRewardDailyClaims/'))).toHaveLength(2);
 await admin('saveWorkoutRewardDraft',{...fields,requestId:'new-version',baseRevision:1});
 const third=await accepted('new-version-attempt','third-capture');
 store.documents.set(path('workoutSessions',keyOf('member','third-capture')),{...store.documents.get(path('workoutSessions',keyOf('member','third-capture'))),startedAtMillis:nextNow-6000,endedAtMillis:nextNow-1000,acceptedAtMillis:nextNow});
 await expect(member('claim',third,{...futureGate,clock:()=>nextNow})).rejects.toMatchObject({code:'resource-exhausted'});
});
