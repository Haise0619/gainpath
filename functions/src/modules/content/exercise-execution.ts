import {DomainError} from '../../platform/errors';
import type {DocumentData} from '../../platform/firestore/store';
/** Exact mirror of ExerciseTrackingRegistry; organization is part of identity. */
export const AI_EXERCISE_IDS = Object.freeze(['standing-lateral-raise-front-v1','bodyweight-reverse-lunge-side-v1','dumbbell-shoulder-press-front-v1','F3b8xIr8ynBDd3gEICKX','standing-single-arm-curl-side-v1','standing-calf-raise-side-v1','wall-push-up-side-v1','standard-floor-push-up-side-v1','single-arm-dumbbell-row-side-v1']);
export type ExerciseExecutionMode = 'aiTracked'|'videoGuidedTimed'|'legacyManual';
export type ExercisePrescription = {executionMode:'videoGuidedTimed';sets:number;durationSeconds:number;restSeconds:number}|{executionMode:'aiTracked'|'legacyManual';sets:number;reps:number;restSeconds:number};
const invalid=()=>new DomainError('failed-precondition','Exercise execution prescription is invalid.');
export function resolveExerciseExecution(org:string,id:string,data:DocumentData):ExerciseExecutionMode {
 const registered=org==='gainpath'&&AI_EXERCISE_IDS.includes(id), mode=data.executionMode;
 if(registered){if(mode!==undefined&&mode!=='aiTracked')throw invalid();return 'aiTracked';}
 if(mode==='aiTracked')throw invalid();
 if(mode===undefined||mode==='legacyManual')return 'legacyManual';
 if(mode==='videoGuidedTimed')return mode;
 throw invalid();
}
export function parseExercisePrescription(data:DocumentData):ExercisePrescription {
 const {executionMode,sets,restSeconds}=data;
 const integer=(v:unknown,min:number,max:number)=>Number.isSafeInteger(v)&&Number(v)>=min&&Number(v)<=max;
 if(!integer(sets,1,50)||!integer(restSeconds,0,600))throw invalid();
 if(executionMode==='videoGuidedTimed'){
  if('reps' in data||!integer(data.durationSeconds,1,3600)||Number(sets)*Number(data.durationSeconds)+(Number(sets)-1)*Number(restSeconds)>86400)throw invalid();
  return {executionMode,sets:Number(sets),durationSeconds:Number(data.durationSeconds),restSeconds:Number(restSeconds)};
 }
 if(!['aiTracked','legacyManual'].includes(String(executionMode))||'durationSeconds' in data||!integer(data.reps,1,100))throw invalid();
 return {executionMode:executionMode as 'aiTracked'|'legacyManual',sets:Number(sets),reps:Number(data.reps),restSeconds:Number(restSeconds)};
}
export function catalogDefaults(org:string,id:string,data:DocumentData):ExercisePrescription {
 const mode=resolveExerciseExecution(org,id,data), defaults=data.workoutDefaults;
 if(!defaults||typeof defaults!=='object'||Array.isArray(defaults))throw invalid();
 const d=defaults as DocumentData;
 if(Object.keys(d).some(k=>!['sets','reps','durationSeconds','restSeconds'].includes(k)))throw invalid();
 return parseExercisePrescription({...d,executionMode:mode});
}
