import type {DocumentData,DocumentStore} from '../../platform/firestore/store';
import {DomainError} from '../../platform/errors';
import {syncAutomaticGymBooking,type SyncDependencies} from './gym-booking-sync';
import type {BookingEmailNotification} from './google-booking-delivery';
export interface AutomaticDeliveryConfig {enabled:boolean;organizationId:string;activatedAtMillis:number;allowedRecipients:readonly string[];testCoachId:string;testBookingId:string}
export interface BookingChangeEvent {organizationId:string;bookingId:string;revision:string;eventAtMillis:number;before:DocumentData;after:DocumentData}
const identifier=(v:unknown):v is string=>typeof v==='string'&&/^[\w-]{1,128}$/.test(v);
export function automaticScopeConfigured(config:AutomaticDeliveryConfig){
 return config.enabled&&identifier(config.organizationId)&&identifier(config.testCoachId)&&identifier(config.testBookingId)&&Number.isSafeInteger(config.activatedAtMillis)&&config.activatedAtMillis>0&&config.allowedRecipients.length===1&&typeof config.allowedRecipients[0]==='string'&&/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(config.allowedRecipients[0]);
}
export function automaticBookingInScope(event:BookingChangeEvent,config:AutomaticDeliveryConfig){
 return automaticScopeConfigured(config)&&event.organizationId===config.organizationId&&event.bookingId===config.testBookingId&&event.after.organizationId===config.organizationId&&event.after.bookingId===config.testBookingId&&event.after.coachId===config.testCoachId&&Number.isSafeInteger(event.after.createdAtMillis)&&Number(event.after.createdAtMillis)>=config.activatedAtMillis&&Number(event.after.createdAtMillis)<=event.eventAtMillis;
}
export function automaticBookingChange(before:DocumentData,after:DocumentData):BookingEmailNotification['type']|undefined{
 if(before.status==='pending_hold'&&after.status==='confirmed')return 'confirmed';
 if(before.status==='confirmed'&&after.status==='cancelled')return 'cancelled';
 if(before.status==='confirmed'&&after.status==='confirmed'&&(before.startAtMillis!==after.startAtMillis||before.endAtMillis!==after.endAtMillis))return 'rescheduled';
 return undefined;
}
export async function deliverAutomaticBooking(store:DocumentStore,event:BookingChangeEvent,config:AutomaticDeliveryConfig,deps:SyncDependencies&{assertCurrent():Promise<void>},clock=Date.now){
 const type=automaticBookingChange(event.before,event.after);
 if(!automaticBookingInScope(event,config)||!Number.isSafeInteger(event.eventAtMillis)||event.eventAtMillis<config.activatedAtMillis||event.eventAtMillis>clock()+60000||clock()-event.eventAtMillis>3600000||!type)return{status:'skipped'};
 if(!event.revision||event.revision.length>256)throw new DomainError('invalid-argument','Booking revision required.');
 await deps.assertCurrent();
 const notice:BookingEmailNotification={type,revision:event.revision,...(type==='rescheduled'?{previousStartAtMillis:Number(event.before.startAtMillis),previousEndAtMillis:Number(event.before.endAtMillis)}:{})};
 // Fail closed while controlled UAT is active: an empty allowlist sends no emails.
 const guarded={...deps,authorize:async(org:string,coach:string)=>{await deps.assertCurrent();await deps.authorize(org,coach);},recipient:async(uid:string)=>{const to=await deps.recipient(uid);if(!config.allowedRecipients.map(x=>x.toLowerCase()).includes(to.toLowerCase()))throw new DomainError('permission-denied','Recipient is outside automatic-delivery UAT scope.');return to;}};
 // Check recipient eligibility before reserving either channel. The coordinator
 // revalidates the current identity again immediately before its Gmail operation.
 await guarded.recipient(String(event.after.memberId));
 let calendar='blocked',calendarError:unknown;
 try{calendar=(await syncAutomaticGymBooking(store,event.organizationId,event.bookingId,'calendar',notice,guarded,clock)).status;}catch(e){calendarError=e;}
 const email=(await syncAutomaticGymBooking(store,event.organizationId,event.bookingId,'email',notice,guarded,clock)).status;
 // Retryable trigger failure can reconcile Calendar, but an existing Gmail
 // receipt (including uncertain) prevents a second send attempt.
 if(calendarError)throw calendarError;
 if(calendar==='uncertain'||calendar==='reconciliation_required')throw new DomainError('unavailable','Calendar needs reconciliation.');
 return{status:'processed',calendar,email};
}
