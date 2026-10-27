import type {DocumentData} from '../../platform/firestore/store';
import type {WorkoutModelTuple} from '../workouts/workout-service';
export interface RoutineRewardPolicy {enabled:boolean;points:number;dailyPointsCap:number;minimumCompletionPercent?:number}
export type RoutineRewardEligibility={status:'disabled'|'unverified'|'incomplete'}|{status:'eligible';points:number;sessionIds:string[]};
/** Pure preparation seam only. No producer/export enables points, no client
 * summary is accepted here and the production tuple allowlist remains empty. */
export function routineRewardEligibility(input:{organizationId:string;memberId:string;routineId:string;day:number;routine:DocumentData|undefined;sessions:DocumentData[];now:number;enabledTuples:readonly WorkoutModelTuple[];policy:RoutineRewardPolicy|null}):RoutineRewardEligibility {
 const {policy,routine,sessions,organizationId,memberId,routineId,day,now,enabledTuples}=input;
 if(!policy?.enabled)return {status:'disabled'};
 const integer=(v:unknown,min=0,max=Number.MAX_SAFE_INTEGER):v is number=>Number.isSafeInteger(v)&&Number(v)>=min&&Number(v)<=max;
 const identifier=(v:unknown):v is string=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(v);
 if(!identifier(organizationId)||!identifier(memberId)||!identifier(routineId)||!integer(day,1,14)||!integer(now,1)||!integer(policy.points,1)||!integer(policy.dailyPointsCap,policy.points)||!routine||routine.schemaVersion!==1||routine.kind!=='routine'||routine.status!=='published'||!Array.isArray(routine.exercises)||!routine.exercises.length||routine.exercises.length>50||sessions.length>200)return {status:'unverified'};
 const targets=routine.exercises.filter(e=>e&&typeof e==='object'&&e.dayNumber===day) as DocumentData[];
 if(!targets.length||targets.some(e=>!identifier(e.exerciseId)||!integer(e.sets,1,50)||!integer(e.reps,1,100)))return {status:'unverified'};
 // Until each accepted session carries a trusted routine-entry index, repeated
 // exercise IDs within a day cannot be attributed to distinct targets safely.
 if(new Set(targets.map(e=>e.exerciseId)).size!==targets.length)return {status:'unverified'};
 const ids=new Set<string>(),reps=new Map<string,number>(),ordered=[...sessions].sort((a,b)=>Number(a.startedAtMillis)-Number(b.startedAtMillis));
 let ended=0;
 for(const s of ordered){
  if(!identifier(s.sessionId)||ids.has(s.sessionId)||s.schemaVersion!==2||s.status!=='accepted'||s.organizationId!==organizationId||s.memberId!==memberId||s.publishedRoutineId!==routineId||s.provenance!=='real_camera'||!targets.some(e=>e.exerciseId===s.exerciseId)||!integer(s.repetitions,1,10000)||!integer(s.startedAtMillis,1)||!integer(s.endedAtMillis,Number(s.startedAtMillis)+1,now)||!integer(s.acceptedAtMillis,Number(s.endedAtMillis),now)||!integer(s.trackedDurationMillis,1,86400000)||s.trackedDurationMillis>Number(s.endedAtMillis)-Number(s.startedAtMillis)||s.repetitions*600>s.trackedDurationMillis||Number(s.startedAtMillis)<ended||!enabledTuples.some(t=>t.organizationId===organizationId&&t.exerciseId===s.exerciseId&&t.detectorId===s.detectorId&&t.detectorVersion===s.detectorVersion&&t.scoringVersion===s.scoringVersion&&t.cameraView===s.cameraView))return {status:'unverified'};
  ids.add(s.sessionId);ended=Number(s.endedAtMillis);reps.set(String(s.exerciseId),(reps.get(String(s.exerciseId))??0)+s.repetitions);
 }
 const percent=policy.minimumCompletionPercent??100;
 if(!integer(percent,1,100))return {status:'unverified'};
 if(targets.some(e=>(reps.get(String(e.exerciseId))??0)<Math.ceil(Number(e.sets)*Number(e.reps)*percent/100)))return {status:'incomplete'};
 return {status:'eligible',points:policy.points,sessionIds:[...ids].sort()};
}
