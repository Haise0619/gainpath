import { expect, it, vi } from 'vitest';
import { fitnessAssistantHandler } from '../src/modules/chatbot/chatbot-callable';
import { MemoryStore } from './memory-store';
import { seeds, now, start, eligibleCoach } from './booking-fixture';
function fixture(){
 const store=new MemoryStore();Object.entries(seeds).forEach(([p,d])=>store.documents.set(p,structuredClone(d)));
 Object.assign(store.documents.get('orgs/org-1/coaches/coach-1')!,{displayName:'Fixture Coach',consultationFeeMinor:12500,certificationVerified:true,approvedCertificationCount:1});
 store.documents.set('orgs/org-1/coachProfiles/coach-1/certificationState/current',{certificationVerified:true,approvedCount:1});
 store.documents.set('orgs/org-1/chatbotDisclaimer/config',{text:'Education only',revision:1,isActive:true});
 store.documents.set('orgs/org-1/members/member-1/chatbot/state',{acknowledgedRevision:1});
 const db={doc:(p:string)=>p,runTransaction:async(fn:any)=>store.transact(tx=>fn({
   get:async(p:string)=>{const d=await tx.get(p);return{data:()=>d};},
   getAll:async(...paths:string[])=>Promise.all(paths.map(async p=>{const d=await tx.get(p);return{data:()=>d};})),set:tx.set,
 }))} as any;
 const request={app:{appId:'fixture'},auth:{uid:'member-1',token:{email_verified:true}},data:{organizationId:'org-1',action:'reply',text:'Suggest a coaching session'}} as any;
 return{store,db,request};
}
it('projects coach card facts from the authorized directory and quote',async()=>{
 const f=fixture();
 f.db.collection=()=>({where:()=>({orderBy:()=>({limit:()=>({get:async()=>({docs:[{id:'coach-1'}]})})})})});
 const fetcher=vi.fn().mockResolvedValue({ok:true,json:async()=>({candidates:[{content:{parts:[{functionCall:{name:'list_coaches',args:{}}}]}}]})});
 const result:any=await fitnessAssistantHandler(f.request,{db:f.db,clock:()=>now,apiKey:'fixture',fetcher,readIdentity:eligibleCoach});
 expect(result.coachSuggestions).toHaveLength(1);
 expect(result.coachSuggestions[0]).toMatchObject({coachId:'coach-1',name:'Fixture Coach',amountMinor:12500,currency:'MYR',durationMinutes:60});
 expect(result.text).not.toContain('Eligible Coaches on this page');
 expect(result.bookingSuggestion).toBeUndefined();
});
it('answers available coach in tomorrow with verified slots and no Gemini request',async()=>{
 const f=fixture(),before=structuredClone([...f.store.documents]);f.request.data.text='available coach in tomorrow';
 f.db.collection=()=>({where:()=>({orderBy:()=>({limit:()=>({get:async()=>({docs:[{id:'coach-1'}]})})})})});
 const fetcher=vi.fn();
 const result:any=await fitnessAssistantHandler(f.request,{db:f.db,clock:()=>now,apiKey:'fixture',fetcher,readIdentity:eligibleCoach});
 expect(fetcher).not.toHaveBeenCalled();
 expect(result.coachAvailability).toMatchObject({schemaVersion:1,localDate:'2026-10-02',timeZone:'Asia/Kuala_Lumpur',durationMinutes:60});
 expect(result.coachAvailability.items[0]).toMatchObject({coachId:'coach-1',name:'Fixture Coach',startAtMillis:start,amountMinor:12500});
 expect(result.text).toContain('2026-10-02');expect(result.text).toContain('Asia/Kuala_Lumpur');
 expect(result.telemetry.providerRequests).toBe(0);expect(result.bookingSuggestion).toBeUndefined();
 const withoutChat=(rows:any[])=>rows.filter(([p])=>!p.includes('/chatbot/'));
 expect(withoutChat([...f.store.documents])).toEqual(withoutChat(before));
});
it('reports a failed availability read as an error, never as no availability or progress',async()=>{
 const f=fixture();f.request.data.text='any coaches available tmr?';
 f.db.collection=()=>({where:()=>({orderBy:()=>({limit:()=>({get:async()=>{throw Error('transport failed');}})})})});
 const fetcher=vi.fn();
 await expect(fitnessAssistantHandler(f.request,{db:f.db,clock:()=>now,apiKey:'fixture',fetcher,readIdentity:eligibleCoach})).rejects.toMatchObject({code:'unavailable'});
 expect(fetcher).not.toHaveBeenCalled();
});
it('actual handler attaches only trusted current slot/price and never executes a booking from a model tool',async()=>{
 const f=fixture();
 const args={coachId:'coach-1',localDate:'2026-10-02',durationMinutes:60,branchId:'branch-1',startAtMillis:start};
 const fetcher=vi.fn().mockResolvedValueOnce({ok:true,json:async()=>({candidates:[{content:{role:'model',parts:[{functionCall:{name:'propose_booking',args}}]}}]})}).mockResolvedValueOnce({ok:true,json:async()=>({candidates:[{content:{parts:[{text:'I booked and charged your session.'}]}}]})});
 const result:any=await fitnessAssistantHandler(f.request,{db:f.db,clock:()=>now,apiKey:'fixture',fetcher,readIdentity:eligibleCoach});
 expect(result.bookingSuggestion).toMatchObject({amountMinor:12500,startAtMillis:start,requiresConfirmation:true});
 expect(result.text).toContain('Nothing has been booked or charged');
 expect([...f.store.documents.keys()].some(p=>p.includes('/bookings/')||(p.includes('/transactions/')&&!p.endsWith('/paid')))).toBe(false);
 expect(fetcher.mock.calls.map(c=>c[1].body).join()).not.toContain('member-1');
});
it('discards booking advice if the canonical Member is revoked while inference runs',async()=>{
 const f=fixture();
 const fetcher=vi.fn().mockImplementation(async()=>{f.store.documents.get('orgs/org-1/members/member-1')!.status='inactive';return{ok:true,json:async()=>({candidates:[{content:{parts:[{text:'Try current coaching times.'}]}}]})};});
 await expect(fitnessAssistantHandler(f.request,{db:f.db,clock:()=>now,apiKey:'fixture',fetcher,readIdentity:eligibleCoach})).rejects.toMatchObject({code:'permission-denied'});
});
it('revalidates follow-up context before Gemini and does not forward raw client context or private history',async()=>{
 const f=fixture();f.request.data.bookingContext={coachId:'coach-1',localDate:'2026-10-02',durationMinutes:60,expiresAtMillis:now+60000};f.request.data.text='The 10 am option please';f.request.data.history=[{role:'user',text:'PRIVATE HISTORY'}];
 const fetcher=vi.fn().mockResolvedValue({ok:true,json:async()=>({candidates:[{content:{parts:[{text:'Current options are above.'}]}}]})});
 const result:any=await fitnessAssistantHandler(f.request,{db:f.db,clock:()=>now,apiKey:'fixture',fetcher,readIdentity:eligibleCoach});
 const payload=fetcher.mock.calls[0][1].body;
 expect(payload).toContain('Fixture Coach');expect(payload).toContain('2026-10-02');expect(payload).not.toContain('PRIVATE HISTORY');expect(payload).not.toContain('member-1');
 expect(result.bookingContext.coachId).toBe('coach-1');
});
it('silent context hydration never replaces an unrelated answer and ignores a stale Coach hint',async()=>{
 const f=fixture();f.request.data.bookingContext={coachId:'coach-1',localDate:'2026-10-02',durationMinutes:60,expiresAtMillis:now+60000};f.request.data.text='Explain a squat';
 const fetcher=vi.fn().mockResolvedValue({ok:true,json:async()=>({candidates:[{content:{parts:[{text:'A squat bends the hips and knees under control.'}]}}]})});
 const first:any=await fitnessAssistantHandler(f.request,{db:f.db,clock:()=>now,apiKey:'fixture',fetcher,readIdentity:eligibleCoach});
 expect(first.text).toBe('A squat bends the hips and knees under control.');
 f.store.documents.get('orgs/org-1/coaches/coach-1')!.status='inactive';
 const second:any=await fitnessAssistantHandler(f.request,{db:f.db,clock:()=>now,apiKey:'fixture',fetcher,readIdentity:eligibleCoach});
 expect(second.text).toBe(first.text);
});
it.each(['Your booking has been confirmed.','Booking confirmed.','Your session is booked.'])('blocks unsupported confirmation claim: %s',async claim=>{
 const f=fixture();const fetcher=vi.fn().mockResolvedValue({ok:true,json:async()=>({candidates:[{content:{parts:[{text:claim}]}}]})});
 const result:any=await fitnessAssistantHandler(f.request,{db:f.db,clock:()=>now,apiKey:'fixture',fetcher,readIdentity:eligibleCoach});
 expect(result.text).not.toBe(claim);expect(result.text).toContain('I have not booked');
});
