import {DomainError} from '../../platform/errors';
import {requireVerifiedEmail,requireActiveMembership} from '../../platform/auth-context';
import {requiredIdentifier,InputValidationError} from '../../platform/validation';
import {readAll,type DocumentStore,type DocumentData,type TransactionPort} from '../../platform/firestore/store';

type Auth={uid:string;token:Record<string,unknown>}|undefined;
export interface ReportRow {id:string;data:DocumentData}
export type ReportCollection='members'|'bookings'|'transactions';
export interface ReportingReader {page(kind:ReportCollection,after:string|undefined,limit:number):Promise<ReportRow[]>}
export const REPORT_SCAN_LIMIT=2000;
const DAY=86400000,OFFSET=8*3600000;
const integer=(v:unknown):v is number=>Number.isSafeInteger(v)&&Number(v)>=0;
const fail=()=>new DomainError('failed-precondition','Reporting source records need authorized review. No partial totals were returned.');
const date=(t:number)=>new Date(t+OFFSET).toISOString().slice(0,10);
const states=['pending_hold','confirmed','cancelled','expired','completed','refunded'] as const;
export interface OperationalReport {
 schemaVersion:1;organizationId:string;startAtMillis:number;endAtMillis:number;
 capturedAtMillis:number;sourceReadStartedAtMillis:number;timezone:'Asia/Kuala_Lumpur';environment:'sandbox';
 currentAccounts:{members:number;coaches:number};
 bookings:{created:number;scheduledStarts:number;statuses:Record<string,number>};
 receipts:{confirmedMinor:number;membershipMinor:number;coachingMinor:number;confirmedCount:number;reviewMinor:number;reviewCount:number;refundedMinor:number;refundedCount:number};
 daily:{date:string;bookingsCreated:number;scheduledStarts:number;receiptsMinor:number;membershipMinor:number;coachingMinor:number}[];
 sourceCounts:Record<ReportCollection,number>;unsupported:string[];
}
async function authorize(tx:TransactionPort,auth:NonNullable<Auth>,org:string) {
 const [user,member,organization]=await readAll(tx,[`users/${auth.uid}`,`orgs/${org}/members/${auth.uid}`,`orgs/${org}`]);
 if(user?.organizationId!==org||member?.organizationId!==org||requireActiveMembership(member).role!=='admin'||
    (user.role!==undefined&&user.role!=='admin')||(member.userId!==undefined&&member.userId!==auth.uid)||organization?.status!=='active')
   throw new DomainError('permission-denied','Active canonical Admin access is required.');
 if(user.accountLifecycle!==undefined){const l=user.accountLifecycle as DocumentData;
   if(!l||l.schemaVersion!==1||l.state!=='active'||l.revocationPending!==false||!integer(l.sessionNotBeforeSeconds)||
     !integer(auth.token.auth_time)||auth.token.auth_time<l.sessionNotBeforeSeconds)throw new DomainError('permission-denied','Your account session changed.');}
}
// Shared canonical authority guard; neither report grants client backup access.
export {authorize as authorizeAdminReport};
async function scan(reader:ReportingReader,kind:ReportCollection):Promise<ReportRow[]> {
 const rows:ReportRow[]=[];let after:string|undefined;
 while(true){const page=await reader.page(kind,after,251);
   if(page.length>251)throw fail();
   for(const row of page){if(!row||typeof row.id!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(row.id)||
     (after!==undefined&&row.id<=after)||!row.data||typeof row.data!=='object')throw fail();
     rows.push(row);after=row.id;if(rows.length>REPORT_SCAN_LIMIT)throw new DomainError('resource-exhausted','Reporting source exceeds the bounded scan limit. No partial totals were returned.');}
   if(page.length<251)return rows;
 }
}
export async function adminReport(store:DocumentStore,auth:Auth,raw:unknown,reader:ReportingReader,clock:()=>number=Date.now):Promise<OperationalReport> {
 requireVerifiedEmail(auth);
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new InputValidationError('Report query required.');
 const d=raw as DocumentData,now=clock();
 if(Object.keys(d).length!==4||d.schemaVersion!==1||!integer(d.startAtMillis)||!integer(d.endAtMillis)||
   d.startAtMillis>=d.endAtMillis||d.endAtMillis>now+DAY||!integer(now))throw new InputValidationError('Invalid report dates or fields.');
 const org=requiredIdentifier(d.organizationId,'organizationId');
 await store.transact(tx=>authorize(tx,auth!,org));
 const [members,bookings,payments]=await Promise.all(['members','bookings','transactions'].map(kind=>scan(reader,kind as ReportCollection)));
 const output:OperationalReport={schemaVersion:1,organizationId:org,startAtMillis:d.startAtMillis,endAtMillis:d.endAtMillis,
   capturedAtMillis:now,sourceReadStartedAtMillis:now,timezone:'Asia/Kuala_Lumpur',environment:'sandbox',
   currentAccounts:{members:0,coaches:0},bookings:{created:0,scheduledStarts:0,statuses:Object.fromEntries(states.map(s=>[s,0]))},
   receipts:{confirmedMinor:0,membershipMinor:0,coachingMinor:0,confirmedCount:0,reviewMinor:0,reviewCount:0,refundedMinor:0,refundedCount:0},
   daily:[],sourceCounts:{members:members.length,bookings:bookings.length,transactions:payments.length},
   unsupported:['posture','facility_occupancy','retention_risk','reward_redemptions','coach_utilization','net_revenue','branch_allocation']};
 const inRange=(t:number)=>t>=Number(d.startAtMillis)&&t<Number(d.endAtMillis)&&t<=now;
 const daily=new Map<string,OperationalReport['daily'][number]>();
 const day=(t:number)=>{const key=date(t);if(!daily.has(key))daily.set(key,{date:key,bookingsCreated:0,scheduledStarts:0,receiptsMinor:0,membershipMinor:0,coachingMinor:0});return daily.get(key)!;};
 const candidates=members.filter(r=>{if(r.data.organizationId!==org)throw fail();return r.data.status==='active'&&['member','coach'].includes(String(r.data.role));});
 for(let offset=0;offset<candidates.length;offset+=200){const batch=candidates.slice(offset,offset+200);
   const users=await store.transact(async tx=>{await authorize(tx,auth!,org);return readAll(tx,batch.map(r=>`users/${r.id}`));});
   for(let i=0;i<batch.length;i++){const u=users[i],m=batch[i].data;
     if(u?.organizationId!==org||(u.role!==undefined&&u.role!==m.role)||(m.userId!==undefined&&m.userId!==batch[i].id))continue;
     if(u.accountLifecycle!==undefined){const l=u.accountLifecycle as DocumentData;if(!l||l.state!=='active'||l.revocationPending!==false)continue;}
     if(m.role==='member')output.currentAccounts.members++;else output.currentAccounts.coaches++;
   }
 }
 for(const {id,data:b} of bookings){
   if(b.organizationId!==org||b.schemaVersion!==1||b.bookingId!==id||!states.includes(b.status as typeof states[number])||
     !integer(b.createdAtMillis)||!integer(b.startAtMillis))throw fail();
   if(inRange(b.createdAtMillis)){output.bookings.created++;output.bookings.statuses[String(b.status)]++;day(b.createdAtMillis).bookingsCreated++;}
   if(['confirmed','completed'].includes(String(b.status))&&b.startAtMillis>=Number(d.startAtMillis)&&b.startAtMillis<Number(d.endAtMillis)){output.bookings.scheduledStarts++;day(b.startAtMillis).scheduledStarts++;}
 }
 const bills=new Set<string>();
 for(const {id,data:p} of payments){
   if(p.organizationId!==org)throw fail();
   if(p.paymentStatus!=='cleared')continue;
   const membership=['MembershipPurchase','MembershipRenewal'].includes(String(p.kind));
   const coaching=p.type==='CoachingBooking'&&!membership;
   const cleared=membership?p.clearedAtMillis:p.paymentVerifiedAtMillis;
   if(p.schemaVersion!==1||p.environment!=='sandbox'||p.provider!=='billplz'||p.currency!=='MYR'||
     (!membership&&!coaching)||(membership?p.transactionId!==id:p.bookingId!==id)||
     !integer(p.amountMinor)||p.amountMinor<1||!integer(cleared)||cleared===0||typeof p.billId!=='string'||!p.billId||
     !['confirmed','reconciliation_required'].includes(String(p.fulfilmentStatus)))throw fail();
   if(bills.has(p.billId))throw fail();bills.add(p.billId);
   if(!inRange(cleared))continue;
   const amount=p.amountMinor,refund=p.refundStatus;
   if(refund==='completed'){output.receipts.refundedMinor+=amount;output.receipts.refundedCount++;}
   else if(p.fulfilmentStatus!=='confirmed'||(refund!==undefined&&!['none','rejected'].includes(String(refund)))){
     output.receipts.reviewMinor+=amount;output.receipts.reviewCount++;
   }else{
     output.receipts.confirmedMinor+=amount;output.receipts.confirmedCount++;
     const field=membership?'membershipMinor':'coachingMinor';output.receipts[field]+=amount;
     const bucket=day(cleared);bucket.receiptsMinor+=amount;bucket[field]+=amount;
   }
   if(Object.values(output.receipts).some(n=>!Number.isSafeInteger(n)))throw fail();
 }
 await store.transact(tx=>authorize(tx,auth!,org));
 output.capturedAtMillis=clock();
 if(!integer(output.capturedAtMillis)||output.capturedAtMillis<now)throw fail();
 output.daily=[...daily.values()].sort((a,b)=>a.date.localeCompare(b.date));
 return output;
}
