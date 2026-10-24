import {createHash} from 'node:crypto';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
import {onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {DomainError} from '../../platform/errors';
import {googleGymServices,googleGymClientSecret,googleGymRuntimeAccount} from './google-gym-runtime';
import {coachCalendarPath,gymConnectionPath} from './google-gym-connection';
import {GoogleBookingGateway} from './google-booking-delivery';
import {automaticBookingChange,automaticBookingInScope,deliverAutomaticBooking} from './automatic-google-delivery';
import {googleAutomationConfig} from './google-automation-config';

/** Prepared locally only. Default off; activation and trigger IAM require owner approval. */
export const synchronizeGoogleBooking=onDocumentUpdated({document:'orgs/{organizationId}/bookings/{bookingId}',region:'us-central1',retry:true,timeoutSeconds:120,maxInstances:3,concurrency:1,secrets:[googleGymClientSecret],serviceAccount:googleGymRuntimeAccount},async event=>{
 const config=googleAutomationConfig(),change=event.data,org=event.params.organizationId,id=event.params.bookingId;
 if(!config.enabled||!change||org!==config.organizationId)return;
 const before=change.before.data(),after=change.after.data(),stamp=change.after.updateTime;
 if(!before||!after||!stamp||!automaticBookingChange(before,after))return;
 const eventAtMillis=stamp.toMillis();
 if(!Number.isFinite(config.activatedAtMillis)||eventAtMillis<config.activatedAtMillis||Date.now()-eventAtMillis>3600000)return;
 const revision=stamp.seconds+'.'+stamp.nanoseconds,deliveryEvent={organizationId:org,bookingId:id,revision,eventAtMillis,before,after};
 if(!automaticBookingInScope(deliveryEvent,config))return;
 const db=getFirestore(),root=`orgs/${org}/bookings/${id}`;
 const current=()=>db.doc(root).get();
 const assertCurrent=async()=>{if(!(await current()).updateTime?.isEqual(stamp))throw new DomainError('aborted','Booking revision changed.');};
 // Transactional revision checking also runs inside every coordinator guard.
 const store=new FirestoreStore(db,{path:root,updateTime:stamp}),{connection}=googleGymServices(store);
 const authorize=async()=>{const c=googleAutomationConfig();if(!automaticBookingInScope(deliveryEvent,c)||c.activatedAtMillis!==config.activatedAtMillis||c.allowedRecipients[0].toLowerCase()!==config.allowedRecipients[0].toLowerCase())throw new DomainError('permission-denied','Automatic delivery scope is unavailable.');await assertCurrent();await store.transact(async tx=>{const grant=await tx.get(gymConnectionPath(org));if(grant?.status!=='connected')throw new DomainError('failed-precondition','Google connection is unavailable.');});};
 const gateway=new GoogleBookingGateway(async(kind,b)=>{
  await authorize();const access=await connection.access(org);
  const mapping=await store.transact(tx=>tx.get(coachCalendarPath(org,b.coachId)));
  if(kind==='calendar'&&(mapping?.status!=='ready'||mapping.subject!==access.subject||mapping.coachId!==b.coachId||typeof mapping.calendarId!=='string'))throw new DomainError('failed-precondition','Coach calendar needs Admin setup.');
  return{accessToken:access.accessToken,senderEmail:access.senderEmail,assertCurrent:async()=>{await store.transact(async tx=>{const c=await tx.get(gymConnectionPath(org));if(c?.status!=='connected'||c.secretId!==access.connectionId||c.subject!==access.subject)throw new DomainError('permission-denied','Google connection changed.');});},...(kind==='calendar'?{calendarId:String(mapping!.calendarId)}:{})};
 });
 const summary=async(status:string)=>{await new FirestoreStore(db).transact(async tx=>{const p=gymConnectionPath(org),c=await tx.get(p);if(c)tx.set(p,{...c,automaticLastStatus:status,automaticLastAttemptAtMillis:Date.now(),automaticLastEvent:createHash('sha256').update(event.id).digest('hex')});});};
 try{
  const result=await deliverAutomaticBooking(store,deliveryEvent,config,{gateway,authorize,assertCurrent,
   recipient:async uid=>{const u=await getAuth().getUser(uid);if(u.disabled||!u.emailVerified||!u.email)throw new DomainError('failed-precondition','Member email must be verified.');return u.email;}});
  await summary(result.status==='skipped'?'skipped':result.email==='uncertain'||result.email==='reconciliation_required'?'email_needs_review':'delivered');
 }catch(error){
  // Stale booking updates must never roll Calendar back or notify old times.
  if(!(await current()).updateTime?.isEqual(stamp))return;
  await summary('needs_review');
  if(error instanceof DomainError&&['permission-denied','failed-precondition','not-found','invalid-argument'].includes(error.code))return;
  // Eventarc retries remain bounded by the one-hour event age gate above.
  throw new Error('Automatic Google delivery requires reconciliation.');
 }
});
