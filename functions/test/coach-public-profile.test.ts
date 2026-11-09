import { describe, expect, it } from 'vitest';
import { coachRatings } from '../src/modules/coaching/coach-rating-service';
import { MemoryStore } from './memory-store';
import { seeds } from './booking-fixture';
const auth={uid:'member-1',token:{email_verified:true}};
const input={schemaVersion:1,organizationId:'org-1',coachIds:['coach-1'],includePublicSummary:true};
const review={schemaVersion:1,bookingId:'b1',coachId:'coach-1',memberId:'member-1',stars:4,reviewText:'Clear and useful coaching.',reviewedAtMillis:100};
function fixture(){const s=new MemoryStore();for(const[p,d]of Object.entries(seeds))s.documents.set(p,structuredClone(d));s.documents.set('orgs/org-1/branches/branch-1',{status:'active',name:'Main gym'});s.documents.set('orgs/org-1/bookings/b1',{schemaVersion:1,bookingId:'b1',memberId:'member-1',coachId:'coach-1',status:'completed'});s.documents.set('orgs/org-1/bookings/b1/consultation/current',{schemaVersion:1,bookingId:'b1',memberId:'member-1',coachId:'coach-1'});return s;}
const reader={aggregate:async()=>({count:1,total:4}),countCompleted:async()=>23,latestReviews:async()=>[{id:'b1',data:review}]};
describe('Member public Coach profile statistics',()=>{
  it('returns real aggregates and canonical review text without private participant IDs or writes',async()=>{
    const s=fixture(),before=structuredClone([...s.documents]);const result=await coachRatings(s,auth,input,reader);
    expect(result.records[0]).toMatchObject({coachId:'coach-1',averageRating:4,reviewCount:1,completedSessions:23,recentReviews:[{stars:4,reviewText:'Clear and useful coaching.',reviewedAtMillis:100,authorLabel:'Verified member'}],branchNames:{'branch-1':'Main gym'}});
    expect(JSON.stringify(result)).not.toContain('member-1');expect(JSON.stringify(result)).not.toContain('b1');expect([...s.documents]).toEqual(before);
  });
  it('preserves true zero statistics and does not invent review text for old star-only entries',async()=>{
    const zero=await coachRatings(fixture(),auth,input,{...reader,aggregate:async()=>({count:0,total:0}),countCompleted:async()=>0,latestReviews:async()=>[]});expect(zero.records[0]).toMatchObject({completedSessions:0,reviewCount:0,averageRating:null,recentReviews:[]});
    const r=await coachRatings(fixture(),auth,input,{...reader,latestReviews:async()=>[{id:'b1',data:{...review,reviewText:undefined}}]});expect(r.records[0].recentReviews![0].reviewText).toBe('');
  });
  it('denies unpublished coaches and private-summary escalation before aggregation',async()=>{
    const s=fixture();s.documents.set('orgs/org-1/coaches/coach-1',{status:'inactive',branchIds:['branch-1']});await expect(coachRatings(s,auth,input,reader)).rejects.toMatchObject({code:'permission-denied'});
    await expect(coachRatings(fixture(),auth,{...input,includeAccountSummary:true},reader)).rejects.toMatchObject({code:'permission-denied'});
  });
  it('rejects invalid counts, unrelated review links and publication drift',async()=>{
    await expect(coachRatings(fixture(),auth,input,{...reader,countCompleted:async()=>-1})).rejects.toMatchObject({code:'failed-precondition'});
    const s=fixture();s.documents.get('orgs/org-1/bookings/b1')!.status='cancelled';await expect(coachRatings(s,auth,input,reader)).rejects.toMatchObject({code:'failed-precondition'});
    const drift=fixture();await expect(coachRatings(drift,auth,input,{...reader,countCompleted:async()=>{drift.documents.get('orgs/org-1/coaches/coach-1')!.status='inactive';return 1;}})).rejects.toMatchObject({code:'permission-denied'});
  });
});
