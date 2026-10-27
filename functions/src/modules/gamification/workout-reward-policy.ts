import {InputValidationError} from '../../platform/validation';
import type {DocumentData} from '../../platform/firestore/store';
const levels=['Beginner','Intermediate','Advanced'];
export const DRAFT_WORKOUT_POLICY_VERSION='workout-draft-unconfigured';
export const WORKOUT_REWARD_PHYSICAL_RELEASE_APPROVED=false;
export function defaultWorkoutRewardDraft(){return {schemaVersion:1,revision:0,version:DRAFT_WORKOUT_POLICY_VERSION,enabled:false,difficultyMultipliersEnabled:false,eligibilityMode:'verified_ai_only',timezone:'Asia/Kuala_Lumpur',points:100,dailyClaimLimit:1,minimumCompletionPercent:100,minimumVerifiedReps:1,minimumTrackedSeconds:1,eligibleRoutineIds:[] as string[],difficultyPoints:{Beginner:100,Intermediate:100,Advanced:100}};}
export function validateWorkoutRewardFields(d:DocumentData){
 const integer=(v:unknown,min:number,max:number)=>Number.isSafeInteger(v)&&Number(v)>=min&&Number(v)<=max;
 const ids=d.eligibleRoutineIds,values=d.difficultyPoints;
 if(!integer(d.points,1,100000)||!integer(d.dailyClaimLimit,1,10)||!integer(d.minimumCompletionPercent,1,100)||!integer(d.minimumVerifiedReps,1,10000)||!integer(d.minimumTrackedSeconds,1,86400)||!Array.isArray(ids)||ids.length>100||new Set(ids).size!==ids.length||ids.some(v=>typeof v!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(v))||!values||typeof values!=='object'||Array.isArray(values)||Object.keys(values).length!==3||levels.some(k=>!integer((values as DocumentData)[k],1,100000)))throw new InputValidationError('Enter valid draft points, daily limit, verified requirements and routine IDs.');
 return {points:Number(d.points),dailyClaimLimit:Number(d.dailyClaimLimit),minimumCompletionPercent:Number(d.minimumCompletionPercent),minimumVerifiedReps:Number(d.minimumVerifiedReps),minimumTrackedSeconds:Number(d.minimumTrackedSeconds),eligibleRoutineIds:ids as string[],difficultyPoints:values as Record<string,number>};
}
export function parseWorkoutRewardPolicy(raw:DocumentData|undefined,org:string){
 if(!raw)return defaultWorkoutRewardDraft();
 if(raw.schemaVersion!==1||raw.organizationId!==org||!Number.isSafeInteger(raw.revision)||Number(raw.revision)<1||typeof raw.version!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(raw.version)||raw.enabled!==false||raw.difficultyMultipliersEnabled!==false||raw.eligibilityMode!=='verified_ai_only'||raw.timezone!=='Asia/Kuala_Lumpur')throw new InputValidationError('Disabled workout policy is invalid.');
 return {...defaultWorkoutRewardDraft(),...validateWorkoutRewardFields(raw),revision:Number(raw.revision),version:raw.version};
}
