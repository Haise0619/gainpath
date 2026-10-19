import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { expireBookingHoldService } from '../src/modules/coaching/booking-lifecycle-service';
import { createBookingPayment, settleBookingPayment } from '../src/modules/commerce/booking-payment-service';
import { seeds, command, now, eligibleCoach } from '../test/booking-fixture';
import { keyOf } from '../src/platform/idempotency';
import type { BillplzGateway, SandboxBill } from '../src/modules/commerce/billplz-sandbox';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
let app:App,db:Firestore,id:string,creates:number;
const store=()=>new FirestoreStore(db);
const auth={uid:'member-1',token:{email_verified:true}};
const bill=(paid=false):SandboxBill=>({id:'bill-1',collection_id:'sandbox-collection',amount:12000,paid,paid_amount:paid?12000:0,state:paid?'paid':'due',url:'https://www.billplz-sandbox.com/bills/bill-1',reference_1:id,reference_2:'org-1'});
const gateway:BillplzGateway={create:async()=>{creates++;return bill();},get:async()=>bill(true)};
beforeAll(()=>{if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Emulator required; never target production.');app=initializeApp({projectId:'demo-gainpath'},'booking-payment');db=getFirestore(app);});
afterAll(async()=>{await db?.terminate();if(app)await deleteApp(app);});
beforeEach(async()=>{
  await db.recursiveDelete(db.collection('orgs'));await db.recursiveDelete(db.collection('users'));creates=0;
  const batch=db.batch();Object.entries(seeds).forEach(([p,d])=>batch.set(db.doc(p),d));
  batch.set(db.doc('orgs/org-1/coaches/coach-1'),{...seeds['orgs/org-1/coaches/coach-1'],displayName:'Fixture Coach',consultationFeeMinor:12000,certificationVerified:true});
  batch.set(db.doc('orgs/org-1/coachProfiles/coach-1/certificationState/current'),{certificationVerified:true,approvedCount:1});
  batch.set(db.doc('users/member-1'),{organizationId:'org-1',email:'fixture@example.invalid',displayName:'Fixture Member'});await batch.commit();
  id=(await createBookingHoldService(store(),'member-1',command,eligibleCoach,()=>now)).bookingId;
});
const create=()=>createBookingPayment(store(),auth,{schemaVersion:1,organizationId:'org-1',bookingId:id},gateway,eligibleCoach,()=>now);
it('concurrent checkout creates one bill; concurrent verified callbacks confirm exactly once',async()=>{
  await Promise.all(Array.from({length:4},create));expect(creates).toBe(1);
  const result=await Promise.all(Array.from({length:4},()=>settleBookingPayment(store(),'org-1',id,bill(true),eligibleCoach,()=>now+1000)));
  expect(result.every(r=>r.status==='confirmed')).toBe(true);
  expect((await db.doc(`orgs/org-1/bookings/${id}`).get()).data()?.status).toBe('confirmed');
  expect((await db.collection(`orgs/org-1/transactions/${id}/events`).get()).size).toBe(4);
  expect(await expireBookingHoldService(store(),`orgs/org-1/jobs/${keyOf('expireBookingHold',id)}`,()=>now+900001)).toBe('already_processed');
});
it('expiry racing with paid verification never resurrects the booking or steals replacement locks',async()=>{
  await create();
  await Promise.all([expireBookingHoldService(store(),`orgs/org-1/jobs/${keyOf('expireBookingHold',id)}`,()=>now+900001),settleBookingPayment(store(),'org-1',id,bill(true),eligibleCoach,()=>now+900001)]);
  expect((await db.doc(`orgs/org-1/bookings/${id}`).get()).data()?.status).toBe('expired');
  expect((await db.doc(`orgs/org-1/transactions/${id}`).get()).data()).toMatchObject({paymentStatus:'cleared',fulfilmentStatus:'reconciliation_required'});
  const locks=await db.collection('orgs/org-1/slotLocks').get();
  for(const lock of locks.docs)await lock.ref.set({...lock.data(),bookingId:'replacement',status:'confirmed'});
  await settleBookingPayment(store(),'org-1',id,bill(true),eligibleCoach,()=>now+900002);
  for(const lock of (await db.collection('orgs/org-1/slotLocks').get()).docs)expect(lock.data()).toMatchObject({bookingId:'replacement',status:'confirmed'});
});
it('exact Rules deny direct financial/audit reads and writes for provisioned clients',async()=>{
  await create();
  await db.doc('users/admin-1').set({organizationId:'org-1'});
  await db.doc('orgs/org-1/members/admin-1').set({organizationId:'org-1',status:'active',role:'admin',branchIds:[]});
  const [host,port]=process.env.FIRESTORE_EMULATOR_HOST!.split(':');
  const env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{host,port:Number(port),rules:readFileSync(process.env.BILLPLZ_RULES_PATH??'../firebase/firestore.rules','utf8')}});
  try{
    for(const uid of ['member-1','coach-1','admin-1']){
      const client=env.authenticatedContext(uid,{email_verified:true}).firestore();
      for(const path of [`orgs/org-1/transactions/${id}`,`orgs/org-1/transactions/${id}/events/checkout_created`,'system/paymentIngress/events/forged']){
        await assertFails(getDoc(doc(client,path)));
        await assertFails(setDoc(doc(client,path),{paymentStatus:'cleared',fulfilmentStatus:'confirmed'}));
      }
    }
  }finally{await env.cleanup();}
});
