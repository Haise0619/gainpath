import {DomainError} from '../../platform/errors';
import type {ReportRow} from './admin-reporting';
import {validateBackupPayload,digestOf} from '../workouts/workout-backup-validation';
export type ObservationEvent={memberId:string;at:number;source:'checkIns'|'bookings'|'games'|'workoutBackups'};
export type ObservationReader={page:(kind:'bookings'|'miniGameRoundSessions',after:string|undefined,limit:number)=>Promise<ReportRow[]>;backups:(uid:string,after:string|undefined,limit:number)=>Promise<ReportRow[]>};
const DAY=86400000,OFFSET=28800000;
const fail=()=>new DomainError('failed-precondition','Recorded activity sources need authorized review. No partial totals returned.');
const cap=()=>new DomainError('resource-exhausted','Recorded activity exceeds its bounded source limit.');
const integer=(v:unknown):v is number=>Number.isSafeInteger(v)&&Number(v)>=0;
const date=(t:number)=>new Date(t+OFFSET).toISOString().slice(0,10);
export async function observedActivity(org:string,from:number,until:number,now:number,eligible:string[],claims:ObservationEvent[],reader:ObservationReader,authorize:()=>Promise<unknown>){
 const events=[...claims],cohort=new Set(eligible);let records=0,bytes=0;
 async function scan(read:(after:string|undefined,limit:number)=>Promise<ReportRow[]>){const all:ReportRow[]=[];let after:string|undefined;do{await authorize();const rows=await read(after,100);if(!Array.isArray(rows)||rows.length>100)throw fail();let previous=after;for(const row of rows){if(!row||typeof row.id!=='string'||!/^[A-Za-z0-9_-]{1,140}$/.test(row.id)||(previous!==undefined&&row.id<=previous)||!row.data)throw fail();previous=row.id;all.push(row);if(++records>6000||all.length>2000)throw cap();}if(rows.length<100)break;after=rows.at(-1)!.id;}while(true);return all;}
 const add=(member:unknown,at:unknown,source:ObservationEvent['source'])=>{if(typeof member!=='string'||!integer(at)||at>8640000000000000-OFFSET)throw fail();if(cohort.has(member)&&at<=now)events.push({memberId:member,at,source});};
 for(const {data:b} of await scan((a,l)=>reader.page('bookings',a,l))){if(b.organizationId!==org||b.schemaVersion!==1||!['pending_hold','confirmed','cancelled','expired','completed','refunded'].includes(String(b.status)))throw fail();add(b.memberId,b.createdAtMillis,'bookings');}
 for(const {id,data:r} of await scan((a,l)=>reader.page('miniGameRoundSessions',a,l))){if(r.organizationId!==org||r.schemaVersion!==1||r.attemptId!==id||!/^[a-f0-9]{32}$/.test(id)||!integer(r.startedAtMillis)||!integer(r.lastAtMillis)||r.startedAtMillis>r.lastAtMillis||r.lastAtMillis>now||!integer(r.activeMillis)||r.activeMillis>40000||r.physicalVerified!==false||r.pointsAwarded!==0||r.expiresAtMillis!==r.startedAtMillis+900000||!integer(r.sequence)||r.sequence>361||(r.status==='awaiting_verification'&&(r.activeMillis!==40000||r.lastAtMillis-r.startedAtMillis<40000||r.lastAtMillis>=Number(r.expiresAtMillis)))||!['move-catch-v1','reach-tap-v1'].includes(String(r.gameId))||!['open','abandoned','awaiting_verification'].includes(String(r.status)))throw fail();add(r.memberId,r.startedAtMillis,'games');}
 for(const uid of eligible){for(const {id,data:b} of await scan((a,l)=>reader.backups(uid,a,l))){if(b.schemaVersion!==1||b.classification!=='provisional_member_backup'||!['session','routine'].includes(String(b.kind))||b.key!==id||b.key!==`${b.kind}-${b.id}`||typeof b.payloadJson!=='string')throw fail();bytes+=Buffer.byteLength(b.payloadJson);if(bytes>16*1024*1024)throw cap();let p;try{p=validateBackupPayload(String(b.kind),String(b.id),org,uid,JSON.parse(b.payloadJson));if(digestOf(p)!==b.digest)throw fail();}catch{throw fail();}if(b.kind==='session')add(uid,Date.parse(String(p.endedAt)),'workoutBackups');}}
 const sourceCounts={checkIns:0,bookings:0,games:0,workoutBackups:0};
 const asOfMillis=Math.min(until-1,now),current=new Set<string>(),previous=new Set<string>(),last=new Map<string,number>();
 type Row={date:string;checkIns:number;bookings:number;games:number;workoutBackups:number;members:Set<string>};const daily=new Map<string,Row>(),weekly=new Map<string,Row>();
 for(const e of events){if(!cohort.has(e.memberId))continue;if(e.at<=asOfMillis)last.set(e.memberId,Math.max(last.get(e.memberId)??0,e.at));if(e.at>=from-(until-from)&&e.at<from)previous.add(e.memberId);if(e.at<from||e.at>=until||e.at>now)continue;current.add(e.memberId);sourceCounts[e.source]++;
 const key=date(e.at),d=new Date(key+'T00:00:00Z'),week=new Date(d.getTime()-(d.getUTCDay()+6)%7*DAY).toISOString().slice(0,10);
 for(const [map,k] of [[daily,key],[weekly,week]] as const){if(!map.has(k))map.set(k,{date:k,checkIns:0,bookings:0,games:0,workoutBackups:0,members:new Set()});const row=map.get(k)!;row[e.source]++;row.members.add(e.memberId);}}
 const recency={within7Days:0,days8To30:0,over30Days:0,noObservedActivity:0};for(const uid of eligible){const t=last.get(uid);if(t===undefined)recency.noObservedActivity++;else{const days=Math.floor((Date.parse(date(asOfMillis)+'T00:00:00Z')-Date.parse(date(t)+'T00:00:00Z'))/DAY);recency[days<7?'within7Days':days<30?'days8To30':'over30Days']++;}}
 const returningMembers=[...previous].filter(uid=>current.has(uid)).length,available=from>=until-from&&until<=now;
 const serialize=(map:Map<string,Row>)=>[...map.values()].sort((a,b)=>a.date.localeCompare(b.date)).map(({members,...row})=>({...row,uniqueMembers:members.size}));await authorize();
 return {schemaVersion:1,asOfMillis,cohortMembers:eligible.length,sourceCounts,daily:serialize(daily),weekly:serialize(weekly),recency,returning:{available,previousMembers:previous.size,currentMembers:current.size,returningMembers,ratePercent:available&&previous.size?returningMembers/previous.size*100:null}};
}

