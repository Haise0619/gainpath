import {DomainError} from '../../platform/errors';
import type {DocumentData,DocumentStore} from '../../platform/firestore/store';
import {resolveMembershipEntitlement} from '../commerce/membership-entitlement';
import {rewardVoucherDetails} from './reward-details';
import {validateParticipationHistoryReceipt} from './mini-game-participation';
type Row={id:string;data:DocumentData};
export type PointsHistoryRows={claims:Row[];awards:Row[];adjustments:Row[];redemptions:Row[];participation?:Row[]};
const fail=()=>new DomainError('failed-precondition','Complete points history is unavailable.');
const int=(v:unknown,min=0):v is number=>Number.isSafeInteger(v)&&Number(v)>=min;
const id=(v:unknown):v is string=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(v);
export function buildPointsHistory(org:string,uid:string,balance:number,now:number,rows:PointsHistoryRows,demoBalance=0){
 if(!int(balance)||!int(demoBalance)||!int(now,1))throw fail();
 const entries:{id:string;source:string;title:string;points:number;occurredAtMillis:number;redemptionId:string|null;wallet:'spendable'|'demo'}[]=[];
 for(const [kind,list]of Object.entries(rows)){
  if(!Array.isArray(list)||list.length>200)throw new DomainError('resource-exhausted','Points history exceeds the supported range.');
  const seen=new Set<string>();
  for(const {id:key,data:d}of list){
   if(!id(key)||seen.has(key)||(kind==='participation'?![1,2].includes(Number(d.schemaVersion)):d.schemaVersion!==1)||d.organizationId!==org||d.memberId!==uid||!int(d.points,1))throw fail();seen.add(key);
   let at:unknown,title:string,source:string,points=Number(d.points),redemptionId:string|null=null;
   if(kind==='claims'){
    if(d.source!=='app_check_in'||d.policyVersion!=='app-check-in-v1'||d.points!==50||d.date!==key||!/^\d{4}-\d{2}-\d{2}$/.test(key))throw fail();
    at=d.claimedAtMillis;title='Daily check-in';source='app_check_in';
    if(int(at,1)&&new Date(at+8*3600000).toISOString().slice(0,10)!==key)throw fail();
   }else if(kind==='adjustments'){
    if(d.source!=='owner_manual_adjustment'||d.requestId!==key||!int(d.balanceBefore)||!int(d.balanceAfter)||d.balanceAfter!==d.balanceBefore+points)throw fail();
    at=d.awardedAtMillis;title='Manual points credit';source='manual_credit';
   }else if(kind==='participation'){
    validateParticipationHistoryReceipt(d,org,uid,key);
    at=d.awardedAtMillis;title='Move & Catch participation';source='mini_game_participation';
   }else if(kind==='awards'){
    if(d.awardId!==key||!id(d.eventId)||!id(d.sourceId)||!id(d.policyVersion)||!id(d.producerVersion)||!int(d.basePoints,1)||typeof d.premiumBonus!=='boolean'||points!==(d.premiumBonus?Math.floor(d.basePoints*3/2):d.basePoints))throw fail();
    if(d.sourceId==='owner_demo_bonus'&&(d.eventId!=='owner-demo-bonus-20261027'||d.producerVersion!=='owner-demo-bonus-v1'||d.policyVersion!=='owner-demo-bonus-20261027-v1'||d.basePoints!==100||d.points!==100||d.premiumBonus!==false||d.reason!=='Owner-approved one-time demo bonus'))throw fail();
    at=d.awardedAtMillis;title=d.sourceId==='owner_demo_bonus'?'Demo bonus':d.sourceId==='routine_completion'?'Workout completion reward':'Activity reward';source=d.sourceId==='routine_completion'?'workout_reward':'activity_reward';
   }else{
    if(d.redemptionId!==key||!id(d.itemId)||!id(d.requestId)||!id(d.policyVersion)||!id(d.exchangeRateVersion)||typeof d.title!=='string'||!d.title.trim()||d.title.length>200||!['issued','fulfilled'].includes(String(d.status)))throw fail();
    rewardVoucherDetails(d);at=d.issuedAtMillis;title=d.title;source='redemption';points=-points;redemptionId=key;
   }
   if(!int(at,1)||at>now)throw fail();entries.push({id:kind+':'+key,source,title,points,occurredAtMillis:at,redemptionId,wallet:kind==='participation'&&d.redeemable===false?'demo':'spendable'});
  }
 }
 entries.sort((a,b)=>b.occurredAtMillis-a.occurredAtMillis||a.id.localeCompare(b.id));
 const net=(wallet:string)=>entries.filter(e=>e.wallet===wallet).reduce((sum,e)=>sum+e.points,0);
 const spendableNet=net('spendable'),demoNet=net('demo');if(!Number.isSafeInteger(spendableNet)||!Number.isSafeInteger(demoNet))throw fail();
 return {schemaVersion:2,organizationId:org,memberId:uid,balance,demoBalance,entries,reconciled:spendableNet===balance,demoReconciled:demoNet===demoBalance,resolvedAtMillis:now};
}
export async function readPointsHistory(store:DocumentStore,auth:{uid:string;token:Record<string,unknown>},org:string,reader:()=>Promise<PointsHistoryRows>,clock:()=>number=Date.now){
 const check=()=>store.transact(async tx=>{
  await resolveMembershipEntitlement(tx,auth,org,clock());
  const member=await tx.get(`orgs/${org}/members/${auth.uid}`);if(member?.role!=='member')throw new DomainError('permission-denied','Member history required.');
  const balance=await tx.get(`orgs/${org}/rewardBalances/${auth.uid}`);
  const demo=await tx.get(`orgs/${org}/miniGameParticipationBalances/${auth.uid}`);
  if(balance&&(balance.schemaVersion!==1||balance.organizationId!==org||balance.memberId!==auth.uid||!int(balance.points)))throw fail();
  if(demo&&(demo.schemaVersion!==1||demo.organizationId!==org||demo.memberId!==auth.uid||demo.mode!=='participation_demo'||demo.redeemable!==false||!int(demo.demoPoints)))throw fail();
  return {balance:balance?.points??0,demoBalance:demo?.demoPoints??0,revision:JSON.stringify([balance??null,demo??null])};
 });
 const before=await check(),rows=await reader(),after=await check();if(before.revision!==after.revision)throw new DomainError('aborted','Points changed while loading. Please refresh.');
 return buildPointsHistory(org,auth.uid,Number(after.balance),clock(),rows,Number(after.demoBalance));
}
