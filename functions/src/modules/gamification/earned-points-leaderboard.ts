import {isDeepStrictEqual} from 'node:util';
import {requireVerifiedEmail,requireActiveMembership} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {readAll,type DocumentData,type DocumentStore,type TransactionPort} from '../../platform/firestore/store';
import {buildPointsHistory} from './points-history';

type Auth={uid:string;token:Record<string,unknown>};
type Row={id:string;data:DocumentData};
type Source='claims'|'awards'|'participation';
export interface EarnedPointsReader {
 members(after:string|undefined,limit:number):Promise<Row[]>;
 receipts(uid:string,source:Source,after:string|undefined,limit:number):Promise<Row[]>;
}
export const LEADERBOARD_LIMITS={members:2000,eligible:200,receipts:20000,page:100,top:20};
const DAY=86400000,OFFSET=8*3600000;
const integer=(v:unknown):v is number=>Number.isSafeInteger(v)&&Number(v)>=0;
const identifier=(v:unknown):v is string=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(v);
const invalid=()=>new DomainError('invalid-argument','Invalid leaderboard request.');
const retry=()=>new DomainError('aborted','Leaderboard changed while loading. Refresh to retry.');
const cap=()=>new DomainError('resource-exhausted','Leaderboard exceeds its supported scan range.');
async function authorize(tx:TransactionPort,auth:Auth,org:string){
 const[m,u,o]=await readAll(tx,[`orgs/${org}/members/${auth.uid}`,`users/${auth.uid}`,`orgs/${org}`]);
 const l=u?.accountLifecycle as DocumentData|undefined;
 if(requireActiveMembership(m).role!=='member'||m?.organizationId!==org||(m.userId!==undefined&&m.userId!==auth.uid)
  ||u?.organizationId!==org||(u.role!==undefined&&u.role!=='member')||o?.status!=='active'
  ||(l!==undefined&&(!l||l.schemaVersion!==1||l.state!=='active'||l.revocationPending!==false||!integer(l.sessionNotBeforeSeconds)
   ||(l.sessionNotBeforeSeconds>0&&(!integer(auth.token.auth_time)||auth.token.auth_time<l.sessionNotBeforeSeconds)))))
  throw new DomainError('permission-denied','Current active Member required.');
}
function page(rows:Row[],after:string|undefined){
 if(!Array.isArray(rows)||rows.length>LEADERBOARD_LIMITS.page)throw cap();
 let previous=after;
 for(const r of rows){if(!identifier(r.id)||(previous!==undefined&&r.id<=previous)||!r.data)throw retry();previous=r.id;}
}
function eligible(row:Row,user:DocumentData|undefined,org:string){
 try{requireActiveMembership(row.data);}catch{return false;}
 const m=row.data,l=user?.accountLifecycle as DocumentData|undefined;
 return m.role==='member'&&m.status==='active'&&m.organizationId===org&&(m.userId===undefined||m.userId===row.id)
  &&user?.organizationId===org&&(user.role===undefined||user.role==='member')
  &&(l===undefined||(l&&l.schemaVersion===1&&l.state==='active'&&l.revocationPending===false&&integer(l.sessionNotBeforeSeconds)));
}
function displayName(member:DocumentData,user:DocumentData|undefined){
 const raw=typeof member.displayName==='string'?member.displayName:user?.displayName;
 if(typeof raw!=='string'||raw.includes('@'))return 'Member';
 return raw.replace(/[\u0000-\u001f\u007f]/g,'').replace(/\s+/g,' ').trim().slice(0,60)||'Member';
}
/** Read-only projections of earned receipts; balances are consistency witnesses, never scores. */
export async function readEarnedPointsLeaderboard(store:DocumentStore,auth:Auth|undefined,raw:unknown,reader:EarnedPointsReader,clock:()=>number=Date.now){
 requireVerifiedEmail(auth);
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw invalid();const d=raw as DocumentData;
 if(d.schemaVersion!==1||d.action!=='leaderboard'||typeof d.period!=='string'||!['week','all_time'].includes(d.period)
  ||Object.keys(d).sort().join(',')!=='action,organizationId,period,schemaVersion')throw invalid();
 const org=requiredIdentifier(d.organizationId,'organizationId'),uid=requiredIdentifier(auth!.uid,'uid'),now=clock();
 if(!integer(now)||now<1||now>8640000000000000-OFFSET)throw invalid();
 await store.transact(tx=>authorize(tx,auth!,org));
 const ordinal=Math.floor((now+OFFSET)/DAY),weekday=new Date(ordinal*DAY).getUTCDay();
 const start=(ordinal-(weekday+6)%7)*DAY-OFFSET,end=start+7*DAY;
 async function roster(){const rows:Row[]=[];let after:string|undefined;
  while(true){const next=await reader.members(after,LEADERBOARD_LIMITS.page);page(next,after);rows.push(...next);if(rows.length>LEADERBOARD_LIMITS.members)throw cap();if(next.length<LEADERBOARD_LIMITS.page)return rows;after=next.at(-1)!.id;}
 }
 const members=await roster(),candidates=members.filter(r=>r.data.role==='member'&&r.data.status==='active');
 if(candidates.length>LEADERBOARD_LIMITS.eligible)throw cap();
 const snapshot=()=>store.transact(async tx=>{await authorize(tx,auth!,org);return readAll(tx,candidates.flatMap(r=>['users/'+r.id,`orgs/${org}/rewardBalances/${r.id}`]));});
 const before=await snapshot();
 const active=candidates.map((r,i)=>({row:r,user:before[i*2]})).filter(x=>eligible(x.row,x.user,org));
 let scanned=0;
 const totals:{uid:string;displayName:string;points:number}[]=[];
 // Four concurrent Members keep read latency bounded without flooding Firestore.
 for(let offset=0;offset<active.length;offset+=4){
  totals.push(...await Promise.all(active.slice(offset,offset+4).map(async({row,user})=>{
   let points=0;
   for(const source of ['claims','awards','participation'] as const){let after:string|undefined;
    while(true){const records=await reader.receipts(row.id,source,after,LEADERBOARD_LIMITS.page);page(records,after);
     scanned+=records.length;if(scanned>LEADERBOARD_LIMITS.receipts)throw cap();
     const accepted=source==='awards'?records.filter(r=>['routine_completion','mini_game_completion','owner_demo_bonus'].includes(String(r.data.sourceId))):records;
     const history=buildPointsHistory(org,row.id,0,now,{claims:source==='claims'?accepted:[],awards:source==='awards'?accepted:[],adjustments:[],redemptions:[],participation:source==='participation'?accepted:[]});
     for(const entry of history.entries)if(entry.wallet==='spendable'&&(d.period==='all_time'||(entry.occurredAtMillis>=start&&entry.occurredAtMillis<end))){points+=entry.points;if(!integer(points))throw retry();}
     if(records.length<LEADERBOARD_LIMITS.page)break;after=records.at(-1)!.id;
    }
   }
   return {uid:row.id,displayName:displayName(row.data,user),points};
  })));
 }
 if(!isDeepStrictEqual(members,await roster())||!isDeepStrictEqual(before,await snapshot()))throw retry();
 const sorted=totals.filter(r=>r.points>0).sort((a,b)=>b.points-a.points||(a.uid<b.uid?-1:a.uid>b.uid?1:0));
 let rank=0;
 const ranked=sorted.map((r,i)=>{if(i===0||r.points!==sorted[i-1].points)rank=i+1;return {rank,displayName:r.displayName,points:r.points,isYou:r.uid===uid};});
 const you=ranked.find(r=>r.isYou)??{rank:null,displayName:'You',points:0,isYou:true};
 return {schemaVersion:1,organizationId:org,memberId:uid,period:d.period,timezone:'Asia/Kuala_Lumpur',
  periodStartMillis:d.period==='week'?start:null,periodEndMillis:d.period==='week'?end:null,
  resolvedAtMillis:now,totalParticipants:ranked.length,entries:ranked.slice(0,LEADERBOARD_LIMITS.top),you};
}
