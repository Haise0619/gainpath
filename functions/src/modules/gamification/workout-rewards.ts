import {createHash} from 'node:crypto';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {InputValidationError,requiredIdentifier} from '../../platform/validation';
import {readAll,type DocumentData,type DocumentStore} from '../../platform/firestore/store';
import {resolveMembershipEntitlement} from '../commerce/membership-entitlement';
import {ENABLED_WORKOUT_TUPLES,type WorkoutModelTuple} from '../workouts/workout-service';
import {keyOf} from '../../platform/idempotency';
import {authorizeRewardsAdmin} from './verified-rewards-service';
import {defaultWorkoutRewardDraft,parseWorkoutRewardPolicy,validateWorkoutRewardFields,WORKOUT_REWARD_PHYSICAL_RELEASE_APPROVED} from './workout-reward-policy';
import {routineRewardEligibility} from './routine-reward-eligibility';
export {defaultWorkoutRewardDraft} from './workout-reward-policy';
type Auth={uid:string;token:Record<string,unknown>}|undefined;
const hash=(v:unknown)=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const integer=(v:unknown,min=0,max=Number.MAX_SAFE_INTEGER):v is number=>Number.isSafeInteger(v)&&Number(v)>=min&&Number(v)<=max;
const fail=(reason='Workout rewards are disabled pending physical validation.')=>new DomainError('failed-precondition',reason);
function input(raw:unknown,actions:Record<string,string[]>){
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new InputValidationError('Workout reward request required.');
 const d=raw as DocumentData,action=String(d.action),keys=['schemaVersion','organizationId','action',...(actions[action]??[])];
 if(d.schemaVersion!==1||!Object.hasOwn(actions,action)||Object.keys(d).length!==keys.length||Object.keys(d).some(k=>!keys.includes(k)))throw new InputValidationError('Invalid workout reward fields.');
 requiredIdentifier(d.organizationId,'organizationId');return d;
}
export async function workoutRewardConfiguration(store:DocumentStore,auth:Auth,raw:unknown,clock:()=>number=Date.now){
 requireVerifiedEmail(auth);
 const d=input(raw,{workoutRewardOverview:[],saveWorkoutRewardDraft:['requestId','baseRevision','points','dailyClaimLimit','minimumCompletionPercent','minimumVerifiedReps','minimumTrackedSeconds','eligibleRoutineIds','difficultyPoints']}),org=String(d.organizationId),uid=auth!.uid;
 if(d.action==='saveWorkoutRewardDraft'){requiredIdentifier(d.requestId,'requestId');if(!integer(d.baseRevision))throw new InputValidationError('Invalid draft revision.');validateWorkoutRewardFields(d);}
 return store.transact(async tx=>{
  await authorizeRewardsAdmin(tx,auth!,org);const now=clock();if(!integer(now,1))throw fail('Invalid server time.');
  const policyPath=`orgs/${org}/workoutRewardPolicies/current`,opPath=`orgs/${org}/workoutRewardConfigurationOperations/${hash([uid,d.requestId])}`,fingerprint=hash(Object.keys(d).sort().map(k=>[k,d[k]]));
  if(d.action==='saveWorkoutRewardDraft'){const prior=await tx.get(opPath);if(prior){if(prior.fingerprint!==fingerprint||prior.adminId!==uid||prior.organizationId!==org)throw new DomainError('already-exists','Request used for different draft.');return {schemaVersion:1,organizationId:org,confirmed:true};}}
  const current=parseWorkoutRewardPolicy(await tx.get(policyPath),org);
  if(d.action==='workoutRewardOverview')return {schemaVersion:1,organizationId:org,draft:current,hold:true};
  if(current.revision!==d.baseRevision)throw new DomainError('aborted','Draft changed. Reload before editing.');
  const version='workout-draft-'+hash([uid,d.requestId]),draft={...defaultWorkoutRewardDraft(),...validateWorkoutRewardFields(d),organizationId:org,revision:current.revision+1,version,updatedBy:uid,updatedAtMillis:now};
  tx.set(policyPath,draft);tx.create(`${policyPath}/versions/${version}`,draft);tx.create(opPath,{schemaVersion:1,organizationId:org,adminId:uid,fingerprint,version,requestId:d.requestId,confirmedAtMillis:now});return {schemaVersion:1,organizationId:org,confirmed:true};
 });
}
/** No runtime/env/request flag opens physical release; only dependency-injected
 * tests can exercise the future claim transaction while the deployed wrapper
 * always supplies the false source constant and the existing empty tuple list. */
export async function workoutRewardCommand(store:DocumentStore,auth:Auth,raw:unknown,options:{clock?:()=>number;physicalValidationApproved?:boolean;enabledTuples?:readonly WorkoutModelTuple[]}={}){
 requireVerifiedEmail(auth);const d=input(raw,{status:['attemptId','routineId','day'],claim:['attemptId','expectedPolicyVersion']}),org=String(d.organizationId),uid=auth!.uid,attemptId=requiredIdentifier(d.attemptId,'attemptId');
 if(d.action==='status'){requiredIdentifier(d.routineId,'routineId');if(!integer(d.day,1,14))throw new InputValidationError('Invalid routine day.');}else requiredIdentifier(d.expectedPolicyVersion,'expectedPolicyVersion');
 return store.transact(async tx=>{
  const now=(options.clock??Date.now)();if(!integer(now,1,8640000000000000))throw fail('Invalid server time.');
  await resolveMembershipEntitlement(tx,auth,org,now);const member=await tx.get(`orgs/${org}/members/${uid}`);if(member?.role!=='member')throw new DomainError('permission-denied','Active Member required.');
  const awardId='workout_'+hash([uid,attemptId]),awardPath=`orgs/${org}/rewardAwards/${awardId}`,prior=await tx.get(awardPath);
  if(prior){if(prior.schemaVersion!==1||prior.organizationId!==org||prior.memberId!==uid||prior.attemptId!==attemptId||prior.awardId!==awardId||prior.sourceId!=='routine_completion'||!integer(prior.points,1)||prior.premiumBonus!==false||prior.points!==prior.basePoints||typeof prior.policyVersion!=='string'||(d.action==='status'&&(prior.routineId!==d.routineId||prior.day!==d.day)))throw fail('Inconsistent reward receipt.');return {schemaVersion:1,organizationId:org,memberId:uid,status:'already_awarded',reason:'confirmed_receipt',policyVersion:prior.policyVersion,draftPoints:prior.points,awardId};}
  const rawPolicy=await tx.get(`orgs/${org}/workoutRewardPolicies/current`);
  const opened=options.physicalValidationApproved??WORKOUT_REWARD_PHYSICAL_RELEASE_APPROVED;
  if(!opened){if(d.action==='claim')throw fail();return {schemaVersion:1,organizationId:org,memberId:uid,status:'disabled',reason:'physical_validation_required',policyVersion:typeof rawPolicy?.version==='string'?rawPolicy.version:'draft-unconfigured',draftPoints:integer(rawPolicy?.points,1)?rawPolicy.points:100};}
  // Even future trusted release must explicitly promote an immutable draft;
  // Admin draft-save never sets this separate approval record.
  const release=await tx.get(`orgs/${org}/workoutRewardReleases/current`),policy=parseWorkoutRewardPolicy(rawPolicy,org);
  if(!release||release.schemaVersion!==1||release.organizationId!==org||release.policyVersion!==policy.version||release.physicalValidationApproved!==true||release.issuanceApproved!==true)throw fail('No approved workout reward release.');
  if(d.action==='claim'&&d.expectedPolicyVersion!==policy.version)throw new DomainError('aborted','Reward policy changed. Refresh before claiming.');
  const evidence=await tx.get(`orgs/${org}/verifiedRoutineAttempts/${hash([uid,attemptId])}`);
  if(!evidence||evidence.schemaVersion!==1||evidence.organizationId!==org||evidence.memberId!==uid||evidence.attemptId!==attemptId||evidence.status!=='verified_ai_completed'||evidence.hasManualExercises!==false||!integer(evidence.day,1,14)||typeof evidence.routineId!=='string'||!policy.eligibleRoutineIds.includes(evidence.routineId)||!Array.isArray(evidence.sessionIds)||!evidence.sessionIds.length||evidence.sessionIds.length>200||new Set(evidence.sessionIds).size!==evidence.sessionIds.length||evidence.sessionIds.some(v=>typeof v!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(v)))throw fail('A trusted AI-only completed routine attempt is required.');
  if(d.action==='status'&&(evidence.routineId!==d.routineId||evidence.day!==d.day))throw fail('Routine attempt does not match.');
  const routine=await tx.get(`orgs/${org}/content/${evidence.routineId}`);
  if(routine?.publishedAtMillis!==evidence.routinePublishedAtMillis)throw fail('Published routine changed.');
  const sessionIds=evidence.sessionIds as string[],sessions=await readAll(tx,sessionIds.map(id=>`orgs/${org}/workoutSessions/${keyOf(uid,id)}`));
  if(sessions.some((s,i)=>!s||s.sessionId!==sessionIds[i]))throw fail('Accepted sessions are missing or mismatched.');
  const eligible=routineRewardEligibility({organizationId:org,memberId:uid,routineId:evidence.routineId,day:evidence.day,routine,sessions:sessions as DocumentData[],now,enabledTuples:options.enabledTuples??ENABLED_WORKOUT_TUPLES,policy:{enabled:true,points:policy.points,dailyPointsCap:policy.points*policy.dailyClaimLimit,minimumCompletionPercent:policy.minimumCompletionPercent}});
  const reps=sessions.reduce((n,s)=>n+Number(s!.repetitions),0),tracked=sessions.reduce((n,s)=>n+Number(s!.trackedDurationMillis),0);
  const date=(at:number)=>new Date(at+8*3600000).toISOString().slice(0,10),today=date(now);
  if(eligible.status!=='eligible'||reps<policy.minimumVerifiedReps||tracked<policy.minimumTrackedSeconds*1000||sessions.some(s=>date(Number(s!.endedAtMillis))!==today))throw fail('Verified completion requirements are not met.');
  if(d.action==='status')return {schemaVersion:1,organizationId:org,memberId:uid,status:'not_eligible',reason:'issuance_disabled_in_draft',policyVersion:policy.version,draftPoints:policy.points};
  const dailyPath=`orgs/${org}/workoutRewardDailyClaims/${hash([uid,today])}`,daily=await tx.get(dailyPath),balancePath=`orgs/${org}/rewardBalances/${uid}`,balance=await tx.get(balancePath);
  const used=await readAll(tx,sessionIds.map(id=>`orgs/${org}/workoutRewardSessionClaims/${hash([uid,id])}`));if(used.some(Boolean))throw fail('Workout evidence already rewarded.');
  if(daily&&(daily.schemaVersion!==1||daily.organizationId!==org||daily.memberId!==uid||daily.date!==today||!integer(daily.count)||!integer(daily.points)))throw fail('Invalid daily reward record.');
  if(Number(daily?.count??0)>=policy.dailyClaimLimit)throw new DomainError('resource-exhausted','Malaysia daily workout claim limit reached.');
  if(balance&&(balance.schemaVersion!==1||balance.organizationId!==org||balance.memberId!==uid||!integer(balance.points)||!Array.isArray(balance.recentRedemptionIds)))throw fail('Invalid reward balance.');
  const total=Number(balance?.points??0)+policy.points;if(!integer(total))throw fail('Balance overflow.');
  if(!integer(Number(daily?.points??0)+policy.points))throw fail('Daily total overflow.');
  const receipt={schemaVersion:1,organizationId:org,memberId:uid,awardId,eventId:attemptId,attemptId,routineId:evidence.routineId,day:evidence.day,routineDifficulty:routine?.difficulty??null,sourceId:'routine_completion',producerVersion:'routine-reward-v1',policyVersion:policy.version,policySnapshot:policy,occurredAtMillis:Math.max(...sessions.map(s=>Number(s!.endedAtMillis))),awardedAtMillis:now,basePoints:policy.points,points:policy.points,premiumBonus:false,tierEvidence:'no_multipliers',difficultyMultipliersEnabled:false,sessionIds};
  tx.create(awardPath,receipt);tx.set(balancePath,{...balance,schemaVersion:1,organizationId:org,memberId:uid,points:total,recentRedemptionIds:balance?.recentRedemptionIds??[],updatedAtMillis:now});tx.set(dailyPath,{schemaVersion:1,organizationId:org,memberId:uid,date:today,count:Number(daily?.count??0)+1,points:Number(daily?.points??0)+policy.points});
  for(const id of sessionIds)tx.create(`orgs/${org}/workoutRewardSessionClaims/${hash([uid,id])}`,{schemaVersion:1,organizationId:org,memberId:uid,sessionId:id,attemptId,awardId,claimedAtMillis:now});
  return {schemaVersion:1,organizationId:org,memberId:uid,status:'awarded',reason:'confirmed_receipt',policyVersion:policy.version,draftPoints:policy.points,awardId};
 });
}
