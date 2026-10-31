import {createHash} from 'node:crypto';
import {requireActiveMembership,requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {readAll,type DocumentData,type DocumentStore,type TransactionPort} from '../../platform/firestore/store';
import {requiredIdentifier} from '../../platform/validation';
import {defaultMiniGameRewardPolicy,miniGameRewardDate,parseMiniGameRewardPolicy,rewardInteger,rewardTime,validateMiniGameRewardFields,type MiniGameRewardPolicy} from './mini-game-reward-policy';

/** Owner-approved participation earning release, 27 October 2026. */
export const MINI_GAME_PARTICIPATION_RELEASE_APPROVED=true;
/** Owner approved Reach & Tap participation20 once/game/Malaysia day,29October. */
export const REACH_TAP_PARTICIPATION_RELEASE_APPROVED=true;
const MOVE='move-catch-v1',REACH='reach-tap-v1';
function reachPolicy(cap=60):MiniGameRewardPolicy{return {schemaVersion:1,revision:0,version:'reach-tap-participation-v1',enabled:false,timezone:'Asia/Kuala_Lumpur',dailyPointsCap:Math.min(60,cap),games:[{gameId:REACH,points:20,dailyClaimLimit:1}],updatedAtMillis:0};}
function isReachPolicy(p:DocumentData){return Object.keys(p).length===8&&p.schemaVersion===1&&p.revision===0&&p.version==='reach-tap-participation-v1'&&p.enabled===false&&p.updatedAtMillis===0&&p.timezone==='Asia/Kuala_Lumpur'&&rewardInteger(p.dailyPointsCap,0,60)&&Array.isArray(p.games)&&p.games.length===1&&p.games[0]?.gameId===REACH&&p.games[0]?.points===20&&p.games[0]?.dailyClaimLimit===1&&Object.keys(p.games[0]).length===3;}
type Auth={uid:string;token:Record<string,unknown>};
interface Dependencies {freshAuth(auth:Auth):Promise<void>;clock?:()=>number;releaseApproved?:boolean}
const digest=(...p:unknown[])=>createHash('sha256').update(JSON.stringify(p)).digest('hex');
const fail=()=>new DomainError('failed-precondition','Participation points could not be confirmed.');
const deny=()=>new DomainError('permission-denied','Current verified Member authority required.');
const identifier=(v:unknown):v is string=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(v);
async function authorize(tx:TransactionPort,auth:Auth,org:string){
 const[member,user,organization]=await readAll(tx,[`orgs/${org}/members/${auth.uid}`,`users/${auth.uid}`,`orgs/${org}`]);
 const role=requireActiveMembership(member).role;
 if(role!=='member'||member?.organizationId!==org||(member.userId!==undefined&&member.userId!==auth.uid)||user?.organizationId!==org
  ||(user.role!==undefined&&user.role!==role)||organization?.status!=='active')throw deny();
 const l=user.accountLifecycle as DocumentData|undefined;
 if(l!==undefined&&(!l||l.schemaVersion!==1||l.state!=='active'||l.revocationPending!==false||!rewardInteger(l.sessionNotBeforeSeconds)
  ||(l.sessionNotBeforeSeconds>0&&(!rewardInteger(auth.token.auth_time)||auth.token.auth_time<l.sessionNotBeforeSeconds))))throw deny();
}
function parse(raw:unknown):DocumentData{
 const invalid=()=>new DomainError('invalid-argument','Invalid participation command.');
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw invalid();const d=raw as DocumentData;
 if((d.schemaVersion!==1&&d.schemaVersion!==2&&d.schemaVersion!==3)||!['participationOverview','claimParticipation'].includes(String(d.action)))throw invalid();
 if(d.schemaVersion===3&&![MOVE,REACH].includes(String(d.gameId)))throw invalid();
 const keys=['schemaVersion','organizationId','action',...(d.schemaVersion===3?['gameId']:[]),...(d.action==='claimParticipation'?['attemptId']:[])];
 if(Object.keys(d).length!==keys.length||Object.keys(d).some(k=>!keys.includes(k)))throw invalid();
 try{requiredIdentifier(d.organizationId,'organizationId');}catch{throw invalid();}
 if(d.action==='claimParticipation'&&(typeof d.attemptId!=='string'||!/^[a-f0-9]{32}$/.test(d.attemptId)))throw invalid();return d;
}
function usage(d:DocumentData|undefined,org:string,uid:string,date:string){
 if(!d)return {points:0,claimsByGame:{} as Record<string,number>};
 if(d.schemaVersion!==1||d.organizationId!==org||d.memberId!==uid||d.timezone!=='Asia/Kuala_Lumpur'||d.date!==date
  ||!rewardInteger(d.points)||!d.claimsByGame||typeof d.claimsByGame!=='object'||Array.isArray(d.claimsByGame))throw fail();
 const counts=d.claimsByGame as Record<string,number>;
 if(Object.keys(counts).length>100||Object.entries(counts).some(([id,count])=>!identifier(id)||!rewardInteger(count,1)))throw fail();
 return {points:d.points,claimsByGame:{...counts}};
}
function priorReceipt(d:DocumentData,org:string,uid:string,attemptId:string,awardId:string){
 if((d.schemaVersion!==1&&d.schemaVersion!==2)||d.organizationId!==org||d.memberId!==uid||d.attemptId!==attemptId||d.awardId!==awardId
  ||![MOVE,REACH].includes(String(d.gameId))||d.verification!=='participation'||d.redeemable!==(d.schemaVersion===2)||d.physicalVerified!==false||d.premiumBonus!==false
  ||!rewardInteger(d.points,1,1000)||!rewardTime(d.awardedAtMillis)||!rewardTime(d.completedAtMillis)||d.completedAtMillis>d.awardedAtMillis
  ||d.date!==miniGameRewardDate(d.awardedAtMillis)||!d.policySnapshot||typeof d.policySnapshot!=='object'||Array.isArray(d.policySnapshot))throw fail();
 const p=d.policySnapshot as DocumentData;
 let policy:MiniGameRewardPolicy;
 if(d.gameId===REACH){if(!isReachPolicy(p)||d.schemaVersion!==2||d.points!==20)throw fail();policy=reachPolicy(Number(p.dailyPointsCap));}
 else if(p.revision===0){policy=defaultMiniGameRewardPolicy();
  let fields:ReturnType<typeof validateMiniGameRewardFields>;
  try{fields=validateMiniGameRewardFields(p);}catch{throw fail();}
  if(p.version!==policy.version||p.enabled!==false||p.updatedAtMillis!==0||p.timezone!==policy.timezone||p.dailyPointsCap!==60
   ||fields.games.length!==1||fields.games[0].gameId!==policy.games[0].gameId||fields.games[0].points!==20||fields.games[0].dailyClaimLimit!==1)throw fail();
 }else policy=parseMiniGameRewardPolicy({...p,organizationId:org},org);
 if(d.policyVersion!==policy.version||policy.games.find(g=>g.gameId===d.gameId)?.points!==d.points)throw fail();
 return d;
}
/** The same immutable receipt validation is used by claims and owned history. */
export function validateParticipationHistoryReceipt(d:DocumentData,org:string,uid:string,awardId:string){
 if(typeof d.attemptId!=='string'||!/^[a-f0-9]{32}$/.test(d.attemptId)
  ||awardId!=='participation_'+digest(org,uid,d.attemptId))throw fail();
 return priorReceipt(d,org,uid,d.attemptId,awardId);
}
/** Lightweight participation only: score and motion never enter the command. */
export async function miniGameParticipation(store:DocumentStore,auth:Auth|undefined,raw:unknown,deps:Dependencies):Promise<Record<string,any>>{
 requireVerifiedEmail(auth);const d=parse(raw),org=String(d.organizationId),uid=requiredIdentifier(auth!.uid,'uid');await deps.freshAuth(auth!);
 const at=(deps.clock??Date.now)(),today=miniGameRewardDate(at),spendable=d.schemaVersion===2||d.schemaVersion===3,gameId=d.schemaVersion===3?String(d.gameId):MOVE;
 // Legacy installed clients keep their read-only demo contract; no automatic conversion.
 const enabled=spendable&&(deps.releaseApproved??MINI_GAME_PARTICIPATION_RELEASE_APPROVED)&&(gameId!==REACH||REACH_TAP_PARTICIPATION_RELEASE_APPROVED);
 const response=await store.transact(async tx=>{
  await authorize(tx,auth!,org);const path=(c:string,id:string)=>`orgs/${org}/${c}/${id}`;
  const dailyPath=path('miniGameParticipationDailyClaims',digest(org,uid,today)),balancePath=path(spendable?'rewardBalances':'miniGameParticipationBalances',uid);
  const [policyData,dailyData,balance]=await readAll(tx,[path('miniGameRewardPolicies','current'),dailyPath,balancePath]);
  const configured=parseMiniGameRewardPolicy(policyData,org),policy=gameId===REACH?reachPolicy(configured.dailyPointsCap):configured,daily=usage(dailyData,org,uid,today);
  if(balance&&(balance.schemaVersion!==1||balance.organizationId!==org||balance.memberId!==uid
   ||(spendable?!rewardInteger(balance.points)||!Array.isArray(balance.recentRedemptionIds)||balance.recentRedemptionIds.length>50||balance.recentRedemptionIds.some(v=>!identifier(v)):balance.mode!=='participation_demo'||balance.redeemable!==false||!rewardInteger(balance.demoPoints))))throw fail();
  let points=Number((spendable?balance?.points:balance?.demoPoints)??0);
  const overview=()=>({today,timezone:'Asia/Kuala_Lumpur',issuanceActive:enabled,policy,...(spendable?{balance:points}:{demoBalance:points}),
   earnedToday:daily.points,remainingToday:Math.max(0,policy.dailyPointsCap-daily.points),claimsToday:daily.claimsByGame[gameId]??0});
  const reply=(status:string,award:DocumentData|null=null)=>({schemaVersion:d.schemaVersion===3?3:spendable?2:1,organizationId:org,memberId:uid,...(d.schemaVersion===3?{gameId}:{}),
   mode:spendable?'participation':'participation_demo',redeemable:spendable,physicalVerified:false,overview:overview(),result:{status,attemptId:d.attemptId??null},award});
  if(d.action==='participationOverview')return reply('overview');
  const attemptId=String(d.attemptId),awardId='participation_'+digest(org,uid,attemptId),awardPath=path('miniGameParticipationAwards',awardId);
  const prior=await tx.get(awardPath);
  if(prior){const receipt=priorReceipt(prior,org,uid,attemptId,awardId);if(receipt.gameId!==gameId)throw fail();
   if(receipt.redeemable!==spendable)return reply('previously-recorded');
   return reply('already-awarded',receipt);
  }
  if(!enabled)return reply('not-active');
  const round=await tx.get(path('miniGameRoundSessions',attemptId));
  if(!round||round.schemaVersion!==1||round.organizationId!==org||round.memberId!==uid||round.attemptId!==attemptId
   ||round.gameId!==gameId||round.status!=='awaiting_verification'||round.physicalVerified!==false||round.pointsAwarded!==0
   ||round.activeMillis!==40000||!rewardInteger(round.sequence,9,361)||!rewardTime(round.startedAtMillis)||!rewardTime(round.lastAtMillis)
   ||!rewardTime(round.expiresAtMillis)||round.expiresAtMillis!==Number(round.startedAtMillis)+900000
   ||round.lastAtMillis>at||round.lastAtMillis>=round.expiresAtMillis||Number(round.lastAtMillis)-Number(round.startedAtMillis)<40000
   ||miniGameRewardDate(Number(round.lastAtMillis))!==today)return reply('not-completed');
  const game=policy.games.find(g=>g.gameId===round.gameId);
  if(!game||!game.points||!game.dailyClaimLimit)return reply('game-disabled');
  if((daily.claimsByGame[game.gameId]??0)>=game.dailyClaimLimit)return reply('game-limit');
  if(daily.points+game.points>policy.dailyPointsCap)return reply('daily-limit');
  if(!rewardInteger(points+game.points)||!rewardInteger(daily.points+game.points))throw fail();
  const award={schemaVersion:2,organizationId:org,memberId:uid,attemptId,awardId,gameId:game.gameId,points:game.points,
   verification:'participation',redeemable:true,physicalVerified:false,premiumBonus:false,
   policyVersion:policy.version,policySnapshot:policy,completedAtMillis:round.lastAtMillis,awardedAtMillis:at,date:today};
  points+=game.points;daily.points+=game.points;daily.claimsByGame[game.gameId]=(daily.claimsByGame[game.gameId]??0)+1;
  tx.create(awardPath,award);
  tx.set(dailyPath,{schemaVersion:1,organizationId:org,memberId:uid,timezone:'Asia/Kuala_Lumpur',date:today,...daily});
  tx.set(balancePath,{...balance,schemaVersion:1,organizationId:org,memberId:uid,points,recentRedemptionIds:balance?.recentRedemptionIds??[],updatedAtMillis:at});
  return reply('awarded',award);
 });
 await deps.freshAuth(auth!);await store.transact(tx=>authorize(tx,auth!,org));return response;
}
