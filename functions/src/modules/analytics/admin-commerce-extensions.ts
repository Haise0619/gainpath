import {DomainError} from '../../platform/errors';
import {readAll,type DocumentStore,type DocumentData} from '../../platform/firestore/store';
import {readVerifiedTargetMembershipEntitlement} from '../commerce/membership-entitlement';
import {authorizeAdminReport,type ReportRow} from './admin-reporting';
type Auth={uid:string;token:Record<string,unknown>};
export type ReportIdentity={exists:boolean;disabled:boolean;emailVerified:boolean};
const DAY=86400000, OFF=28800000;
const integer=(v:unknown):v is number=>Number.isSafeInteger(v)&&Number(v)>=0;
const id=(v:unknown):v is string=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(v);
const fail=()=>new DomainError('failed-precondition','Coach and membership sources need authorized review. No partial totals returned.');
const date=(n:number)=>new Date(n+OFF).toISOString().slice(0,10);
const metric=()=>({purchases:0,renewals:0,confirmedMinor:0,confirmedCount:0,reviewMinor:0,refundedMinor:0,statuses:{} as Record<string,number>,refundStatuses:{} as Record<string,number>,daily:[] as {date:string;confirmedMinor:number;purchases:number;renewals:number}[],previous:{confirmedMinor:0,confirmedCount:0,purchases:0,renewals:0}});
export async function commerceExtensions(store:DocumentStore,auth:Auth,org:string,from:number,until:number,now:number,members:ReportRow[],bookings:ReportRow[],payments:ReportRow[],identity?: (uid:string)=>Promise<ReportIdentity>){
 const span=until-from, previousFrom=from-span, previousAvailable=previousFrom>=0&&until<=now;
 const inside=(n:unknown):n is number=>integer(n)&&n>=from&&n<until&&n<=now;
 const coaches=new Map<string,{coachId:string;name:string;bookings:number;confirmed:number;completed:number;cancelled:number;expired:number;pendingHold:number;refunded:number;consultations:number;missingConsultations:number;reviewCount:number;ratingSum:number;scheduledStarts:number;daily:{date:string;bookings:number;consultations:number}[]}>();
 const coach=(uid:string,name?:unknown)=>{if(!id(uid))throw fail();if(!coaches.has(uid))coaches.set(uid,{coachId:uid,name:typeof name==='string'&&name.trim()?name.slice(0,100):'Coach '+uid,bookings:0,confirmed:0,completed:0,cancelled:0,expired:0,pendingHold:0,refunded:0,consultations:0,missingConsultations:0,reviewCount:0,ratingSum:0,scheduledStarts:0,daily:[]});return coaches.get(uid)!;};
 const current={free:0,basic:0,premium:0,unknown:0};
 const candidates=members.filter(r=>r.data.status==='active'&&r.data.role==='member');
 if(candidates.length>200||bookings.length>1000)throw new DomainError('resource-exhausted','Coach and membership reporting exceeds its bounded source limit.');
 for(const m of members.filter(r=>r.data.role==='coach')){await store.transact(async tx=>{await authorizeAdminReport(tx,auth,org);const profile=await tx.get(`orgs/${org}/coaches/${m.id}`);coach(m.id,profile?.name??profile?.displayName);});}
 for(const m of candidates){
  const canonical=await store.transact(async tx=>{await authorizeAdminReport(tx,auth,org);return tx.get('users/'+m.id);});
  if(canonical?.organizationId!==org||(canonical.role!==undefined&&canonical.role!=='member')||(m.data.userId!==undefined&&m.data.userId!==m.id))continue;
  const lifecycle=canonical.accountLifecycle as DocumentData|undefined;if(lifecycle&&(lifecycle.state!=='active'||lifecycle.revocationPending!==false))continue;
  if(!identity){current.unknown++;continue;}
  const facts=await identity(m.id);
  if(!facts.exists||facts.disabled||!facts.emailVerified){current.unknown++;continue;}
  const e=await store.transact(async tx=>{await authorizeAdminReport(tx,auth,org);return readVerifiedTargetMembershipEntitlement(tx,m.id,org,now,facts);});
  if(e.status==='resolved'&&['free','basic','premium'].includes(String(e.effectiveTier)))current[e.effectiveTier as 'free'|'basic'|'premium']++;else current.unknown++;
 }
 for(const {id:bookingId,data:b} of bookings){
  if(!id(b.coachId)||!id(b.memberId))throw fail();const c=coach(b.coachId);
  const d=(t:number)=>{const key=date(t);let row=c.daily.find(v=>v.date===key);if(!row){row={date:key,bookings:0,consultations:0};c.daily.push(row);}return row;};
  if(inside(b.createdAtMillis)){c.bookings++;const key=b.status==='pending_hold'?'pendingHold':String(b.status);if(key in c)(c as unknown as Record<string,number>)[key]++;d(b.createdAtMillis).bookings++;}
  if(integer(b.startAtMillis)&&b.startAtMillis>=from&&b.startAtMillis<until&&['confirmed','completed'].includes(String(b.status)))c.scheduledStarts++;
  const [note,review]=await store.transact(async tx=>{await authorizeAdminReport(tx,auth,org);return readAll(tx,[`orgs/${org}/bookings/${bookingId}/consultation/current`,`orgs/${org}/bookings/${bookingId}/review/current`]);});
  if(note){if(note.schemaVersion!==1||note.organizationId!==org||note.bookingId!==bookingId||note.coachId!==b.coachId||note.memberId!==b.memberId||b.status!=='completed'||!integer(note.publishedAtMillis)||!integer(b.endAtMillis)||note.publishedAtMillis<b.endAtMillis||note.publishedAtMillis>now||typeof note.text!=='string'||!note.text.trim())throw fail();if(inside(note.publishedAtMillis)){c.consultations++;d(note.publishedAtMillis).consultations++;}}
  else if(b.status==='completed'&&inside(b.createdAtMillis))c.missingConsultations++;
  if(review){if(!note||review.schemaVersion!==1||review.bookingId!==bookingId||review.coachId!==b.coachId||review.memberId!==b.memberId||!integer(review.stars)||review.stars<1||review.stars>5||!integer(review.reviewedAtMillis)||review.reviewedAtMillis<Number(note.publishedAtMillis)||review.reviewedAtMillis>now)throw fail();if(inside(review.reviewedAtMillis)){c.reviewCount++;c.ratingSum+=review.stars;}}
 }
 const plans=new Map<string,ReturnType<typeof metric>>(),coaching=metric();
 for(const {data:p} of payments){
  if(p.organizationId!==org)throw fail();const membership=['MembershipPurchase','MembershipRenewal'].includes(String(p.kind));if(!membership&&p.type!=='CoachingBooking')throw fail();
  if(p.schemaVersion!==1||p.environment!=='sandbox'||p.provider!=='billplz'||p.currency!=='MYR'||!integer(p.amountMinor))throw fail();
  const planId=membership?(id(p.planId)?p.planId:'unknown'):'coaching';if(membership&&!plans.has(planId))plans.set(planId,metric());const t=membership?plans.get(planId)!:coaching;
  if(inside(p.createdAtMillis)){const status=typeof p.paymentStatus==='string'?p.paymentStatus:'unknown';t.statuses[status]=(t.statuses[status]??0)+1;const refund=typeof p.refundStatus==='string'?p.refundStatus:'none';t.refundStatuses[refund]=(t.refundStatuses[refund]??0)+1;}
  const at=membership?p.clearedAtMillis:p.paymentVerifiedAtMillis;if(p.paymentStatus!=='cleared'||!integer(at)||at>now)continue;
  const confirmed=p.fulfilmentStatus==='confirmed'&&(p.refundStatus===undefined||['none','rejected'].includes(String(p.refundStatus)));
  const key=p.kind==='MembershipRenewal'?'renewals':'purchases';
  if(inside(at)){if(p.refundStatus==='completed')t.refundedMinor+=p.amountMinor;else if(!confirmed)t.reviewMinor+=p.amountMinor;else{t.confirmedMinor+=p.amountMinor;t.confirmedCount++;if(membership)t[key]++;const label=date(at);let row=t.daily.find(x=>x.date===label);if(!row){row={date:label,confirmedMinor:0,purchases:0,renewals:0};t.daily.push(row);}row.confirmedMinor+=p.amountMinor;if(membership)row[key]++;}}
  if(previousAvailable&&at>=previousFrom&&at<from&&confirmed){t.previous.confirmedMinor+=p.amountMinor;t.previous.confirmedCount++;if(membership)t.previous[key]++;}
 }
 for(const t of [...plans.values(),coaching]){t.daily.sort((a,b)=>a.date.localeCompare(b.date));for(const n of [t.confirmedMinor,t.reviewMinor,t.refundedMinor,t.previous.confirmedMinor])if(!integer(n))throw fail();}
 await store.transact(tx=>authorizeAdminReport(tx,auth,org));
 return {schemaVersion:1,asOfMillis:now,coaches:[...coaches.values()].sort((a,b)=>a.coachId.localeCompare(b.coachId)).map(c=>({...c,daily:c.daily.sort((a,b)=>a.date.localeCompare(b.date))})),membership:{current,plans:[...plans].sort(([a],[b])=>a.localeCompare(b)).map(([planId,m])=>({planId,...m})),coaching,previousAvailable},coverage:{membersConsidered:candidates.length,bookingsScanned:bookings.length,paymentsScanned:payments.length}};
}
