import {expect,it} from 'vitest';
import {claimAiWorkoutPoints} from '../src/modules/gamification/ai-workout-points';
import {auth, now, org, path, seed} from './reward-journey-fixture';
import {keyOf} from '../src/platform/idempotency';

const exerciseId = 'F3b8xIr8ynBDd3gEICKX';
function fixture() {
  const store = seed();
  const row = {exerciseId,dayNumber:1,sets:3,reps:8};
  const routine = {kind:'routine',status:'published',exercises:[row]};
  store.documents.set(path('content','routine'),routine);
  store.documents.set(path('exerciseVideos',exerciseId),{isActive:true});
  const save = (kind: string, id: string, data: object) => {
    const key = kind+'-'+id;
    store.documents.set(path('members',auth.uid)+'/workoutBackups/'+key,{
      schemaVersion:1,classification:'provisional_member_backup',kind,id,key,
      payloadJson:JSON.stringify({organizationId:org,userId:auth.uid,...data}),
    });
  };
  const start = now-90000, end = now-1000;
  const session = {sessionId:'cam',provenance:'realCamera',exerciseId,repetitions:24,
    startedAt:new Date(start).toISOString(),endedAt:new Date(end).toISOString(),
    poseMetrics:{publishedRoutineId:'routine'}};
  save('session','cam',session);
  const attempt = {finished:true,startedAtMicros:start*1000,finishedAtMicros:end*1000,
    routine,entries:[{index:0,status:'completed',manualSets:0,sessionIds:['cam']}]};
  const saveRoutine = (id: string, override = attempt) =>
    save('routine',id,{routineId:'routine',day:1,finished:true,attempt:override});
  saveRoutine('attempt');
  const claim = (attemptId = 'attempt', actor = auth) => claimAiWorkoutPoints(store,actor,
    {schemaVersion:1,action:'claimAiWorkoutPoints',organizationId:org,attemptId},()=>now);
  const balance = () => store.documents.get(path('rewardBalances',auth.uid))?.points;
  return {store,save,saveRoutine,attempt,session,claim,balance};
}

it('awards ten points once despite parallel claims and copied routine results',async()=>{
  const f = fixture();
  const outcomes = await Promise.all([f.claim(),f.claim()]);
  expect(outcomes.map(r=>r.earned).sort((a,b)=>a-b)).toEqual([0,10]);
  expect(outcomes.map(r=>r.confirmed)).toEqual([10,10]);
  f.saveRoutine('another');
  expect(await f.claim('another')).toMatchObject({earned:0});
  expect(await f.claim('attempt',{...auth,uid:'other'})).toMatchObject({earned:0});
  expect(f.balance()).toBe(1010);
});

it('skips manual, incomplete, and under-target records',async()=>{
  const f = fixture();
  for (const status of ['selfReportedCompleted','skipped','partial']) {
    f.saveRoutine('attempt',{...f.attempt,entries:[{...f.attempt.entries[0],status}]});
    expect(await f.claim()).toMatchObject({earned:0});
  }
  f.saveRoutine('attempt');
  f.save('session','cam',{...f.session,repetitions:23});
  expect(await f.claim()).toMatchObject({earned:0});
  expect(f.balance()).toBe(1000);
});

it('counts each completed AI exercise and adds them to existing video earnings', async () => {
  const f = fixture();
  const [first] = f.attempt.routine.exercises;
  const second = {...first, exerciseId:'standing-calf-raise-side-v1'};
  const skipped = {...first, exerciseId:'dumbbell-shoulder-press-front-v1'};
  const mixed = {...f.attempt.routine,exercises:[first,second,skipped]};
  f.store.documents.set(path('content','routine'),mixed);
  f.store.documents.set(path('exerciseVideos',second.exerciseId),{isActive:true});
  f.save('session','second',{...f.session,sessionId:'second',exerciseId:second.exerciseId});
  f.saveRoutine('attempt',{...f.attempt,routine:mixed,entries:[
    f.attempt.entries[0],
    {index:1,status:'completed',manualSets:0,sessionIds:['second']},
    {index:2,status:'skipped',manualSets:0,sessionIds:[]},
  ]});
  const date = new Date(now+28800000).toISOString().slice(0,10);
  const awardId = 'workout_day_'+keyOf(auth.uid,date);
  const daily = path('rewardAwards',awardId);
  f.store.documents.set(daily,{schemaVersion:1,organizationId:org,memberId:auth.uid,
    awardId,date,policyVersion:'workout-exercise-points-v1',points:5,basePoints:5,premiumBonus:false});
  expect(await f.claim()).toMatchObject({earned:20,confirmed:20});
  expect(f.balance()).toBe(1020);
  expect(f.store.documents.get(daily)?.points).toBe(25);
});
