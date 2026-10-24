import {createHash,randomUUID} from 'node:crypto';
import type {DocumentStore,TransactionPort,DocumentData} from '../../platform/firestore/store';
import {DomainError} from '../../platform/errors';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {requiredIdentifier} from '../../platform/validation';
import {object,allowed} from './coach-availability-contracts';
import {currentBookingMembership,requireBookingOrganization} from './booking-validation';
import {storedBooking} from './booking-record';
import type {DeliveryBooking,BookingEmailNotification} from './google-booking-delivery';
import {coachCalendarPath,type GoogleActor} from './google-gym-connection';

export interface SyncDependencies {
 authorize(org:string,coach:string):Promise<void>;
 gateway:{putCalendar(b:DeliveryBooking,guard?:()=>Promise<void>):Promise<{eventId:string}>;removeCalendar(b:DeliveryBooking,guard?:()=>Promise<void>):Promise<{eventId:string}>;sendConfirmation(b:DeliveryBooking,to:string,guard?:()=>Promise<void>):Promise<{messageId:string}>;sendNotification?(b:DeliveryBooking,to:string,notice:BookingEmailNotification,guard?:()=>Promise<void>):Promise<{messageId:string}>};
 recipient(uid:string):Promise<string>;
}
const version=(b:DocumentData)=>createHash('sha256').update(JSON.stringify([b.coachId,b.branchId,b.startAtMillis,b.endAtMillis,b.status])).digest('hex');
export async function syncGymBooking(store:DocumentStore,auth:GoogleActor,raw:unknown,deps:SyncDependencies,clock=Date.now){
 return coordinateGymBooking(store,auth,raw,deps,clock);
}
/** Server-only entry: never exposed as a Callable or selected by client data. */
export async function syncAutomaticGymBooking(store:DocumentStore,org:string,id:string,kind:'calendar'|'email',notice:BookingEmailNotification,deps:SyncDependencies,clock=Date.now){
 return coordinateGymBooking(store,undefined,{organizationId:org,bookingId:id,kind,confirmed:true},deps,clock,notice);
}
async function coordinateGymBooking(store:DocumentStore,auth:GoogleActor,raw:unknown,deps:SyncDependencies,clock:()=>number,automatic?:BookingEmailNotification){
 if(!automatic)requireVerifiedEmail(auth);
 const d=object(raw);allowed(d,['organizationId','bookingId','kind','confirmed']);
 if(d.confirmed!==true||!['calendar','email'].includes(String(d.kind)))throw new DomainError('invalid-argument','Confirm this external delivery first.');
 const org=requiredIdentifier(d.organizationId,'organizationId'),id=requiredIdentifier(d.bookingId,'bookingId'),kind=String(d.kind),attempt=randomUUID(),root=`orgs/${org}/bookings/${id}`;
 const read=async(tx:TransactionPort)=>{
  await requireBookingOrganization(tx,org);
  if(!automatic){const m=await currentBookingMembership(tx,org,auth!.uid);if(m.role!=='admin')throw new DomainError('permission-denied','Only Admin can reconcile external delivery.');
  const u=await tx.get(`users/${auth!.uid}`),l=u?.accountLifecycle as DocumentData|undefined;
  if(l&&(l.state!=='active'||l.revocationPending!==false||!Number.isSafeInteger(l.sessionNotBeforeSeconds)||Number(auth!.token.auth_time??0)<Number(l.sessionNotBeforeSeconds)))throw new DomainError('permission-denied','Sign in again.');
  }
  const b=storedBooking(await tx.get(root),org,id),p=await tx.get(`orgs/${org}/transactions/${id}`);
  if(!['confirmed','cancelled','refunded'].includes(b.status)||kind==='email'&&b.status!=='confirmed'&&!(automatic?.type==='cancelled'&&b.status==='cancelled'))throw new DomainError('failed-precondition','Only eligible session states can synchronize.');
  if(automatic&&(automatic.type==='cancelled'?b.status!=='cancelled':b.status!=='confirmed'))throw new DomainError('failed-precondition','Booking changed before automatic delivery.');
  if(!p||p.schemaVersion!==1||p.organizationId!==org||p.bookingId!==id||p.memberId!==b.memberId||p.coachId!==b.coachId||p.branchId!==b.branchId||p.type!=='CoachingBooking'||p.provider!=='billplz'||p.environment!=='sandbox'||p.currency!=='MYR'||!Number.isSafeInteger(p.amountMinor)||Number(p.amountMinor)<=0||p.durationMinutes!==b.durationMinutes||typeof p.coachName!=='string'||typeof p.branchName!=='string')throw new DomainError('failed-precondition','Payment records need review.');
  if(b.status==='confirmed'&&(p.paymentStatus!=='cleared'||p.fulfilmentStatus!=='confirmed'||p.refundStatus!==undefined))throw new DomainError('failed-precondition','Only cleared confirmed paid sessions can sync.');
  if(automatic&&p.paymentStatus!=='cleared')throw new DomainError('failed-precondition','Automatic delivery requires cleared payment proof.');
  const booking={...b,status:b.status==='refunded'?'cancelled':b.status,coachName:p.coachName,branchName:p.branchName} as DeliveryBooking;
  if(kind==='email'){const recipient=await currentBookingMembership(tx,org,b.memberId);if(recipient.role!=='member')throw new DomainError('failed-precondition','The booking Member is no longer available.');}
  return{booking,version:version(b)};
 };
 const initial=await store.transact(read);await deps.authorize(org,initial.booking.coachId);
 const receiptVersion=kind==='email'&&automatic&&automatic.type!=='confirmed'?createHash('sha256').update(JSON.stringify([automatic.type,automatic.revision])).digest('hex'):initial.version;
 const receiptPath=`${root}/externalDelivery/gym-${kind}-${receiptVersion}`,lockPath=`system/googleBookingSync/bookings/${createHash('sha256').update(org+'/'+id).digest('hex')}`;
 const reservation=await store.transact(async tx=>{
  const current=await read(tx),storedReceipt=await tx.get(receiptPath),lock=await tx.get(lockPath);
  let receipt=storedReceipt;
  if(current.version!==initial.version)throw new DomainError('failed-precondition','Booking changed. Reload before delivery.');
  if(lock?.status==='sending'){
   if(!Number.isSafeInteger(lock.leaseUntilMillis)||Number(lock.leaseUntilMillis)>clock())throw new DomainError('aborted','Another synchronization is pending. Wait for its lease before reconciliation.');
   if(!['calendar','email'].includes(String(lock.kind))||typeof lock.version!=='string'||!/^[a-f0-9]{64}$/.test(lock.version))throw new DomainError('failed-precondition','Stored synchronization lock needs review.');
   const oldPath=`${root}/externalDelivery/gym-${lock.kind}-${typeof lock.receiptVersion==='string'&&/^[a-f0-9]{64}$/.test(lock.receiptVersion)?lock.receiptVersion:lock.version}`,old=oldPath===receiptPath?receipt:await tx.get(oldPath);
   if(old?.status==='sending'){
    const uncertain={...old,status:'uncertain',recoveredAtMillis:clock()};
    if(oldPath===receiptPath)receipt=uncertain;else tx.set(oldPath,uncertain);
   }
   // An expired worker cannot retain a shared lock forever. Email remains
   // uncertain/no-resend; Calendar may reconcile its stable event ID.
   if(oldPath===receiptPath&&kind==='email'&&receipt)tx.set(receiptPath,receipt);
   tx.set(lockPath,{...lock,status:'uncertain',...(lock.kind==='calendar'?{calendarDirty:true}:{})});
  }
  // Email never resends an ambiguous attempt. Calendar reconciliation may re-read
  // the stable event ID; a historical A receipt cannot stand for current B -> A.
  if(receipt&&(kind==='email'||receipt.status==='delivered'&&lock?.calendarVersion===current.version&&lock.calendarDirty===false))return{...current,receipt,reserved:false};
  const nextReceipt={schemaVersion:1,status:'sending',attempt,kind,version:current.version,atMillis:clock(),actorId:automatic?'google-booking-worker':auth!.uid,...(automatic?{notificationType:automatic.type,bookingRevision:automatic.revision}:{})};
  if(receipt)tx.set(receiptPath,nextReceipt);else tx.create(receiptPath,nextReceipt);
  tx.set(lockPath,{...lock,status:'sending',attempt,version:current.version,receiptVersion,kind,atMillis:clock(),leaseUntilMillis:clock()+300000,...(kind==='calendar'?{calendarDirty:true}:{})});return{...current,reserved:true,receipt:undefined};
 });
 if(!reservation.reserved)return{status:String(reservation.receipt!.status)};
 let outcome:DocumentData;
 const guard=async()=>{await deps.authorize(org,reservation.booking.coachId);await store.transact(async tx=>{const current=await read(tx),lock=await tx.get(lockPath);if(current.version!==reservation.version||lock?.attempt!==attempt||lock.status!=='sending'||Number(lock.leaseUntilMillis)<=clock())throw new DomainError('failed-precondition','The synchronization lease or booking changed.');});};
 try{
  await deps.authorize(org,reservation.booking.coachId);await guard();
  const result=kind==='email'?(automatic?await deps.gateway.sendNotification!(reservation.booking,await deps.recipient(reservation.booking.memberId),automatic,guard):await deps.gateway.sendConfirmation(reservation.booking,await deps.recipient(reservation.booking.memberId),guard)):
   reservation.booking.status==='cancelled'?await deps.gateway.removeCalendar(reservation.booking,guard):await deps.gateway.putCalendar(reservation.booking,guard);
  const providerId='eventId'in result?result.eventId:result.messageId;if(typeof providerId!=='string'||!providerId||providerId.length>512)throw Error();outcome={status:'delivered',providerId};
 }catch{outcome={status:'uncertain'};}
 await store.transact(async tx=>{const receipt=await tx.get(receiptPath),lock=await tx.get(lockPath),b=await tx.get(root),mapping=await tx.get(coachCalendarPath(org,reservation.booking.coachId));
  if(receipt?.attempt!==attempt||lock?.attempt!==attempt)throw new DomainError('failed-precondition','Synchronization receipt needs review.');
  if(!b||version(b)!==reservation.version)outcome={...outcome,status:'reconciliation_required'};
  tx.set(receiptPath,{...receipt,...outcome,finishedAtMillis:clock()});tx.set(lockPath,{...lock,...outcome,...(kind==='calendar'&&outcome.status==='delivered'?{calendarVersion:reservation.version,calendarDirty:false}:{})});
  if(kind==='calendar'&&mapping)tx.set(coachCalendarPath(org,reservation.booking.coachId),{...mapping,lastDeliveryStatus:outcome.status,...(outcome.status==='delivered'?{lastSyncedAtMillis:clock()}:{})});
  if(kind==='email'&&mapping)tx.set(coachCalendarPath(org,reservation.booking.coachId),{...mapping,lastEmailDeliveryStatus:outcome.status,lastEmailAttemptAtMillis:clock()});
 });
 await store.transact(read);return{status:String(outcome.status)};
}
