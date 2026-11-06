import {expect,it} from 'vitest';
import {buildUnifiedSampleBusiness,aggregateUnifiedSampleBusiness} from '../src/modules/dataset/unified-sample-business';
const now=Date.UTC(2026,10,4,0,34),members=Array.from({length:18},(_,i)=>`member-${i+1}`),coaches=Array.from({length:7},(_,i)=>`coach-${i+1}`);
const input={anchorAtMillis:now,memberIds:members,coachIds:coaches,programIds:['program-a','program-b','program-c'],plans:[{id:'basic' as const,name:'Basic',amountMinor:5900,durationDays:30,version:'v1'},{id:'premium' as const,name:'Premium',amountMinor:9900,durationDays:30,version:'v1'}]};
it('creates one deterministic coherent simulation without financial entitlements or provider claims',()=>{
 const a=buildUnifiedSampleBusiness(input);expect(a).toEqual(buildUnifiedSampleBusiness(input));expect(new Set(a.map(x=>x.id)).size).toBe(a.length);
 expect(a.filter(x=>x.kind==='subscription')).toHaveLength(18);expect(a.filter(x=>x.kind==='appointment')).toHaveLength(24);expect(a.filter(x=>x.kind==='program_relationship')).toHaveLength(18);
 const text=JSON.stringify(a);for(const key of ['billId','paymentStatus','providerReference','wallet','clearedAtMillis'])expect(text).not.toContain(`"${key}"`);
 expect(a.every(x=>x.provenance==='fyp_business_simulation'&&x.currency==='MYR')).toBe(true);
});
it('has known-answer membership/coaching totals, excludes cancelled appointments and uses one date range',()=>{
 const rows=buildUnifiedSampleBusiness(input),r=aggregateUnifiedSampleBusiness(rows,{startAtMillis:Date.UTC(2026,7,31,16),endAtMillis:now},now);
 expect(r.simulatedRevenueMinor).toBe(18*5900+17*9900+16*8000);expect(r.membershipRevenueMinor).toBe(18*5900+17*9900);expect(r.coachingRevenueMinor).toBe(16*8000);
 expect(r.appointments).toEqual({total:24,completed:16,cancelled:8});expect(r.subscriptions.total).toBe(18);expect(r.subscriptions.expired).toBe(1);
 expect(r.monthly.reduce((n,x)=>n+x.amountMinor,0)).toBe(r.simulatedRevenueMinor);
 const nov=aggregateUnifiedSampleBusiness(rows,{startAtMillis:Date.UTC(2026,9,31,16),endAtMillis:now},now);expect(nov.membershipRevenueMinor).toBe(6*5900+5*9900);expect(nov.coachingRevenueMinor).toBe(0);
});
it('rejects duplicate/foreign identities, invalid prices, invalid dates and oversized catalogs',()=>{
 for(const extra of [{memberIds:[...members,members[0]]},{plans:[{...input.plans[0],amountMinor:-1},input.plans[1]]},{anchorAtMillis:NaN},{coachIds:[]},{memberIds:Array.from({length:201},(_,i)=>'m'+i)}])expect(()=>buildUnifiedSampleBusiness({...input,...extra})).toThrow();
});
it('rejects duplicate/unknown rows, unsupported assertions and source-reference drift rather than returning partial money',()=>{
 const rows=buildUnifiedSampleBusiness(input);for(const bad of [[...rows,rows[0]],rows.map((r,i)=>i===0?{...r,provider:'billplz'}:r),rows.map(r=>r.kind==='ledger'&&r.stream==='coaching'?{...r,appointmentId:'missing'}:r)])expect(()=>aggregateUnifiedSampleBusiness(bad as never,{startAtMillis:0,endAtMillis:now},now)).toThrow();
});
