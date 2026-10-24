import {beforeEach,afterEach,expect,it,vi} from 'vitest';
import {Timestamp} from 'firebase-admin/firestore';
import {createHash} from 'node:crypto';
import {seeds,now,start} from './booking-fixture';
const state=vi.hoisted(()=>({db:{} as any,config:{} as any}));
vi.mock('firebase-admin/firestore',async()=>({...await vi.importActual<any>('firebase-admin/firestore'),getFirestore:()=>state.db}));
vi.mock('firebase-admin/auth',()=>({getAuth:()=>({getUser:async()=>({email:'member@example.com',emailVerified:true,disabled:false})})}));
vi.mock('../src/modules/coaching/google-automation-config',()=>({googleAutomationConfig:()=>state.config}));
vi.mock('../src/modules/coaching/google-gym-runtime',async()=>({...await vi.importActual<any>('../src/modules/coaching/google-gym-runtime'),googleGymServices:(store:any)=>({store,connection:{access:async()=>({accessToken:'TOKEN',subject:'subject',senderEmail:'gym@example.com',connectionId:'secret'})}})}));
import {synchronizeGoogleBooking} from '../src/modules/coaching/automatic-google-worker';
let docs:Map<string,any>,stamp:Timestamp,fetcher:ReturnType<typeof vi.fn>;
const root='orgs/org-1/bookings/booking',connection='system/googleGym/orgs/org-1';
const event=()=>({id:'event-1',params:{organizationId:'org-1',bookingId:'booking'},data:{before:{data:()=>({...docs.get(root),status:'pending_hold'})},after:{data:()=>docs.get(root),updateTime:Timestamp.fromMillis(now)}}} as any);
beforeEach(()=>{
 vi.spyOn(Date,'now').mockReturnValue(now);stamp=Timestamp.fromMillis(now);state.config={enabled:true,organizationId:'org-1',activatedAtMillis:now-1000,allowedRecipients:['member@example.com'],testCoachId:'coach-1',testBookingId:'booking'};
 docs=new Map(Object.entries(structuredClone(seeds)));docs.set(root,{schemaVersion:1,bookingId:'booking',organizationId:'org-1',memberId:'member-1',coachId:'coach-1',branchId:'branch-1',requestId:'hold',createdBy:'member-1',createdAtMillis:now,startAtMillis:start,endAtMillis:start+3600000,durationMinutes:60,status:'confirmed',holdExpiresAtMillis:now+900000,localDate:'2026-10-02',timeZone:'Asia/Kuala_Lumpur',policyVersion:'v1'});
 docs.set('orgs/org-1/transactions/booking',{schemaVersion:1,environment:'sandbox',provider:'billplz',type:'CoachingBooking',currency:'MYR',amountMinor:12000,durationMinutes:60,organizationId:'org-1',bookingId:'booking',memberId:'member-1',coachId:'coach-1',branchId:'branch-1',paymentStatus:'cleared',fulfilmentStatus:'confirmed',coachName:'Coach',branchName:'Gym'});
 docs.set(connection,{status:'connected',subject:'subject',secretId:'secret'});docs.set(connection+'/calendars/coach-1',{coachId:'coach-1',status:'ready',subject:'subject',calendarId:'calendar'});
 const snapshot=(p:string)=>({data:()=>docs.get(p),updateTime:p===root?stamp:Timestamp.fromMillis(now)});
 state.db={doc:(p:string)=>({path:p,get:async()=>snapshot(p)}),runTransaction:async(work:any)=>{let writing=false;return work({get:async(ref:any)=>{if(writing)throw Error('read after write');return snapshot(ref.path);},set:(ref:any,d:any)=>{writing=true;docs.set(ref.path,d);},create:(ref:any,d:any)=>{writing=true;if(docs.has(ref.path))throw Error('exists');docs.set(ref.path,d);}})}};
 fetcher=vi.fn(async(url:string,init:any)=>{if(url.includes('gmail'))return new Response(JSON.stringify({id:'gmail-message'}));if(init.method==='GET')return new Response(null,{status:404});return new Response(JSON.stringify({id:JSON.parse(init.body).id}));});vi.stubGlobal('fetch',fetcher);
});
afterEach(()=>{vi.restoreAllMocks();vi.unstubAllGlobals();});
it('disabled mode performs no provider writes or Firestore delivery writes for a real confirmation event',async()=>{state.config={...state.config,enabled:false};const before=structuredClone([...docs]);await synchronizeGoogleBooking.run(event());expect(fetcher).not.toHaveBeenCalled();expect([...docs]).toEqual(before);});
it('rejects other Coach, other booking and historical booking without provider or Firestore writes',async()=>{
 for(const c of [{...state.config,testCoachId:'different'},{...state.config,testBookingId:'different'},{...state.config,testBookingId:''}]){state.config=c;const before=structuredClone([...docs]);await synchronizeGoogleBooking.run(event());expect(fetcher).not.toHaveBeenCalled();expect([...docs]).toEqual(before);}
 state.config={...state.config,testCoachId:'coach-1',testBookingId:'booking'};docs.get(root).createdAtMillis=now-1001;const before=structuredClone([...docs]);await synchronizeGoogleBooking.run(event());expect(fetcher).not.toHaveBeenCalled();expect([...docs]).toEqual(before);
});
it('stops provider mutation if the approved single-booking scope changes during Calendar lookup',async()=>{
 fetcher.mockImplementationOnce(async()=>{state.config={...state.config,testBookingId:'different'};return new Response(null,{status:404});});await synchronizeGoogleBooking.run(event());expect(fetcher).toHaveBeenCalledOnce();expect(docs.get(connection).automaticLastStatus).toBe('needs_review');
});
it('executes the enabled real trigger handler and reuses delivered receipts',async()=>{await synchronizeGoogleBooking.run(event());await synchronizeGoogleBooking.run(event());expect(fetcher.mock.calls.filter(([u])=>u.includes('gmail'))).toHaveLength(1);expect(fetcher.mock.calls.filter(([,i])=>i.method==='POST'&&!String(i.body).includes('raw'))).toHaveLength(1);expect(docs.get(connection).automaticLastStatus).toBe('delivered');});
it('stops Calendar mutation and email when automation is disabled after Calendar GET',async()=>{fetcher.mockImplementationOnce(async()=>{state.config={...state.config,enabled:false};return new Response(null,{status:404});});await synchronizeGoogleBooking.run(event());expect(fetcher).toHaveBeenCalledOnce();expect(docs.get(connection).automaticLastStatus).toBe('needs_review');});
it('acks stale revisions without applying any provider change',async()=>{stamp=Timestamp.fromMillis(now+1);await synchronizeGoogleBooking.run(event());expect(fetcher).not.toHaveBeenCalled();});
it('never emails stale session times if the booking revision changes during Calendar IO',async()=>{
 fetcher.mockImplementation(async(_url:string,init:any)=>{if(init.method==='GET')return new Response(null,{status:404});stamp=Timestamp.fromMillis(now+1);return new Response(JSON.stringify({id:JSON.parse(init.body).id}));});
 await synchronizeGoogleBooking.run(event());expect(fetcher.mock.calls.filter(([u])=>u.includes('gmail'))).toHaveLength(0);
 const receipts=[...docs].filter(([p])=>p.includes('/externalDelivery/'));expect(receipts).toHaveLength(1);expect(receipts[0][1].status).toBe('sending');
 // A newer event must recover the fenced lease; this stale invocation must not
 // claim success or release another worker's lock after canonical state changed.
 expect(docs.get(connection).automaticLastStatus).toBeUndefined();
});
it('retries busy leases, then recovers an abandoned email without sending it again',async()=>{
 const b=docs.get(root),version=createHash('sha256').update(JSON.stringify([b.coachId,b.branchId,b.startAtMillis,b.endAtMillis,b.status])).digest('hex');const lock='system/googleBookingSync/bookings/'+createHash('sha256').update('org-1/booking').digest('hex'),receipt=root+'/externalDelivery/gym-email-'+version;
 docs.set(lock,{status:'sending',kind:'email',version,leaseUntilMillis:now+1000});docs.set(receipt,{status:'sending'});
 await expect(synchronizeGoogleBooking.run(event())).rejects.toThrow('requires reconciliation');expect(fetcher).not.toHaveBeenCalled();
 docs.get(lock).leaseUntilMillis=now-1;await synchronizeGoogleBooking.run(event());expect(fetcher.mock.calls.filter(([u])=>u.includes('gmail'))).toHaveLength(0);expect(docs.get(receipt).status).toBe('uncertain');expect(docs.get(connection).automaticLastStatus).toBe('email_needs_review');
});
