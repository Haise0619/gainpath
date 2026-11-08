import { describe, expect, it } from 'vitest';
import { coachRatings } from '../src/modules/coaching/coach-rating-service';
import { MemoryStore } from './memory-store';
import { seeds } from './booking-fixture';
const auth = {uid:'coach-1', token:{email_verified:true}};
const input = {schemaVersion:1, organizationId:'org-1', coachIds:['coach-1'], includeAccountSummary:true};
function fixture() { const store=new MemoryStore(); for(const [p,d] of Object.entries(seeds)) store.documents.set(p,structuredClone(d)); store.documents.set('orgs/org-1/branches/branch-1',{status:'active',name:'Main gym'}); return store; }
describe('Coach self account summary',()=>{
  it('preserves ordinary rating responses without reading private summaries',async()=>{
    const result=await coachRatings(fixture(),auth,{schemaVersion:1,organizationId:'org-1',coachIds:['coach-1']},{aggregate:async()=>({count:0,total:0}),countCompleted:async()=>{throw Error('Must not read private summary');}});
    expect(result).toEqual({schemaVersion:1,records:[{coachId:'coach-1',reviewCount:0,averageRating:null}]});
  });
  it('returns lifetime completed count and assigned branch names without writes',async()=>{
    const store=fixture(), before=structuredClone([...store.documents]);
    const result=await coachRatings(store,auth,input,{aggregate:async()=>({count:1,total:4}),countCompleted:async()=>23});
    expect(result.records[0]).toEqual({coachId:'coach-1',reviewCount:1,averageRating:4});
    expect(result.accountSummary).toEqual({completedSessions:23,branches:[{id:'branch-1',name:'Main gym'}]});
    expect([...store.documents]).toEqual(before);
  });
  it('rejects another coach or member requesting private summary before aggregation',async()=>{
    let called=false; const reader={aggregate:async()=>{called=true;return {count:0,total:0}},countCompleted:async()=>0};
    for(const actor of [{uid:'member-1',token:{email_verified:true}},auth]) {
      await expect(coachRatings(fixture(),actor,{...input,coachIds:['other']},reader)).rejects.toMatchObject({code:'permission-denied'});
    }
    expect(called).toBe(false);
  });
  it('rejects invalid counts and membership drift',async()=>{
    await expect(coachRatings(fixture(),auth,input,{aggregate:async()=>({count:0,total:0}),countCompleted:async()=>-1})).rejects.toMatchObject({code:'failed-precondition'});
    const store=fixture();
    await expect(coachRatings(store,auth,input,{aggregate:async()=>({count:0,total:0}),countCompleted:async()=>{store.documents.set('users/coach-1',{organizationId:'other'});return 1;}})).rejects.toMatchObject({code:'permission-denied'});
  });
});
