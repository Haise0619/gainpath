import {DomainError} from '../../platform/errors';
import {InputValidationError,requiredIdentifier} from '../../platform/validation';
import {requireVerifiedEmail,requireActiveMembership} from '../../platform/auth-context';
import {readAll,type DocumentStore,type DocumentData,type TransactionPort} from '../../platform/firestore/store';

// PROPOSED POLICY: only the isolated reviewed release may activate this producer.
export const APP_CHECK_IN_POLICY=Object.freeze({organizationId:'gainpath',version:'app-check-in-v1',points:50,timezone:'Asia/Kuala_Lumpur'});
const DAY=86400000,OFFSET=8*3600000;
const badgeDefinitions=[{id:'first-check-in',title:'First check-in',requiredStreak:1},{id:'check-in-streak-3',title:'Three-day streak',requiredStreak:3},{id:'check-in-streak-7',title:'Seven-day streak',requiredStreak:7}];
type Auth={uid:string;token:Record<string,unknown>}|undefined;
const integer=(v:unknown,max=Number.MAX_SAFE_INTEGER):v is number=>Number.isSafeInteger(v)&&Number(v)>=0&&Number(v)<=max;
const fail=()=>new DomainError('failed-precondition','Check-in records are unavailable. Refresh before retrying.');
const date=(ordinal:number)=>new Date(ordinal*DAY).toISOString().slice(0,10);
const ordinal=(value:string)=>{if(!/^\d{4}-\d{2}-\d{2}$/.test(value))throw fail();const n=Date.parse(value+'T00:00:00.000Z')/DAY;if(!Number.isInteger(n)||date(n)!==value)throw fail();return n;};
interface Profile {lastOrdinal:number|null;streak:number;longest:number;totalClaims:number;recentDays:string[];badges:Record<string,number>;}
interface Receipt {schemaVersion:number;organizationId:string;memberId:string;date:string;points:number;claimedAtMillis:number;policyVersion:string;source:string;}
export interface CheckInSnapshot {schemaVersion:number;organizationId:string;memberId:string;policyVersion:string;timezone:string;pointsPerClaim:number;balance:number;today:string;claimedToday:boolean;currentStreak:number;longestStreak:number;totalClaims:number;serverNowMillis:number;nextResetMillis:number;days:{date:string;claimed:boolean}[];recentClaims:Receipt[];badges:{id:string;title:string;requiredStreak:number;unlockedAtMillis:number|null}[];}
function parseProfile(raw:DocumentData|undefined,org:string,uid:string,today:number):Profile {
 if(!raw)return {lastOrdinal:null,streak:0,longest:0,totalClaims:0,recentDays:[],badges:{}};
 if(raw.schemaVersion!==1||raw.organizationId!==org||raw.memberId!==uid||!integer(raw.lastOrdinal)||raw.lastOrdinal>today||!integer(raw.streak)||!integer(raw.longest)||!integer(raw.totalClaims)||raw.streak<1||raw.streak>raw.longest||raw.longest>raw.totalClaims||!Array.isArray(raw.recentDays)||raw.recentDays.length===0||raw.recentDays.length>50||new Set(raw.recentDays).size!==raw.recentDays.length||!raw.badges||typeof raw.badges!=='object'||Array.isArray(raw.badges))throw fail();
 if(raw.recentDays.length!==Math.min(raw.totalClaims,50))throw fail();
 for(const badge of badgeDefinitions){const unlocked=Object.hasOwn(raw.badges,badge.id);if(unlocked!==(raw.longest>=badge.requiredStreak))throw fail();}
 const recentDays=raw.recentDays as string[];if(recentDays[0]!==date(raw.lastOrdinal)||recentDays.some((d,i)=>typeof d!=='string'||ordinal(d)>today||(i>0&&ordinal(d)>=ordinal(recentDays[i-1]))))throw fail();
 const badges=raw.badges as Record<string,number>;if(Object.entries(badges).some(([id,at])=>!badgeDefinitions.some(b=>b.id===id)||!integer(at)||at===0))throw fail();
 return {lastOrdinal:raw.lastOrdinal,streak:raw.streak,longest:raw.longest,totalClaims:raw.totalClaims,recentDays,badges};
}
function parseBalance(raw:DocumentData|undefined,org:string,uid:string,p:Profile):number {
 if(!raw){if(p.totalClaims!==0)throw fail();return 0;}
 if(raw.schemaVersion!==1||raw.organizationId!==org||raw.memberId!==uid||!integer(raw.points)||!Array.isArray(raw.recentRedemptionIds)||raw.recentRedemptionIds.length>50||raw.recentRedemptionIds.some(v=>typeof v!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(v)))throw fail();return raw.points;
}
function receipt(raw:DocumentData|undefined,org:string,uid:string,day:string):Receipt {
 if(!raw||raw.schemaVersion!==1||raw.organizationId!==org||raw.memberId!==uid||raw.date!==day||raw.points!==APP_CHECK_IN_POLICY.points||raw.policyVersion!==APP_CHECK_IN_POLICY.version||raw.source!=='app_check_in'||!integer(raw.claimedAtMillis)||Math.floor((raw.claimedAtMillis+OFFSET)/DAY)!==ordinal(day))throw fail();return raw as unknown as Receipt;
}
// Pure validators reused by read-only analytics; earning behavior stays unchanged.
export {parseProfile as parseAppCheckInProfile, receipt as parseAppCheckInReceipt};
async function member(tx:TransactionPort,auth:NonNullable<Auth>,org:string){
 const [user,membership,organization]=await readAll(tx,[`users/${auth.uid}`,`orgs/${org}/members/${auth.uid}`,`orgs/${org}`]);
 if(user?.organizationId!==org||membership?.organizationId!==org||requireActiveMembership(membership).role!=='member'||(membership.userId!==undefined&&membership.userId!==auth.uid)||organization?.status!=='active')throw new DomainError('permission-denied','An active canonical Member is required.');
 if(user.accountLifecycle!==undefined){const l=user.accountLifecycle as DocumentData;if(!l||l.schemaVersion!==1||l.state!=='active'||l.revocationPending!==false||!integer(l.sessionNotBeforeSeconds)||!integer(auth.token.auth_time)||auth.token.auth_time<l.sessionNotBeforeSeconds)throw new DomainError('permission-denied','Your account session changed.');}
}
export async function appCheckInCommand(store:DocumentStore,auth:Auth,raw:unknown,clock:()=>number=Date.now):Promise<{awarded:boolean;snapshot:CheckInSnapshot}> {
 requireVerifiedEmail(auth);
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new InputValidationError('Check-in command required.');
 const data=raw as DocumentData;if(Object.keys(data).length!==3||data.schemaVersion!==1||!['overview','claim'].includes(String(data.action)))throw new InputValidationError('Invalid check-in fields.');
 const org=requiredIdentifier(data.organizationId,'organizationId'),uid=requiredIdentifier(auth!.uid,'member');if(org!==APP_CHECK_IN_POLICY.organizationId)throw new DomainError('permission-denied','Check-in is unavailable for this organization.');
 const profilePath=`orgs/${org}/appCheckInProfiles/${uid}`,balancePath=`orgs/${org}/rewardBalances/${uid}`;
 return store.transact(async tx=>{
  await member(tx,auth!,org);
  const now=clock();if(!integer(now,8639999996400000)||now===0)throw fail();const todayOrdinal=Math.floor((now+OFFSET)/DAY),today=date(todayOrdinal),claimPath=profilePath+'/claims/'+today;
  const [rawProfile,rawBalance,todayReceipt]=await readAll(tx,[profilePath,balancePath,claimPath]);
  const previous=parseProfile(rawProfile,org,uid,todayOrdinal);let p=previous,balance=parseBalance(rawBalance,org,uid,p),awarded=false;
  let created:Receipt|undefined;
  if(todayReceipt){receipt(todayReceipt,org,uid,today);if(p.lastOrdinal!==todayOrdinal)throw fail();}
  else if(p.lastOrdinal===todayOrdinal)throw fail();
  if(data.action==='claim'&&!todayReceipt){
   if(!Number.isSafeInteger(balance+APP_CHECK_IN_POLICY.points)||!Number.isSafeInteger(p.totalClaims+1))throw fail();
   const streak=p.lastOrdinal===todayOrdinal-1?p.streak+1:1;
   p={lastOrdinal:todayOrdinal,streak,longest:Math.max(p.longest,streak),totalClaims:p.totalClaims+1,recentDays:[today,...p.recentDays].slice(0,50),badges:{...p.badges}};
   for(const b of badgeDefinitions)if(streak>=b.requiredStreak&&p.badges[b.id]===undefined)p.badges[b.id]=now;
   created={schemaVersion:1,organizationId:org,memberId:uid,date:today,points:APP_CHECK_IN_POLICY.points,claimedAtMillis:now,policyVersion:APP_CHECK_IN_POLICY.version,source:'app_check_in'};balance+=APP_CHECK_IN_POLICY.points;awarded=true;
  }
  // Read all historical receipts before any transaction writes.
  const priorDays=p.recentDays.filter(d=>!(created&&d===today));
  const prior=await readAll(tx,priorDays.map(d=>profilePath+'/claims/'+d));
  const recent=prior.map((row,i)=>receipt(row,org,uid,priorDays[i]));if(created)recent.unshift(created);
  const snapshot:CheckInSnapshot={schemaVersion:1,organizationId:org,memberId:uid,policyVersion:APP_CHECK_IN_POLICY.version,timezone:APP_CHECK_IN_POLICY.timezone,pointsPerClaim:APP_CHECK_IN_POLICY.points,balance,today,claimedToday:p.lastOrdinal===todayOrdinal,currentStreak:p.lastOrdinal!==null&&todayOrdinal-p.lastOrdinal<=1?p.streak:0,longestStreak:p.longest,totalClaims:p.totalClaims,serverNowMillis:now,nextResetMillis:(todayOrdinal+1)*DAY-OFFSET,days:Array.from({length:7},(_,i)=>{const d=date(todayOrdinal-6+i);return {date:d,claimed:p.recentDays.includes(d)};}),recentClaims:recent,badges:badgeDefinitions.map(b=>({...b,unlockedAtMillis:p.badges[b.id]??null}))};
  if(created){tx.create(claimPath,created);tx.set(profilePath,{schemaVersion:1,organizationId:org,memberId:uid,...p,updatedAtMillis:now});tx.set(balancePath,{...rawBalance,schemaVersion:1,organizationId:org,memberId:uid,points:balance,recentRedemptionIds:rawBalance?.recentRedemptionIds??[],updatedAtMillis:now});}
  return {awarded,snapshot};
 });
}
