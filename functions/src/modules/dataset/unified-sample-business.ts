/** Descriptive simulation only. Never consumed by payment, entitlement or booking commands. */
import {DomainError} from '../../platform/errors';
export interface SamplePlanReference {id:'basic'|'premium';name:string;amountMinor:number;durationDays:number;version:string}
interface Common {schemaVersion:1;id:string;provenance:'fyp_business_simulation';currency:'MYR'}
export type SampleBusinessRow=Common&(
 |{kind:'plan';planId:string;name:string;amountMinor:number;durationDays:number;version:string}
 |{kind:'subscription';memberId:string;planId:string;status:'active'|'expired';startedAtMillis:number;expiresAtMillis:number|null}
 |{kind:'appointment';memberId:string;coachId:string;branchId:'main';status:'completed'|'cancelled';startAtMillis:number;endAtMillis:number;illustrativeFeeMinor:number}
 |{kind:'ledger';memberId:string;stream:'membership'|'coaching';event:'simulated_purchase'|'simulated_renewal'|'simulated_consultation';referenceId:string;atMillis:number;amountMinor:number}
 |{kind:'program_relationship';memberId:string;programId:string;relationship:'illustrative_assignment'});
const DAY=86400000,OFFSET=8*3600000;
const fail=()=>new DomainError('failed-precondition','Sample business sources require review. No partial amounts were returned.');
const integer=(x:unknown):x is number=>Number.isSafeInteger(x)&&Number(x)>=0;
const id=(x:unknown):x is string=>typeof x==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(x);
export function buildUnifiedSampleBusiness(input:{anchorAtMillis:number;memberIds:readonly string[];coachIds:readonly string[];programIds:readonly string[];plans:readonly SamplePlanReference[]}):SampleBusinessRow[]{
 const lists=[input.memberIds,input.coachIds,input.programIds];
 if(!integer(input.anchorAtMillis)||input.anchorAtMillis<Date.UTC(2020,0,1)||input.anchorAtMillis>8640000000000000-DAY||lists.some(x=>!Array.isArray(x)||x.length<1||x.length>20||x.some(v=>!id(v))||new Set(x).size!==x.length)||input.plans.length!==2||new Set(input.plans.map(p=>p.id)).size!==2||input.plans.some(p=>!['basic','premium'].includes(p.id)||!integer(p.amountMinor)||p.amountMinor<1||p.amountMinor>1000000||!integer(p.durationDays)||p.durationDays<1||p.durationDays>366||!p.name||p.name.length>80||!p.version||p.version.length>80))throw fail();
 const members=[...input.memberIds].sort(),coaches=[...input.coachIds].sort(),programs=[...input.programIds].sort(),plans=new Map(input.plans.map(p=>[p.id,p]));
 const local=new Date(input.anchorAtMillis+OFFSET),monthAt=(offset:number,day:number)=>Date.UTC(local.getUTCFullYear(),local.getUTCMonth()-offset,day,9)-OFFSET;
 const rows:SampleBusinessRow[]=[],common=(key:string):Common=>({schemaVersion:1,id:key,provenance:'fyp_business_simulation',currency:'MYR'});
 rows.push({...common('sim-plan-free'),kind:'plan',planId:'free',name:'Free baseline (illustrative)',amountMinor:0,durationDays:30,version:'illustrative-free-v1'});
 for(const p of [...input.plans].sort((a,b)=>a.id.localeCompare(b.id)))rows.push({...common('sim-plan-'+p.id),kind:'plan',planId:p.id,name:p.name,amountMinor:p.amountMinor,durationDays:p.durationDays,version:p.version});
 members.forEach((memberId,i)=>{
  const planId=i%3===0?'free':i%3===1?'basic':'premium',plan=plans.get(planId as 'basic'|'premium'),key='sim-sub-'+String(i+1).padStart(2,'0'),expired=i===members.length-1&&planId!=='free',latest=monthAt(expired?1:0,i%3+1);
  rows.push({...common(key),kind:'subscription',memberId,planId,status:expired?'expired':'active',startedAtMillis:monthAt(2,i%3+1),expiresAtMillis:plan?latest+plan.durationDays*DAY:null});
  rows.push({...common('sim-program-'+String(i+1).padStart(2,'0')),kind:'program_relationship',memberId,programId:programs[i%programs.length],relationship:'illustrative_assignment'});
  if(plan)for(const offset of [2,1,0]){if(expired&&offset===0)continue;const atMillis=monthAt(offset,i%3+1);if(atMillis>input.anchorAtMillis)throw fail();rows.push({...common(`sim-membership-${i+1}-${offset}`),kind:'ledger',memberId,stream:'membership',event:offset===2?'simulated_purchase':'simulated_renewal',referenceId:key,atMillis,amountMinor:plan.amountMinor});}
 });
 for(let i=0;i<24;i++){const memberId=members[i%members.length],coachId=coaches[i%coaches.length],key='sim-appointment-'+String(i+1).padStart(2,'0'),startAtMillis=monthAt(i<12?2:1,i%12+3),status=i%3===0?'cancelled':'completed';
  rows.push({...common(key),kind:'appointment',memberId,coachId,branchId:'main',status,startAtMillis,endAtMillis:startAtMillis+3600000,illustrativeFeeMinor:8000});
  if(status==='completed')rows.push({...common('sim-coaching-'+String(i+1).padStart(2,'0')),kind:'ledger',memberId,stream:'coaching',event:'simulated_consultation',referenceId:key,atMillis:startAtMillis+3600000,amountMinor:8000});
 }
 return rows.sort((a,b)=>a.id.localeCompare(b.id));
}
const fields:Record<SampleBusinessRow['kind'],string[]>={plan:['planId','name','amountMinor','durationDays','version'],subscription:['memberId','planId','status','startedAtMillis','expiresAtMillis'],appointment:['memberId','coachId','branchId','status','startAtMillis','endAtMillis','illustrativeFeeMinor'],ledger:['memberId','stream','event','referenceId','atMillis','amountMinor'],program_relationship:['memberId','programId','relationship']};
export function aggregateUnifiedSampleBusiness(rows:readonly SampleBusinessRow[],window:{startAtMillis:number;endAtMillis:number},now:number){
 if(!Array.isArray(rows)||rows.length>250||!integer(now)||!integer(window.startAtMillis)||!integer(window.endAtMillis)||window.startAtMillis>=window.endAtMillis||window.endAtMillis>now+DAY)throw fail();
 const byId=new Map<string,SampleBusinessRow>(),plans=new Map<string,Extract<SampleBusinessRow,{kind:'plan'}>>(),subscriptions=new Map<string,Extract<SampleBusinessRow,{kind:'subscription'}>>();
 for(const row of rows as readonly SampleBusinessRow[]){if(!row||row.schemaVersion!==1||!id(row.id)||byId.has(row.id)||row.provenance!=='fyp_business_simulation'||row.currency!=='MYR'||!Object.hasOwn(fields,row.kind)||Object.keys(row).sort().join(',')!==['schemaVersion','id','provenance','currency','kind',...fields[row.kind]].sort().join(','))throw fail();byId.set(row.id,row);
  if(row.kind==='plan'){if(!id(row.planId)||plans.has(row.planId)||!integer(row.amountMinor)||row.amountMinor>1000000||!integer(row.durationDays)||row.durationDays<1||row.durationDays>366||typeof row.name!=='string'||!row.name||row.name.length>80||typeof row.version!=='string'||!row.version||row.version.length>80)throw fail();plans.set(row.planId,row);}
  if(row.kind==='subscription'){if(!id(row.memberId)||subscriptions.has(row.memberId)||!['active','expired'].includes(row.status)||!integer(row.startedAtMillis)||row.startedAtMillis>now||row.expiresAtMillis!==null&&(!integer(row.expiresAtMillis)||row.expiresAtMillis<=row.startedAtMillis))throw fail();subscriptions.set(row.memberId,row);}
 }
 const inRange=(at:number)=>at>=window.startAtMillis&&at<window.endAtMillis&&at<=now,monthly=new Map<string,{month:string;amountMinor:number;membershipMinor:number;coachingMinor:number}>();
 const result={provenance:'fyp_business_simulation' as const,currency:'MYR' as const,simulatedRevenueMinor:0,membershipRevenueMinor:0,coachingRevenueMinor:0,subscriptions:{total:subscriptions.size,active:0,expired:0,free:0,basic:0,premium:0},appointments:{total:0,completed:0,cancelled:0},monthly:[] as {month:string;amountMinor:number;membershipMinor:number;coachingMinor:number}[],rows:rows.length};
 const seenEvents=new Set<string>();
 for(const row of rows as readonly SampleBusinessRow[]){
  if(row.kind!=='plan'&&!subscriptions.has(row.memberId))throw fail();
  if(row.kind==='subscription'){if(!plans.has(row.planId)||!['free','basic','premium'].includes(row.planId))throw fail();result.subscriptions[row.status]++;result.subscriptions[row.planId as 'free'|'basic'|'premium']++;}
  if(row.kind==='program_relationship'&&(!id(row.programId)||row.relationship!=='illustrative_assignment'))throw fail();
  if(row.kind==='appointment'){if(!id(row.coachId)||row.branchId!=='main'||!['completed','cancelled'].includes(row.status)||!integer(row.startAtMillis)||!integer(row.endAtMillis)||row.endAtMillis-row.startAtMillis!==3600000||row.endAtMillis>now||!integer(row.illustrativeFeeMinor)||row.illustrativeFeeMinor<1)throw fail();if(inRange(row.startAtMillis)){result.appointments.total++;result.appointments[row.status]++;}}
  if(row.kind==='ledger'){
   if(!integer(row.atMillis)||row.atMillis>now||!integer(row.amountMinor)||row.amountMinor<1||!['membership','coaching'].includes(row.stream))throw fail();const ref=byId.get(row.referenceId);
   if(row.stream==='membership'){if(ref?.kind!=='subscription'||ref.memberId!==row.memberId||plans.get(ref.planId)?.amountMinor!==row.amountMinor||!['simulated_purchase','simulated_renewal'].includes(row.event))throw fail();}
   else if(ref?.kind!=='appointment'||ref.memberId!==row.memberId||ref.status!=='completed'||ref.illustrativeFeeMinor!==row.amountMinor||ref.endAtMillis!==row.atMillis||row.event!=='simulated_consultation')throw fail();
   const eventKey=`${row.stream}:${row.referenceId}:${row.atMillis}`;if(seenEvents.has(eventKey))throw fail();seenEvents.add(eventKey);
   if(inRange(row.atMillis)){const key=new Date(row.atMillis+OFFSET).toISOString().slice(0,7),bucket=monthly.get(key)??{month:key,amountMinor:0,membershipMinor:0,coachingMinor:0};bucket.amountMinor+=row.amountMinor;bucket[row.stream==='membership'?'membershipMinor':'coachingMinor']+=row.amountMinor;monthly.set(key,bucket);result.simulatedRevenueMinor+=row.amountMinor;result[row.stream==='membership'?'membershipRevenueMinor':'coachingRevenueMinor']+=row.amountMinor;}
  }
 }
 if(!Number.isSafeInteger(result.simulatedRevenueMinor))throw fail();result.monthly=[...monthly.values()].sort((a,b)=>a.month.localeCompare(b.month));return result;
}
