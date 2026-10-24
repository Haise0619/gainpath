import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now, start } from './booking-fixture';
import { deliverConfirmedBooking } from '../src/modules/coaching/booking-external-delivery';
let store:MemoryStore,calls:number;
const auth={uid:'member-1',token:{email_verified:true,email:'member@example.invalid'}};
const input={schemaVersion:1,organizationId:'org-1',bookingId:'booking',kind:'email',requestId:'delivery-1',expectedStartAtMillis:start,confirmed:true};
beforeEach(()=>{
 store=new MemoryStore();calls=0;Object.entries(seeds).forEach(([p,d])=>store.documents.set(p,structuredClone(d)));
 store.documents.set('orgs/org-1/bookings/booking',{schemaVersion:1,bookingId:'booking',organizationId:'org-1',memberId:'member-1',coachId:'coach-1',branchId:'branch-1',requestId:'hold',createdBy:'member-1',createdAtMillis:now,startAtMillis:start,endAtMillis:start+3600000,durationMinutes:60,status:'confirmed',holdExpiresAtMillis:now+900000,localDate:'2026-10-02',timeZone:'Asia/Kuala_Lumpur',policyVersion:'booking-v1'});
 store.documents.set('orgs/org-1/transactions/booking',{schemaVersion:1,environment:'sandbox',provider:'billplz',type:'CoachingBooking',currency:'MYR',amountMinor:12000,durationMinutes:60,organizationId:'org-1',bookingId:'booking',memberId:'member-1',coachId:'coach-1',branchId:'branch-1',paymentStatus:'cleared',fulfilmentStatus:'confirmed',coachName:'Coach',branchName:'Studio'});
});
const deps=()=>({authorizeConnection:async()=>{},gateway:{putCalendar:async()=>{calls++;return{eventId:'event'};},sendConfirmation:async(_b:unknown,to:string)=>{expect(to).toBe(auth.token.email);calls++;return{messageId:'message'};}}});
it('requires explicit confirmation and rejects forged recipients before external delivery',async()=>{
 await expect(deliverConfirmedBooking(store,auth,{...input,confirmed:false},deps(),()=>now)).rejects.toBeDefined();
 await expect(deliverConfirmedBooking(store,auth,{...input,recipient:'attacker@example.invalid'},deps(),()=>now)).rejects.toBeDefined();
 expect(calls).toBe(0);
});
it('delivers only a canonical own paid confirmed booking once across repeated requests',async()=>{
 expect(await deliverConfirmedBooking(store,auth,input,deps(),()=>now)).toMatchObject({status:'delivered'});
 await deliverConfirmedBooking(store,auth,{...input,requestId:'another-tap'},deps(),()=>now);
 expect(calls).toBe(1);
});
it('does not retry an uncertain email request',async()=>{
 const d=deps();d.gateway.sendConfirmation=async()=>{calls++;throw Error('timeout SECRET');};
 expect(await deliverConfirmedBooking(store,auth,input,d,()=>now)).toMatchObject({status:'uncertain'});
 await deliverConfirmedBooking(store,auth,{...input,requestId:'retry'},d,()=>now);
 expect(calls).toBe(1);
});
it('connection not authorized means zero provider calls and no delivery reservation',async()=>{
 const before=structuredClone([...store.documents]),d=deps();d.authorizeConnection=async()=>{throw Error('not connected');};
 await expect(deliverConfirmedBooking(store,auth,input,d,()=>now)).rejects.toBeDefined();
 expect([...store.documents]).toEqual(before);expect(calls).toBe(0);
});
