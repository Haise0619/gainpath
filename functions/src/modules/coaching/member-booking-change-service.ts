import type { DocumentStore, DocumentData, TransactionPort } from '../../platform/firestore/store';
import { DomainError } from '../../platform/errors';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { requiredIdentifier, InputValidationError } from '../../platform/validation';
import { keyOf } from '../../platform/idempotency';
import { object, allowed, integer, localDate, SLOT } from './coach-availability-contracts';
import { storedBooking, bookingReview, type StoredBooking } from './booking-record';
import { currentBookingMembership, requireBookingOrganization, bookingCoachScope, coachEligibilityFailure, currentBookingPolicy, activeBookingReservations, bookingDaySnapshot } from './booking-validation';
import type { CoachIdentityReader } from './coach-profile-service';
import { getMemberBookingOptionsService } from './member-booking-options-service';
import { memberBusySlots } from './member-booking-conflicts';

type Auth = {uid:string;token:Record<string,unknown>} | undefined;
const NOTICE = {cancel:12*3600000,reschedule:24*3600000};
async function owner(tx:TransactionPort,org:string,uid:string,id:string) {
  const actor=await currentBookingMembership(tx,org,uid);
  await requireBookingOrganization(tx,org);
  const booking=storedBooking(await tx.get(`orgs/${org}/bookings/${id}`),org,id);
  if(actor.role!=='member'||booking.memberId!==uid)throw new DomainError('permission-denied','Only the booking Member may change this session.');
  return {actor,booking};
}
function payment(data:DocumentData|undefined,b:StoredBooking) {
  if(!data||data.schemaVersion!==1||data.organizationId!==b.organizationId||data.bookingId!==b.bookingId||data.memberId!==b.memberId||data.coachId!==b.coachId||data.branchId!==b.branchId||data.durationMinutes!==b.durationMinutes||data.environment!=='sandbox'||data.provider!=='billplz'||data.type!=='CoachingBooking'||data.paymentStatus!=='cleared'||data.fulfilmentStatus!=='confirmed'||data.currency!=='MYR'||!Number.isSafeInteger(data.amountMinor)||Number(data.amountMinor)<1||data.refundStatus!==undefined)throw new DomainError('failed-precondition','The confirmed payment needs Admin review before this booking can change.');
  return data;
}

export async function memberReschedulingOptions(store:DocumentStore,auth:Auth,raw:unknown,readIdentity:CoachIdentityReader,clock=Date.now){
  requireVerifiedEmail(auth);
  const d=object(raw);allowed(d,['schemaVersion','organizationId','bookingId','action','localDate']);
  if(d.schemaVersion!==1||d.action!=='options')throw new InputValidationError('Invalid replacement options request.');
  const org=requiredIdentifier(d.organizationId,'organizationId'),id=requiredIdentifier(d.bookingId,'bookingId');
  const {booking}=await store.transact(tx=>owner(tx,org,auth!.uid,id));
  return getMemberBookingOptionsService(store,auth,{schemaVersion:1,organizationId:org,coachId:booking.coachId,durationMinutes:booking.durationMinutes,rescheduleBookingId:id,...(d.localDate===undefined?{}:{localDate:d.localDate})},readIdentity,clock);
}

export async function memberBookingChange(store:DocumentStore,auth:Auth,raw:unknown,readIdentity:CoachIdentityReader,clock=Date.now) {
  requireVerifiedEmail(auth);
  const d=object(raw);allowed(d,['schemaVersion','organizationId','bookingId','action','requestId','expectedStartAtMillis','newStartAtMillis','reason']);
  if(d.schemaVersion!==1||!['cancel','reschedule'].includes(String(d.action)))throw new InputValidationError('Choose cancellation or rescheduling.');
  const action=d.action as keyof typeof NOTICE,org=requiredIdentifier(d.organizationId,'organizationId'),id=requiredIdentifier(d.bookingId,'bookingId'),uid=auth!.uid,requestId=requiredIdentifier(d.requestId,'requestId');
  const expected=integer(d.expectedStartAtMillis,1),target=action==='reschedule'?integer(d.newStartAtMillis,1):undefined;
  if(action==='cancel'&&d.newStartAtMillis!==undefined)throw new InputValidationError('Cancellation does not accept a replacement time.');
  const reason=typeof d.reason==='string'?d.reason.trim():'';
  if(!reason||reason.length>500||/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(reason))throw new InputValidationError('Enter a reason of 1–500 characters.');
  const root=`orgs/${org}`,path=`${root}/bookings/${id}`,receiptPath=`${root}/commandReceipts/${keyOf('memberBookingChange',uid,requestId)}`,fingerprint=keyOf(org,id,action,expected,target??null,reason);
  const prior=async(tx:TransactionPort)=>{
    const scope=await owner(tx,org,uid,id),receipt=await tx.get(receiptPath);
    if(receipt){
      if(receipt.fingerprint!==fingerprint||receipt.command!=='memberBookingChange'||receipt.actorId!==uid)throw new DomainError('already-exists','Request ID belongs to another booking change.');
      const result=object(receipt.result);
      if(result.requestId!==requestId||result.bookingId!==id||result.action!==action)throw bookingReview();
      return {...scope,result};
    }
    return {...scope,result:undefined};
  };
  const captured=await store.transact(prior);
  if(captured.result)return captured.result;
  const eligibility=action==='reschedule'?await coachEligibilityFailure(readIdentity,captured.booking.coachId):undefined;
  return store.transact(async tx=>{
    const {actor,booking:b,result:replayed}=await prior(tx);if(replayed)return replayed;
    const now=integer(clock(),1);
    if(b.status!=='confirmed')throw new DomainError('failed-precondition','Only confirmed sessions can use this change action.');
    if(b.startAtMillis!==expected)throw new DomainError('aborted','The booking changed. Reload its current schedule.');
    if(now<b.createdAtMillis||b.startAtMillis-now<NOTICE[action])throw new DomainError('failed-precondition',action==='cancel'?'Cancellation requires at least 12 hours before session start.':'Rescheduling requires at least 24 hours before session start.');
    const p=payment(await tx.get(`${root}/transactions/${id}`),b);
    const communicationPath=`${path}/communicationState/current`,communication=await tx.get(communicationPath);
    if(communication&&(communication.schemaVersion!==1||!Number.isSafeInteger(communication.count)||Number(communication.count)<0||Number(communication.count)>=1000000))throw bookingReview();
    const oldDayPath=`${root}/bookingDays/${keyOf(uid,b.localDate)}`,oldDay=await tx.get(oldDayPath);
    const oldReservations=activeBookingReservations(oldDay,uid,b.localDate,b.timeZone,now);
    if(!oldReservations.some(r=>r.bookingId===id&&r.status==='confirmed'))throw bookingReview();
    const oldLocks:{slot:number;path:string;data:DocumentData}[]=[];
    for(let slot=b.startAtMillis;slot<b.endAtMillis;slot+=SLOT){
      const lockPath=`${root}/slotLocks/${keyOf(b.coachId,slot)}`,lock=await tx.get(lockPath);
      if(!lock||lock.schemaVersion!==1||lock.bookingId!==id||lock.coachId!==b.coachId||lock.branchId!==b.branchId||lock.status!=='confirmed')throw bookingReview();
      oldLocks.push({slot,path:lockPath,data:lock});
    }
    let replacement: {date:string;end:number;day:Awaited<ReturnType<typeof bookingDaySnapshot>>;slots:number[]}|undefined;
    if(action==='reschedule'){
      if(eligibility)throw eligibility;
      if(target!<=now||target!%SLOT||target===b.startAtMillis||target!<b.holdExpiresAtMillis)throw new InputValidationError('Choose a different future half-hour start.');
      const coach=await bookingCoachScope(tx,org,b.coachId,actor.branchIds);
      if(!coach.permitted.includes(b.branchId))throw new DomainError('permission-denied','The original branch is no longer available.');
      const publication=await tx.get(`${root}/coaches/${b.coachId}`),cert=await tx.get(`${root}/coachProfiles/${b.coachId}/certificationState/current`);
      if(publication?.certificationVerified!==true||!Number.isSafeInteger(publication.approvedCertificationCount)||Number(publication.approvedCertificationCount)<1||cert?.certificationVerified!==true||!Number.isSafeInteger(cert.approvedCount)||Number(cert.approvedCount)<1)throw new DomainError('failed-precondition','The Coach must have approved credentials.');
      const policy=currentBookingPolicy(await tx.get(`${root}/settings/booking`));
      if(policy.timeZone!==b.timeZone)throw new DomainError('failed-precondition','The booking timezone needs Admin review.');
      const date=localDate(target!,policy.timeZone),end=target!+b.durationMinutes*60000;
      if(localDate(end-1,policy.timeZone)!==date)throw new InputValidationError('A session must stay within one local date.');
      const day=await bookingDaySnapshot(tx,org,b.coachId,uid,date,policy,coach.assigned,now,id);
      const slots=Array.from({length:b.durationMinutes/30},(_,i)=>target!+i*SLOT);
      const memberBlocked=await memberBusySlots(tx,org,uid,date,policy.timeZone,day.reservations);
      if(slots.some(slot=>memberBlocked.has(slot)))throw new DomainError('aborted','The replacement overlaps another session or active hold.');
      if(!day.windows.some(w=>w.branchId===b.branchId&&w.startAtMillis<=target!&&w.endAtMillis>=end))throw new DomainError('failed-precondition','No current availability covers this replacement.');
      if(slots.some(slot=>day.blocked.has(slot)))throw new DomainError('aborted','The replacement time is no longer available.');
      if(day.reservations.length>=policy.cap||day.dailyCapacityMinutes!==undefined&&day.blocked.size*30+b.durationMinutes>day.dailyCapacityMinutes)throw new DomainError('resource-exhausted','The replacement exceeds a daily booking limit.');
      replacement={date,end,day,slots};
    }
    // All validation and reads completed before any write. The atomic transaction
    // preserves the original reservation if any replacement check fails.
    let next:StoredBooking;
    if(replacement){
      next={...b,startAtMillis:target!,endAtMillis:replacement.end,localDate:replacement.date};
      storedBooking(next,org,id);
      for(const lock of oldLocks)if(!replacement.slots.includes(lock.slot))tx.set(lock.path,{...lock.data,status:'pending_hold',expiresAtMillis:now});
      for(const slot of replacement.slots)tx.set(`${root}/slotLocks/${keyOf(b.coachId,slot)}`,{schemaVersion:1,bookingId:id,coachId:b.coachId,branchId:b.branchId,status:'confirmed'});
      if(oldDayPath!==replacement.day.dayPath)tx.set(oldDayPath,{...oldDay,reservations:oldReservations.filter(r=>r.bookingId!==id)});
      tx.set(replacement.day.dayPath,{schemaVersion:1,memberId:uid,localDate:replacement.date,timeZone:b.timeZone,reservations:[...replacement.day.reservations,{bookingId:id,status:'confirmed',expiresAtMillis:b.holdExpiresAtMillis}]});
    }else{
      next={...b,status:'cancelled',resolution:'member_confirmed_cancelled',resolvedAtMillis:now,cancelledBy:uid,cancellationReason:reason};
      storedBooking(next,org,id);
      for(const lock of oldLocks)tx.set(lock.path,{...lock.data,status:'pending_hold',expiresAtMillis:now});
      tx.set(oldDayPath,{...oldDay,reservations:oldReservations.filter(r=>r.bookingId!==id)});
      tx.set(`${root}/transactions/${id}`,{...p,fulfilmentStatus:'reconciliation_required',resolutionReason:'member_cancelled',refundReviewRequired:true,reviewReason:reason,updatedAtMillis:now});
      tx.create(`${root}/transactions/${id}/events/${keyOf('member_cancellation',requestId)}`,{schemaVersion:1,environment:'sandbox',event:'resolution_required',atMillis:now,actorId:uid,reason:'Member cancellation; refund requires Admin/provider review'});
    }
    tx.set(path,next);
    const notice=action==='cancel'?`Member cancelled this session. Refund is pending Admin/provider review. Reason: ${reason}`:`Member rescheduled this session to ${next.localDate}, ${new Intl.DateTimeFormat('en-GB',{timeZone:next.timeZone,hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(next.startAtMillis)} (${next.timeZone}). Original paid price is unchanged. Reason: ${reason}`;
    const sequence=Number(communication?.count??0)+1;
    tx.set(`${path}/messages/${sequence}`,{schemaVersion:1,sequence,senderRole:'member',text:`[Automated Notice]: ${notice}`.slice(0,500),sentAtMillis:now});
    tx.set(communicationPath,{...communication,schemaVersion:1,count:sequence,updatedAtMillis:now});
    tx.create(`${root}/notifications/${keyOf('memberBookingChange',uid,requestId)}`,{schemaVersion:1,type:action==='cancel'?'member_cancellation':'member_reschedule',recipientId:b.coachId,title:action==='cancel'?'Session cancelled by Member':'Session rescheduled by Member',message:notice.slice(0,500),bookingId:id,createdAtMillis:now,read:false});
    const result={schemaVersion:1,requestId,bookingId:id,action,status:next.status,startAtMillis:next.startAtMillis,endAtMillis:next.endAtMillis,localDate:next.localDate,timeZone:next.timeZone,changedAtMillis:now,refundReviewRequired:action==='cancel'};
    tx.create(receiptPath,{schemaVersion:1,command:'memberBookingChange',actorId:uid,fingerprint,createdAtMillis:now,policyVersion:'member-notice-12h-24h-v1',before:{startAtMillis:b.startAtMillis,endAtMillis:b.endAtMillis,localDate:b.localDate},result,reason});
    return result;
  });
}
