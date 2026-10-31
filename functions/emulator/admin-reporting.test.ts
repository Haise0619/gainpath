import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,FieldPath,type Firestore} from 'firebase-admin/firestore';
import {beforeAll,afterAll,beforeEach,it,expect} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {adminReport,type ReportingReader} from '../src/modules/analytics/admin-reporting';
let app:App,db:Firestore;
const now=Date.UTC(2026,9,26,6),actor={uid:'admin',token:{email_verified:true,auth_time:100}},query={schemaVersion:1,organizationId:'gainpath',startAtMillis:Date.UTC(2026,9,24,16),endAtMillis:Date.UTC(2026,9,25,16)};
beforeAll(()=>{if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18088')throw Error('Dedicated loopback emulator required');app=initializeApp({projectId:'demo-gainpath-reporting'},'reporting');db=getFirestore(app);});
afterAll(async()=>{await db?.terminate();if(app)await deleteApp(app);});
beforeEach(async()=>{await fetch('http://127.0.0.1:18088/emulator/v1/projects/demo-gainpath-reporting/databases/(default)/documents',{method:'DELETE'});
 const b=db.batch();b.set(db.doc('users/admin'),{organizationId:'gainpath'});b.set(db.doc('orgs/gainpath'),{status:'active'});b.set(db.doc('orgs/gainpath/members/admin'),{organizationId:'gainpath',role:'admin',status:'active',branchIds:[]});await b.commit();});
const reader:ReportingReader={page:async(kind,after,limit)=>{let q=db.collection('orgs/gainpath/'+kind).orderBy(FieldPath.documentId()).limit(limit);if(after)q=q.startAfter(after);return(await q.get()).docs.map(d=>({id:d.id,data:d.data()}));}};
it('real document-id pages include every account exactly once without writes',async()=>{
 const b=db.batch();for(let i=0;i<270;i++){const id='member-'+String(i).padStart(3,'0');b.set(db.doc('users/'+id),{organizationId:'gainpath'});b.set(db.doc('orgs/gainpath/members/'+id),{organizationId:'gainpath',role:'member',status:'active'});}await b.commit();
 const before=await db.doc('orgs/gainpath/members/admin').get();
 const result=await adminReport(new FirestoreStore(db),actor,query,reader,()=>now);
 expect(result.currentAccounts.members).toBe(270);expect(result.sourceCounts.members).toBe(271);
 expect((await db.doc('orgs/gainpath/members/admin').get()).updateTime?.isEqual(before.updateTime!)).toBe(true);
 expect((await db.collection('orgs/gainpath/analytics').get()).empty).toBe(true);
});
it('aggregates real Sandbox server-owned cleared evidence without provider or ledger mutation',async()=>{
 const ref=db.doc('orgs/gainpath/transactions/tx');await ref.set({schemaVersion:1,organizationId:'gainpath',transactionId:'tx',kind:'MembershipPurchase',memberId:'member',environment:'sandbox',provider:'billplz',currency:'MYR',amountMinor:8900,billId:'bill',paymentStatus:'cleared',fulfilmentStatus:'confirmed',clearedAtMillis:query.startAtMillis+1000});
 const before=await ref.get(),r=await adminReport(new FirestoreStore(db),actor,query,reader,()=>now);
 expect(r.receipts.membershipMinor).toBe(8900);expect(r.daily[0].date).toBe('2026-10-25');expect((await ref.get()).updateTime?.isEqual(before.updateTime!)).toBe(true);
});
it('canonical organization drift during a real page read denies the result',async()=>{
 const changed:ReportingReader={page:async(kind,after,limit)=>{const rows=await reader.page(kind,after,limit);if(kind==='transactions')await db.doc('users/admin').update({organizationId:'other'});return rows;}};
 await expect(adminReport(new FirestoreStore(db),actor,query,changed,()=>now)).rejects.toMatchObject({code:'permission-denied'});
});
it('schema2 reads real consultation and review documents without source writes',async()=>{
 const id='session',root='orgs/gainpath/bookings/'+id,t=query.startAtMillis+1000;
 await db.doc(root).set({schemaVersion:1,organizationId:'gainpath',bookingId:id,coachId:'coach',memberId:'member',status:'completed',createdAtMillis:t,startAtMillis:t+1,endAtMillis:t+2});
 await db.doc(root+'/consultation/current').set({schemaVersion:1,organizationId:'gainpath',bookingId:id,coachId:'coach',memberId:'member',text:'Genuine emulator fixture consultation',publishedAtMillis:t+3});
 await db.doc(root+'/review/current').set({schemaVersion:1,bookingId:id,coachId:'coach',memberId:'member',stars:5,reviewedAtMillis:t+4});
 const before=await db.doc(root).get();const r=await adminReport(new FirestoreStore(db),actor,{...query,schemaVersion:2},reader,()=>now);
 expect(r.commerce?.coaches[0]).toMatchObject({bookings:1,completed:1,consultations:1,reviewCount:1,ratingSum:5});
 expect((await db.doc(root).get()).updateTime?.isEqual(before.updateTime!)).toBe(true);
 expect((await db.collection('orgs/gainpath/coachEarnings').get()).empty).toBe(true);
});
