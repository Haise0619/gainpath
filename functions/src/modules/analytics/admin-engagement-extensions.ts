import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import type {DocumentData} from '../../platform/firestore/store';
import type {ReportRow} from './admin-reporting';
import {rewardVoucherDetails} from '../gamification/reward-details';
import {validateParticipationHistoryReceipt} from '../gamification/mini-game-participation';
export type EngagementCollection = 'rewardRedemptions'|'miniGameRoundSessions'|'miniGameParticipationAwards';
export type EngagementPage = (kind: EngagementCollection, after: string|undefined, limit: number)=>Promise<ReportRow[]>;
const fail = () => new DomainError('failed-precondition','Reward and game reporting sources need authorized review. No partial totals were returned.');
const cap = () => new DomainError('resource-exhausted','Reward and game reporting exceeds its bounded scan limit. No partial totals were returned.');
const integer = (v:unknown):v is number => Number.isSafeInteger(v)&&Number(v)>=0;
const time = (v:unknown):v is number => integer(v)&&v<=8640000000000000-28800000;
const date = (t:number)=>new Date(t+28800000).toISOString().slice(0,10);
const ids = ['move-catch-v1','reach-tap-v1'];
export async function engagementExtensions(org:string,from:number,until:number,now:number,page:EngagementPage,authorize:()=>Promise<unknown>,badgeUnlocks:{badgeId:string;at:number}[],checkInClaims:number,checkInPoints:number) {
 const inRange=(t:number)=>t>=from&&t<until&&t<=now;
 const scanned:Record<EngagementCollection,ReportRow[]>={rewardRedemptions:[],miniGameRoundSessions:[],miniGameParticipationAwards:[]};
 for(const kind of Object.keys(scanned) as EngagementCollection[]){
  let after:string|undefined;
  do{await authorize();const rows=await page(kind,after,251);if(!Array.isArray(rows)||rows.length>251)throw fail();
   let previous=after;
   for(const r of rows){if(!r||typeof r.id!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(r.id)||(previous!==undefined&&r.id<=previous)||!r.data||r.data.organizationId!==org)throw fail();previous=r.id;scanned[kind].push(r);if(scanned[kind].length>2000)throw cap();}
   if(rows.length<251)break;after=rows.at(-1)!.id;
  }while(true);
 }
 const redemptionDays=new Map<string,{date:string;issued:number;collected:number;expired:number;pointsSpent:number}>();
 const day=(t:number)=>{const d=date(t);if(!redemptionDays.has(d))redemptionDays.set(d,{date:d,issued:0,collected:0,expired:0,pointsSpent:0});return redemptionDays.get(d)!;};
 const redemptions={issued:0,collected:0,expired:0,pointsSpent:0,issuedStatus:{outstanding:0,collected:0,expired:0,expiryUnknown:0},daily:[] as ReturnType<typeof day>[],rewards:[] as {itemId:string;title:string;issued:number;collected:number;pointsSpent:number}[]};
 const rewards=new Map<string,typeof redemptions.rewards[number]>();
 for(const {id,data:r} of scanned.rewardRedemptions){
  if(r.schemaVersion!==1||r.redemptionId!==id||!['issued','fulfilled'].includes(String(r.status))||!integer(r.points)||r.points<1||!time(r.issuedAtMillis)||r.issuedAtMillis>now||typeof r.title!=='string'||!r.title.trim()||r.title.length>120)throw fail();
  try{requiredIdentifier(r.memberId,'member');requiredIdentifier(r.itemId,'item');requiredIdentifier(r.policyVersion,'policy');requiredIdentifier(r.exchangeRateVersion,'exchange');rewardVoucherDetails(r);}catch{throw fail();}
  if(r.status==='fulfilled'&&(!time(r.fulfilledAtMillis)||r.fulfilledAtMillis<r.issuedAtMillis||r.fulfilledAtMillis>now||typeof r.fulfilledBy!=='string'))throw fail();
  const item=String(r.itemId);if(!rewards.has(item))rewards.set(item,{itemId:item,title:r.title,issued:0,collected:0,pointsSpent:0});const summary=rewards.get(item)!;
  const expired=r.status==='issued'&&r.rewardDetailsVersion===1&&Number(r.expiresAtMillis)<=now;
  if(inRange(r.issuedAtMillis)){redemptions.issued++;redemptions.pointsSpent+=r.points;day(r.issuedAtMillis).issued++;day(r.issuedAtMillis).pointsSpent+=r.points;summary.issued++;summary.pointsSpent+=r.points;
   redemptions.issuedStatus[r.status==='fulfilled'?'collected':expired?'expired':r.rewardDetailsVersion===1?'outstanding':'expiryUnknown']++;
  }
  if(r.status==='fulfilled'&&inRange(Number(r.fulfilledAtMillis))){redemptions.collected++;day(Number(r.fulfilledAtMillis)).collected++;summary.collected++;}
  if(expired&&inRange(Number(r.expiresAtMillis))){redemptions.expired++;day(Number(r.expiresAtMillis)).expired++;}
 }
 redemptions.daily=[...redemptionDays.values()].sort((a,b)=>a.date.localeCompare(b.date));
 redemptions.rewards=[...rewards.values()].filter(r=>r.issued||r.collected).sort((a,b)=>b.issued-a.issued||a.itemId.localeCompare(b.itemId));
 const games=ids.map(gameId=>({gameId,started:0,completed:0,abandoned:0,open:0,uniqueMembers:0,awards:0,pointsAwarded:0,daily:[] as {date:string;started:number;completed:number;awards:number;pointsAwarded:number}[]}));
 const members=ids.map(()=>new Set<string>()),days=ids.map(()=>new Map<string,typeof games[number]['daily'][number]>());
 const gameDay=(i:number,t:number)=>{const d=date(t);if(!days[i].has(d))days[i].set(d,{date:d,started:0,completed:0,awards:0,pointsAwarded:0});return days[i].get(d)!;};
 for(const {id,data:r} of scanned.miniGameRoundSessions){
  const i=ids.indexOf(String(r.gameId));
  if(i<0||r.schemaVersion!==1||r.attemptId!==id||!/^[a-f0-9]{32}$/.test(id)||!['open','awaiting_verification','abandoned'].includes(String(r.status))||!time(r.startedAtMillis)||!time(r.lastAtMillis)||r.startedAtMillis>r.lastAtMillis||r.lastAtMillis>now||!integer(r.activeMillis)||r.activeMillis>40000||r.physicalVerified!==false||r.pointsAwarded!==0||!time(r.expiresAtMillis)||r.expiresAtMillis!==r.startedAtMillis+900000||!integer(r.sequence)||r.sequence>361)throw fail();
  try{requiredIdentifier(r.memberId,'member');}catch{throw fail();}
  const g=games[i];if(inRange(r.startedAtMillis)){g.started++;gameDay(i,r.startedAtMillis).started++;members[i].add(String(r.memberId));if(r.status==='abandoned')g.abandoned++;if(r.status==='open')g.open++;}
  if(r.status==='awaiting_verification'){if(r.activeMillis!==40000||r.lastAtMillis-r.startedAtMillis<40000||r.lastAtMillis>=r.expiresAtMillis)throw fail();if(inRange(r.lastAtMillis)){g.completed++;gameDay(i,r.lastAtMillis).completed++;}}
 }
 for(const {id,data:r} of scanned.miniGameParticipationAwards){
  try{requiredIdentifier(r.memberId,'member');validateParticipationHistoryReceipt(r,org,String(r.memberId),id);}catch{throw fail();}
  if(Number(r.awardedAtMillis)>now)throw fail();
  if(r.redeemable!==true)continue; // Historical demo receipts never become spendable points.
  if(inRange(Number(r.awardedAtMillis))){const i=ids.indexOf(String(r.gameId));if(i<0)throw fail();games[i].awards++;games[i].pointsAwarded+=Number(r.points);const d=gameDay(i,Number(r.awardedAtMillis));d.awards++;d.pointsAwarded+=Number(r.points);}
 }
 for(let i=0;i<games.length;i++){games[i].uniqueMembers=members[i].size;games[i].daily=[...days[i].values()].sort((a,b)=>a.date.localeCompare(b.date));}
 const badges=Object.entries(badgeUnlocks.filter(b=>inRange(b.at)).reduce<Record<string,number>>((a,b)=>(a[b.badgeId]=(a[b.badgeId]??0)+1,a),{})).sort(([a],[b])=>a.localeCompare(b)).map(([badgeId,unlocks])=>({badgeId,unlocks}));
 const result={schemaVersion:1,sourceCounts:{redemptions:scanned.rewardRedemptions.length,rounds:scanned.miniGameRoundSessions.length,awards:scanned.miniGameParticipationAwards.length},redemptions,games,badges,earningSources:[{source:'daily_check_in',claims:checkInClaims,pointsAwarded:checkInPoints},...games.map(g=>({source:g.gameId,claims:g.awards,pointsAwarded:g.pointsAwarded}))]};
 const verifyNumbers=(v:unknown):void=>{if(typeof v==='number'&&!integer(v))throw fail();if(v&&typeof v==='object')for(const x of Object.values(v))verifyNumbers(x);};verifyNumbers(result);await authorize();return result;
}
