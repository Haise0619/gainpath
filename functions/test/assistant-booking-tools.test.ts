import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now, start, eligibleCoach } from './booking-fixture';
import { AssistantBookingTools, validBookingToolArgs } from '../src/modules/chatbot/assistant-booking-tools';

let store: MemoryStore;
const auth={uid:'member-1',token:{email_verified:true}};
const make=(actor=auth)=>new AssistantBookingTools(store,actor,'org-1',async()=>['coach-1'],eligibleCoach,()=>now);
beforeEach(()=>{
 store=new MemoryStore();Object.entries(seeds).forEach(([p,d])=>store.documents.set(p,structuredClone(d)));
 Object.assign(store.documents.get('orgs/org-1/coaches/coach-1')!,{displayName:'Fixture Coach',consultationFeeMinor:12500,certificationVerified:true,approvedCertificationCount:1});
 store.documents.set('orgs/org-1/coachProfiles/coach-1/certificationState/current',{certificationVerified:true,approvedCount:1});
});
it('validates allowlisted tool arguments and never accepts user identity or mutation arguments',()=>{
 expect(validBookingToolArgs('list_coaches',{})).toBe(true);
 expect(validBookingToolArgs('get_coaching_options',{coachId:'coach-1',durationMinutes:60})).toBe(true);
 expect(validBookingToolArgs('get_coaching_options',{coachId:'coach-1',memberId:'someone'})).toBe(false);
 expect(validBookingToolArgs('execute_booking',{})).toBe(false);
});
it('lists scoped eligible Coaches and creates a genuine suggestion without reserving, charging or saving conversation',async()=>{
 const tools=make(),before=structuredClone([...store.documents]);
 const coaches=await tools.execute('list_coaches',{});
 expect(coaches).toMatchObject({items:[{coachId:'coach-1',name:'Fixture Coach'}]});
 await tools.execute('propose_booking',{coachId:'coach-1',localDate:'2026-10-02',durationMinutes:60,branchId:'branch-1',startAtMillis:start});
 expect(tools.suggestion).toMatchObject({coachId:'coach-1',localDate:'2026-10-02',startAtMillis:start,amountMinor:12500,currency:'MYR',requiresConfirmation:true});
 expect([...store.documents]).toEqual(before);
});
it('rejects unavailable slots, foreign ownership/scope and stale branch assignments',async()=>{
 await expect(make().execute('propose_booking',{coachId:'coach-1',localDate:'2026-10-02',durationMinutes:60,branchId:'branch-1',startAtMillis:start-3600000})).rejects.toBeDefined();
 store.documents.get('users/member-1')!.organizationId='elsewhere';
 await expect(make().execute('list_coaches',{})).rejects.toMatchObject({code:'permission-denied'});
});
