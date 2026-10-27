import {beforeEach,it,expect} from 'vitest';
import {MemoryStore} from './memory-store';
import {adminReport,type ReportingReader,type ReportRow} from '../src/modules/analytics/admin-reporting';
const now=Date.UTC(2026,9,26,6),start=Date.UTC(2026,9,24,16),end=Date.UTC(2026,9,25,16);
const auth={uid:'admin',token:{email_verified:true,auth_time:100}};
const input={schemaVersion:1,organizationId:'gainpath',startAtMillis:start,endAtMillis:end};
let store:MemoryStore, rows:Record<string,ReportRow[]>;
let scans=0;
const reader:ReportingReader={page:async(kind,after,limit)=>{scans++;return (rows[kind]??[]).filter(r=>after===undefined||r.id>after).slice(0,limit);}};
const run=()=>adminReport(store,auth,input,reader,()=>now);
const payment=(id:string,extra:Record<string,unknown>={}):ReportRow=>({id,data:{schemaVersion:1,organizationId:'gainpath',transactionId:id,memberId:'member',kind:'MembershipPurchase',environment:'sandbox',provider:'billplz',currency:'MYR',amountMinor:8900,durationDays:30,planId:'basic',billId:'bill-'+id,paymentStatus:'cleared',fulfilmentStatus:'confirmed',clearedAtMillis:start+1000,invoiceStatus:'paid',...extra}});
beforeEach(()=>{scans=0;store=new MemoryStore();rows={members:[],bookings:[],transactions:[]};store.documents.set('users/admin',{organizationId:'gainpath'});store.documents.set('orgs/gainpath',{status:'active'});store.documents.set('orgs/gainpath/members/admin',{organizationId:'gainpath',role:'admin',status:'active',branchIds:[]});});
it('returns real canonical active counts and no writes',async()=>{
  rows.members=[{id:'a',data:{organizationId:'gainpath',role:'member',status:'active'}},{id:'b',data:{organizationId:'gainpath',role:'coach',status:'active'}},{id:'c',data:{organizationId:'gainpath',role:'member',status:'inactive'}}];
  for(const id of ['a','b','c'])store.documents.set('users/'+id,{organizationId:'gainpath'});
  const before=JSON.stringify([...store.documents]);const r=await run();
  expect(r.currentAccounts).toEqual({members:1,coaches:1});expect(JSON.stringify([...store.documents])).toBe(before);
  expect(r.unsupported).toContain('posture');
});
it('separates trusted confirmed receipts from pending, reconciliation and refunds',async()=>{
  rows.transactions=[payment('a'),payment('b',{kind:undefined,type:'CoachingBooking',transactionId:undefined,bookingId:'b',paymentVerifiedAtMillis:start+2000,clearedAtMillis:undefined,amountMinor:5000}),payment('c',{paymentStatus:'pending'}),payment('d',{fulfilmentStatus:'reconciliation_required'}),payment('e',{refundStatus:'approved'}),payment('f',{refundStatus:'completed'})];
  const r=await run();expect(r.receipts).toMatchObject({confirmedMinor:13900,membershipMinor:8900,coachingMinor:5000,confirmedCount:2,reviewMinor:17800,reviewCount:2,refundedMinor:8900,refundedCount:1});
  expect(r.daily.reduce((n,d)=>n+d.receiptsMinor,0)).toBe(13900);
});
it('Malaysia instants are start-inclusive and end-exclusive; pending never earns',async()=>{
  rows.transactions=[payment('a',{clearedAtMillis:start-1}),payment('b',{clearedAtMillis:start}),payment('c',{clearedAtMillis:end}),payment('d',{paymentStatus:'pending'})];
  const r=await run();expect(r.receipts.confirmedMinor).toBe(8900);expect(r.daily[0].date).toBe('2026-10-25');
});
it('bookings are created-in-window counts and scheduled starts are separate',async()=>{
  rows.bookings=[{id:'a',data:{schemaVersion:1,organizationId:'gainpath',bookingId:'a',status:'confirmed',createdAtMillis:start,startAtMillis:end+1000}},
    {id:'b',data:{schemaVersion:1,organizationId:'gainpath',bookingId:'b',status:'completed',createdAtMillis:start-1000,startAtMillis:start+1000}}];
  const r=await run();expect(r.bookings.created).toBe(1);expect(r.bookings.scheduledStarts).toBe(1);expect(r.bookings.statuses.confirmed).toBe(1);expect(r.bookings.statuses.completed).toBe(0);
});
it('rejects Member/staff/unverified/foreign scopes before scans',async()=>{
  for(const role of ['member','staff','coach']){store.documents.set('orgs/gainpath/members/admin',{organizationId:'gainpath',role,status:'active',branchIds:[]});await expect(run()).rejects.toMatchObject({code:'permission-denied'});}
  expect(scans).toBe(0);
});
it('rejects changed canonical authority after scanning',async()=>{
  const changed:ReportingReader={page:async()=>{store.documents.set('users/admin',{organizationId:'other'});return[];}};
  await expect(adminReport(store,auth,input,changed,()=>now)).rejects.toMatchObject({code:'permission-denied'});
});
it('rejects unknown query fields, invalid dates and branch allocation',async()=>{
  for(const extra of [{startAtMillis:end,endAtMillis:start},{endAtMillis:now+2*86400000},{branchId:'branch'},{points:50}]){
    await expect(adminReport(store,auth,{...input,...extra},reader,()=>now)).rejects.toThrow('Invalid report dates or fields.');
  }
});
it('does not return partial totals on scan cap or duplicate source identities',async()=>{
  rows.members=Array.from({length:2001},(_,i)=>({id:String(i).padStart(5,'0'),data:{organizationId:'gainpath',role:'member',status:'inactive'}}));
  await expect(run()).rejects.toMatchObject({code:'resource-exhausted'});
  rows.members=[];const duplicate:ReportingReader={page:async()=>[{id:'same',data:{}},{id:'same',data:{}}]};
  await expect(adminReport(store,auth,input,duplicate,()=>now)).rejects.toMatchObject({code:'failed-precondition'});
});
it('malformed cleared money, foreign records and duplicate bills fail closed',async()=>{
  for(const payments of [[payment('a',{amountMinor:NaN})],[payment('a',{organizationId:'other'})],[payment('a'),payment('b',{billId:'bill-a'})]]){
    rows.transactions=payments;await expect(run()).rejects.toMatchObject({code:'failed-precondition'});
  }
});
it('canonical census never counts foreign or deactivating user records',async()=>{
  rows.members=[{id:'a',data:{organizationId:'gainpath',role:'member',status:'active'}},{id:'b',data:{organizationId:'gainpath',role:'member',status:'active'}}];
  store.documents.set('users/a',{organizationId:'other'});store.documents.set('users/b',{organizationId:'gainpath',accountLifecycle:{state:'deactivation_pending'}});
  expect((await run()).currentAccounts.members).toBe(0);
});
it('scheduled starts include confirmed appointments later today within the selected range',async()=>{
  rows.bookings=[{id:'future',data:{schemaVersion:1,organizationId:'gainpath',bookingId:'future',status:'confirmed',createdAtMillis:now-1000,startAtMillis:now+3600000}}];
  const r=await adminReport(store,auth,{...input,startAtMillis:now-10000,endAtMillis:now+7200000},reader,()=>now);
  expect(r.bookings.created).toBe(1);expect(r.bookings.scheduledStarts).toBe(1);
});
