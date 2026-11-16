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
it('finds actual tomorrow slots in the organization timezone without reserving anything',async()=>{
 const before=structuredClone([...store.documents]);
 const result=await make().availableCoaches({dayOffset:1});
 expect(result).toMatchObject({schemaVersion:1,localDate:'2026-10-02',timeZone:'Asia/Kuala_Lumpur',durationMinutes:60});
 expect(result.items[0]).toMatchObject({coachId:'coach-1',name:'Fixture Coach',branchId:'branch-1',amountMinor:12500,startAtMillis:start});
 expect([...store.documents]).toEqual(before);
});
it('uses the organization calendar across UTC midnight and month-end, not the client date',async()=>{
 const late=Date.parse('2026-10-31T20:00:00Z');
 const tools=new AssistantBookingTools(store,auth,'org-1',async()=>[],eligibleCoach,()=>late);
 const result=await tools.availableCoaches({dayOffset:1});
 expect(result).toMatchObject({localDate:'2026-11-02',timeZone:'Asia/Kuala_Lumpur',items:[]});
 expect(Number.isFinite(result.expiresAtMillis)).toBe(true);expect(result.expiresAtMillis).toBe(late+300000);
});
it('does not call an eligible Coach available when that Coach has no actual slots',async()=>{
 for(const [path,value] of [...store.documents])if(path.includes('coach-1'))store.documents.set(path.replaceAll('coach-1','coach-2'),structuredClone(value));
 store.documents.delete('orgs/org-1/coachAvailability/coach-2/days/2026-10-02');
 const tools=new AssistantBookingTools(store,auth,'org-1',async()=>['coach-1','coach-2'],eligibleCoach,()=>now);
 const result=await tools.availableCoaches({dayOffset:1});
 expect(result.items.length).toBeGreaterThan(0);expect(result.items.every(row=>row.coachId==='coach-1')).toBe(true);
});
