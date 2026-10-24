import type { DocumentStore, TransactionPort, DocumentData } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { requiredIdentifier } from '../../platform/validation';
import { object, allowed, integer } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { storedBooking } from './booking-record';
import { keyOf } from '../../platform/idempotency';
import type { DeliveryBooking } from './google-booking-delivery';

interface Dependencies {
 /** Must verify a current grant for this org, Coach and delivery purpose. */
 authorizeConnection(org:string,coachId:string,kind:'calendar'|'email'):Promise<void>;
 gateway:{putCalendar(b:DeliveryBooking):Promise<{eventId:string}>;sendConfirmation(b:DeliveryBooking,verifiedRecipient:string):Promise<{messageId:string}>};
}
/** Not exposed as a Callable or model tool until OAuth connection UI is ready. */
export async function deliverConfirmedBooking(store:DocumentStore,auth:{uid:string;token:Record<string,unknown>}|undefined,raw:unknown,deps:Dependencies,clock=Date.now){
 requireVerifiedEmail(auth);
 const d=object(raw);allowed(d,['schemaVersion','organizationId','bookingId','kind','requestId','expectedStartAtMillis','confirmed']);
 if(d.schemaVersion!==1||d.confirmed!==true||!['calendar','email'].includes(String(d.kind)))throw new DomainError('invalid-argument','Explicit delivery confirmation is required.');
 const org=requiredIdentifier(d.organizationId,'organizationId'),id=requiredIdentifier(d.bookingId,'bookingId'),uid=auth!.uid,requestId=requiredIdentifier(d.requestId,'requestId'),start=integer(d.expectedStartAtMillis,1),kind=d.kind as 'calendar'|'email';
 const recipient=auth!.token.email;
 if(kind==='email'&&(typeof recipient!=='string'||!recipient||/[\r\n]/.test(recipient)))throw new DomainError('failed-precondition','A verified account email is required.');
 const path=`orgs/${org}/bookings/${id}`,receiptPath=`${path}/externalDelivery/${keyOf(kind,start)}`;
 const read=async(tx:TransactionPort)=>{
   const member=await currentBookingMembership(tx,org,uid);await requireBookingOrganization(tx,org);
   const user=await tx.get(`users/${uid}`),lifecycle=user?.accountLifecycle as Record<string,unknown>|undefined;
   if(lifecycle&&(lifecycle.schemaVersion!==1||lifecycle.state!=='active'||lifecycle.revocationPending!==false||!Number.isSafeInteger(lifecycle.sessionNotBeforeSeconds)||Number(auth!.token.auth_time??0)<Number(lifecycle.sessionNotBeforeSeconds)))throw new DomainError('permission-denied','The authenticated session changed.');
   const b=storedBooking(await tx.get(path),org,id);
   if(member.role!=='member'||b.memberId!==uid)throw new DomainError('permission-denied','Only the owning Member can confirm delivery.');
   if(b.status!=='confirmed'||b.startAtMillis!==start)throw new DomainError('failed-precondition','Reload the current confirmed session before delivery.');
   const p=await tx.get(`orgs/${org}/transactions/${id}`);
   if(!p||p.schemaVersion!==1||p.environment!=='sandbox'||p.provider!=='billplz'||p.type!=='CoachingBooking'||p.currency!=='MYR'||!Number.isSafeInteger(p.amountMinor)||Number(p.amountMinor)<1||p.durationMinutes!==b.durationMinutes||p.organizationId!==org||p.bookingId!==id||p.memberId!==uid||p.coachId!==b.coachId||p.branchId!==b.branchId||p.paymentStatus!=='cleared'||p.fulfilmentStatus!=='confirmed'||p.refundStatus!==undefined||typeof p.coachName!=='string'||typeof p.branchName!=='string')throw new DomainError('failed-precondition','A confirmed paid session is required.');
   const old=await tx.get(receiptPath);
   if(old&&(old.schemaVersion!==1||old.actorId!==uid||old.bookingId!==id||old.kind!==kind||old.startAtMillis!==start||!['sending','delivered','uncertain','reconciliation_required'].includes(String(old.status))))throw new DomainError('failed-precondition','Delivery record needs authorized review.');
   return{booking:{...b,coachName:p.coachName,branchName:p.branchName} as DeliveryBooking,old};
 };
 const initial=await store.transact(read);
 if(initial.old)return{status:initial.old.status};
 await deps.authorizeConnection(org,initial.booking.coachId,kind);
 const reserved=await store.transact(async tx=>{
   const current=await read(tx);if(current.old)return{...current,reserved:false};
   tx.create(receiptPath,{schemaVersion:1,bookingId:id,actorId:uid,kind,startAtMillis:start,requestId,status:'sending',confirmedAtMillis:integer(clock(),1)});
   return{...current,reserved:true};
 });
 if(!reserved.reserved)return{status:reserved.old!.status};
 let outcome:DocumentData;
 try{
   const result=kind==='calendar'?await deps.gateway.putCalendar(reserved.booking):await deps.gateway.sendConfirmation(reserved.booking,recipient as string);
   const providerId='eventId'in result?result.eventId:result.messageId;
   if(typeof providerId!=='string'||!providerId||providerId.length>512)throw Error();
   outcome={status:'delivered',providerId};
 }catch{outcome={status:'uncertain'};}
 // Record an already-issued outcome even if the session was revoked meanwhile;
 // current access is checked separately before returning any result.
 await store.transact(async tx=>{
   const receipt=await tx.get(receiptPath),current=await tx.get(path);
   if(!receipt||receipt.status!=='sending'||receipt.requestId!==requestId)throw new DomainError('failed-precondition','Delivery receipt changed; reconciliation is required.');
   if(current?.status!=='confirmed'||current.startAtMillis!==start)outcome={...outcome,status:'reconciliation_required'};
   tx.set(receiptPath,{...receipt,...outcome,finishedAtMillis:integer(clock(),1)});
 });
 await store.transact(read);
 return{status:outcome.status};
}
