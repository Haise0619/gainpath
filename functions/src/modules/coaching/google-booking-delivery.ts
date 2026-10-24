import { createHash } from 'node:crypto';
import { DomainError } from '../../platform/errors';

export interface DeliveryBooking {
 organizationId:string;bookingId:string;coachId:string;memberId:string;status:string;
 startAtMillis:number;endAtMillis:number;timeZone:string;coachName:string;branchName:string;
}
interface GoogleConnection {accessToken:string;calendarId?:string;senderEmail?:string;assertCurrent?:()=>Promise<void>}
export interface BookingEmailNotification {type:'confirmed'|'rescheduled'|'cancelled';revision:string;previousStartAtMillis?:number;previousEndAtMillis?:number}
const email=(v:string)=>/^[A-Za-z0-9.!#$%&'*+\/= ?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(v)&&!/[\s\r\n]/.test(v)&&v.length<=254;
const failure=()=>new DomainError('unavailable','Google delivery outcome is not confirmed. Reconcile the original attempt before retrying.');

/** Provider adapter only. Not exported as a Callable or registered as an AI tool.
 * The future delivery coordinator must supply canonical paid booking data,
 * an authorized server-side connection and a persisted send-once receipt.
 * Never pass model arguments, client tokens or arbitrary recipients here.
 */
export class GoogleBookingGateway {
 constructor(private connection:(kind:'calendar'|'email',booking:DeliveryBooking)=>Promise<GoogleConnection>,private fetcher:typeof fetch=fetch){}
 private connectionGuard(c:GoogleConnection,guard?:()=>Promise<void>){return async()=>{if(guard)await guard();if(c.assertCurrent)await c.assertCurrent();};}
 private validate(b:DeliveryBooking){
   if(b.status!=='confirmed'||!['organizationId','bookingId','coachId','memberId'].every(k=>typeof b[k as keyof DeliveryBooking]==='string'&&/^[\w-]{1,128}$/.test(b[k as keyof DeliveryBooking] as string))
     ||!Number.isSafeInteger(b.startAtMillis)||!Number.isSafeInteger(b.endAtMillis)||b.startAtMillis<=0||![1800000,3600000].includes(b.endAtMillis-b.startAtMillis))throw new DomainError('failed-precondition','Only a confirmed coaching session may be delivered.');
   try{new Intl.DateTimeFormat('en-GB',{timeZone:b.timeZone}).format(b.startAtMillis);}catch{throw new DomainError('failed-precondition','Invalid booking timezone.');}
 }
 calendarEvent(b:DeliveryBooking){
   this.validate(b);
   return {id:'gp'+createHash('sha256').update(JSON.stringify([b.organizationId,b.bookingId])).digest('hex'),summary:'GainPath coaching session',location:b.branchName.slice(0,120),
     description:'Coaching session arranged in GainPath. Check GainPath for authoritative booking and payment status.',
     start:{dateTime:new Date(b.startAtMillis).toISOString(),timeZone:b.timeZone},end:{dateTime:new Date(b.endAtMillis).toISOString(),timeZone:b.timeZone},
     extendedProperties:{private:{gainpathOrg:b.organizationId,gainpathBooking:b.bookingId}},visibility:'private'};
 }
 private async request(url:string,token:string,method:string,body?:unknown,etag?:string,guard?:()=>Promise<void>){
   if(!token||/[\r\n]/.test(token))throw new DomainError('failed-precondition','Google connection is unavailable.');
   try{
     if(guard)await guard();
     return await this.fetcher(url,{method,redirect:'error',signal:AbortSignal.timeout(10000),headers:{Authorization:'Bearer '+token,...(body?{'Content-Type':'application/json'}:{}),...(etag?{'If-Match':etag}:{})},...(body?{body:JSON.stringify(body)}:{})});
   }catch{throw failure();}
 }
 async putCalendar(b:DeliveryBooking,guard?:()=>Promise<void>){
   const event=this.calendarEvent(b),c=await this.connection('calendar',b);
   guard=this.connectionGuard(c,guard);
   if(!c.calendarId||c.calendarId.length>512)throw new DomainError('failed-precondition','Connect the authorized Calendar first.');
   const root='https://www.googleapis.com/calendar/v3/calendars/'+encodeURIComponent(c.calendarId)+'/events';
   const existing=await this.request(root+'/'+event.id,c.accessToken,'GET',undefined,undefined,guard);
   if(existing.ok){
     const saved=await existing.json() as any;
     if(saved.id!==event.id||saved.extendedProperties?.private?.gainpathOrg!==b.organizationId||saved.extendedProperties?.private?.gainpathBooking!==b.bookingId||saved.status==='cancelled')throw new DomainError('failed-precondition','Calendar event needs authorized review.');
     if(saved.start?.dateTime===event.start.dateTime&&saved.end?.dateTime===event.end.dateTime)return {eventId:event.id};
     if(typeof saved.etag!=='string'||/[\r\n]/.test(saved.etag))throw failure();
     const {id:_,...patch}=event;
     const updated=await this.request(root+'/'+event.id+'?sendUpdates=none',c.accessToken,'PATCH',patch,saved.etag,guard);
     if(!updated.ok)throw failure();
     const value=await updated.json() as any;if(value.id!==event.id)throw failure();return{eventId:event.id};
   }
   if(existing.status!==404)throw failure();
   const created=await this.request(root+'?sendUpdates=none',c.accessToken,'POST',event,undefined,guard);
   // A conflict/timeout is reconciled by the coordinator using the stable ID.
   // Do not recursively create or issue another event here.
   if(!created.ok)throw failure();
   const value=await created.json() as any;if(value.id!==event.id)throw failure();return{eventId:event.id};
 }
 async sendConfirmation(b:DeliveryBooking,recipient:string,guard?:()=>Promise<void>){
   return this.sendNotification(b,recipient,{type:'confirmed',revision:'confirmation'},guard);
 }
 async sendNotification(b:DeliveryBooking,recipient:string,notice:BookingEmailNotification,guard?:()=>Promise<void>){
   if(!['confirmed','rescheduled','cancelled'].includes(notice.type)||!notice.revision||notice.revision.length>256||notice.type==='cancelled'&&b.status!=='cancelled')throw new DomainError('failed-precondition','Invalid booking notification.');
   this.validate(notice.type==='cancelled'?{...b,status:'confirmed'}:b);if(!email(recipient))throw new DomainError('invalid-argument','Invalid verified recipient.');
   if(notice.type==='rescheduled'&&(!Number.isSafeInteger(notice.previousStartAtMillis)||!Number.isSafeInteger(notice.previousEndAtMillis)||Number(notice.previousEndAtMillis)<=Number(notice.previousStartAtMillis)))throw new DomainError('failed-precondition','Previous session time is required.');
   const c=await this.connection('email',b);if(!c.senderEmail||!email(c.senderEmail))throw new DomainError('failed-precondition','Connect the authorized sender first.');
   guard=this.connectionGuard(c,guard);
   const format=new Intl.DateTimeFormat('en-GB',{timeZone:b.timeZone,dateStyle:'medium',timeStyle:'short'});
   const previous=notice.type==='rescheduled'?`Previous start: ${format.format(notice.previousStartAtMillis!)}\nPrevious end: ${format.format(notice.previousEndAtMillis!)}\n`:'';
   const text=`Your GainPath coaching session is ${notice.type}.\nCoach: ${b.coachName.slice(0,120)}\nLocation: ${b.branchName.slice(0,120)}\n${previous}Start: ${format.format(b.startAtMillis)}\nEnd: ${format.format(b.endAtMillis)}\nTimezone: ${b.timeZone}\n${notice.type==='cancelled'?'Refunds are subject to review in GainPath; this email does not confirm a refund.\n':''}Check GainPath for the current session and payment status.`;
   const messageId=createHash('sha256').update(JSON.stringify([b.organizationId,b.bookingId,b.startAtMillis,notice.type==='confirmed'?'confirmation':notice.type, ...(notice.type==='confirmed'?[]:[notice.revision])])).digest('hex');
   const subject=notice.type==='confirmed'?'confirmation':notice.type;
   const mime=[`From: ${c.senderEmail}`,`To: ${recipient}`,`Subject: GainPath session ${subject}`,`Message-ID: <${messageId}@gainpath.invalid>`,'MIME-Version: 1.0','Content-Type: text/plain; charset=UTF-8','Content-Transfer-Encoding: base64','',Buffer.from(text).toString('base64')].join('\r\n');
   const r=await this.request('https://gmail.googleapis.com/gmail/v1/users/me/messages/send',c.accessToken,'POST',{raw:Buffer.from(mime).toString('base64url')},undefined,guard);
   if(!r.ok)throw failure();
   const result=await r.json() as any;if(typeof result.id!=='string'||!result.id)throw failure();
   return {messageId:result.id}; // Gmail has no send idempotency guarantee; receipt required above this adapter.
 }
 async removeCalendar(b:DeliveryBooking,guard?:()=>Promise<void>){
   if(b.status!=='cancelled')throw new DomainError('failed-precondition','Only a cancelled booking may remove an event.');
   const event=this.calendarEvent({...b,status:'confirmed'}),c=await this.connection('calendar',b);
   guard=this.connectionGuard(c,guard);
   if(!c.calendarId||c.calendarId.length>512)throw new DomainError('failed-precondition','Calendar mapping is unavailable.');
   const url='https://www.googleapis.com/calendar/v3/calendars/'+encodeURIComponent(c.calendarId)+'/events/'+event.id;
   const r=await this.request(url,c.accessToken,'GET',undefined,undefined,guard);if(r.status===404||r.status===410)return{eventId:event.id};if(!r.ok)throw failure();
   const saved=await r.json() as any;
   if(saved.id!==event.id||saved.extendedProperties?.private?.gainpathOrg!==b.organizationId||saved.extendedProperties?.private?.gainpathBooking!==b.bookingId)throw new DomainError('failed-precondition','Calendar ownership needs review.');
   if(saved.status==='cancelled')return{eventId:event.id};if(typeof saved.etag!=='string'||/[\r\n]/.test(saved.etag))throw failure();
   const removed=await this.request(url+'?sendUpdates=none',c.accessToken,'DELETE',undefined,saved.etag,guard);
   if(!removed.ok&&removed.status!==404&&removed.status!==410)throw failure();return{eventId:event.id};
 }
}
