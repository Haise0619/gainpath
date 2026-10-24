import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { createBookingPayment, settleBookingPayment } from '../src/modules/commerce/booking-payment-service';
import { preparePremiumCoachVoucherTerm } from '../src/modules/commerce/premium-coach-voucher';
import { seeds, command, now, eligibleCoach } from '../test/booking-fixture';
import type { BillplzGateway, SandboxBill } from '../src/modules/commerce/billplz-sandbox';
import { localFirestoreEmulator } from './loopback-emulator';
const emulator = localFirestoreEmulator();

let app: App, db: Firestore, bookingId: string;
const org = 'org-1', uid = 'member-1';
const auth = { uid, token: { email_verified: true } }, store = () => new FirestoreStore(db);
const policy = { schemaVersion:1,policyVersion:'synthetic-only',enabled:true,discountBasisPoints:1000,maximumDiscountMinor:1500,
  currency:'MYR',cycleDays:30,rounding:'floor',fundingSource:'gym',coachCommissionBasis:'gross_fee',financeApprovalId:'fixture',
  commissionPolicyVersion:'sandbox-coach-80-v1',eligibleBranchIds:['branch-1'],eligibleCoachIds:['coach-1'],eligibleDurationsMinutes:[30,60],
  expiry:'cycle_end',stacking:'none',refund:'no_reinstatement',unpaidRecovery:'provider_deleted_only' };
const bill = (id: string, paid = false): SandboxBill => ({ id:`bill-${id}`,collection_id:'collection',amount:10800,paid,
  paid_amount:paid ? 10800 : 0,state:paid?'paid':'due',url:`https://www.billplz-sandbox.com/bills/bill-${id}`,reference_1:id,reference_2:org });
const gateway: BillplzGateway = { create:async d=>bill(d.reference),get:async()=>bill(bookingId,true) };
beforeAll(() => {
  app=initializeApp({projectId:'demo-gainpath'},'premium-coach-voucher');db=getFirestore(app);
});
afterAll(async()=>{await db?.terminate();if(app)await deleteApp(app);});
beforeEach(async()=>{
  await db.recursiveDelete(db.collection('orgs'));await db.recursiveDelete(db.collection('users'));
  const batch=db.batch();Object.entries(seeds).forEach(([p,d])=>batch.set(db.doc(p),d));
  batch.set(db.doc(`users/${uid}`),{organizationId:org,email:'fixture@example.invalid'});
  batch.set(db.doc(`orgs/${org}/coaches/coach-1`),{...seeds['orgs/org-1/coaches/coach-1'],displayName:'Fixture Coach',consultationFeeMinor:12000,certificationVerified:true});
  batch.set(db.doc(`orgs/${org}/coachProfiles/coach-1/certificationState/current`),{certificationVerified:true,approvedCount:1});
  batch.set(db.doc(`orgs/${org}/settings/premiumCoachVoucher`),policy);await batch.commit();
  const p={schemaVersion:1,organizationId:org,memberId:uid,transactionId:'paid',kind:'MembershipPurchase',environment:'sandbox',provider:'billplz',currency:'MYR',
    planId:'premium',planName:'Synthetic',benefits:[],durationDays:30,amountMinor:8900,paymentStatus:'cleared',fulfilmentStatus:'confirmed',
    billId:'paid-bill',collectionId:'collection',clearedAtMillis:now-86400000,expiresAtMillis:now+29*86400000};
  await store().transact(async tx=>{
    const apply=await preparePremiumCoachVoucherTerm(tx,org,p);
    tx.set(`orgs/${org}/transactions/paid`,p);tx.set(`orgs/${org}/membershipAccounts/${uid}`,{organizationId:org,memberId:uid,planId:'premium',expiresAtMillis:p.expiresAtMillis,lastTransactionId:'paid'});apply();
  });
  bookingId=(await createBookingHoldService(store(),uid,command,eligibleCoach,()=>now)).bookingId;
});
it('serializes distinct checkout contention on one voucher and consumes exactly once under callback retries',async()=>{
  const b=(await db.doc(`orgs/${org}/bookings/${bookingId}`).get()).data()!;
  await db.doc(`orgs/${org}/bookings/other`).set({...b,bookingId:'other'});
  const result=await Promise.allSettled([bookingId,'other'].map(id=>createBookingPayment(store(),auth,{schemaVersion:1,organizationId:org,bookingId:id,usePremiumVoucher:true},gateway,eligibleCoach,()=>now)));
  expect(result.filter(r=>r.status==='fulfilled')).toHaveLength(1);expect(result.filter(r=>r.status==='rejected')).toHaveLength(1);
  const winner=result[0].status==='fulfilled'?bookingId:'other';
  await Promise.all(Array.from({length:4},()=>settleBookingPayment(store(),org,winner,bill(winner,true),eligibleCoach,()=>now+1000)));
  const vouchers=await db.collection(`orgs/${org}/premiumCoachVouchers`).get();expect(vouchers.size).toBe(1);
  expect(vouchers.docs[0].data()).toMatchObject({status:'consumed',bookingId:winner,discountMinor:1200,amountMinor:10800});
});
it('denies direct client reads and writes of voucher policy, earned terms, heads and reservations',async()=>{
  await db.doc('users/admin-1').set({organizationId:org});
  await db.doc(`orgs/${org}/members/admin-1`).set({organizationId:org,role:'admin',status:'active',branchIds:[]});
  const env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{host:emulator.host,port:emulator.port,rules:readFileSync(process.env.BILLPLZ_RULES_PATH??'../firebase/firestore.rules','utf8')}});
  try {
    for(const actor of [uid,'coach-1','admin-1']) {
      const client=env.authenticatedContext(actor,{email_verified:true}).firestore();
      for(const path of [`orgs/${org}/settings/premiumCoachVoucher`,`orgs/${org}/premiumCoachVoucherHeads/${uid}`,`orgs/${org}/premiumCoachVoucherTerms/paid`,`orgs/${org}/premiumCoachVouchers/forged`]) {
        await assertFails(getDoc(doc(client,path)));await assertFails(setDoc(doc(client,path),{status:'available',memberId:uid}));
      }
    }
  } finally { await env.cleanup(); }
});
