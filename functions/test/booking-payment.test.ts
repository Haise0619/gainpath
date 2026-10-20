import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { command, seeds, now, eligibleCoach } from './booking-fixture';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { getBookingPaymentQuote, createBookingPayment, readBookingPayment, settleBookingPayment } from '../src/modules/commerce/booking-payment-service';
import type { BillplzGateway, SandboxBill } from '../src/modules/commerce/billplz-sandbox';
import { expireBookingHoldService } from '../src/modules/coaching/booking-lifecycle-service';
import { keyOf } from '../src/platform/idempotency';
let store: MemoryStore, id: string, creates: number;
const auth = (uid = 'member-1') => ({ uid, token: { email_verified: true } });
const input = () => ({ schemaVersion: 1, organizationId: 'org-1', bookingId: id });
const bill = (paid = false): SandboxBill => ({ id: 'bill-1', collection_id: 'sandbox-collection', amount: 12000, paid, paid_amount: paid ? 12000 : 0, state: paid ? 'paid' : 'due', url: 'https://www.billplz-sandbox.com/bills/bill-1', reference_1: id, reference_2: 'org-1' });
const gateway: BillplzGateway = { create: async () => { creates++; return bill(); }, get: async () => bill(true) };
beforeEach(async () => {
  store = new MemoryStore(); creates = 0;
  Object.entries(seeds).forEach(([p,d]) => store.documents.set(p, structuredClone(d)));
  Object.assign(store.documents.get('orgs/org-1/coaches/coach-1')!, { displayName: 'Fixture Coach', consultationFeeMinor: 12000, certificationVerified: true });
  store.documents.set('orgs/org-1/coachProfiles/coach-1/certificationState/current', { certificationVerified: true, approvedCount: 1 });
  Object.assign(store.documents.get('users/member-1')!, { email: 'member@example.invalid', displayName: 'Fixture Member' });
  Object.assign(store.documents.get('orgs/org-1/branches/branch-1')!, { displayName: 'Fixture Branch' });
  id = (await createBookingHoldService(store, 'member-1', command, eligibleCoach, () => now)).bookingId;
});
it('quotes authoritative minor units and creates only one bill for concurrent/repeated checkout', async () => {
  const quote = await getBookingPaymentQuote(store, auth(), { schemaVersion: 1, organizationId: 'org-1', coachId: 'coach-1', branchId: 'branch-1', durationMinutes: 60 });
  expect(quote).toMatchObject({ amountMinor: 12000, currency: 'MYR' });
  await Promise.all([createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now), createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now)]);
  expect(creates).toBe(1);
  expect((await createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now)).status).toBe('awaiting_payment');
  expect(creates).toBe(1);
});
it('independent provider read confirms once, promotes own locks/day and makes expiry harmless', async () => {
  await createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now);
  const result = await readBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now + 1000);
  expect(result.status).toBe('confirmed');
  expect(store.documents.get(`orgs/org-1/bookings/${id}`)?.status).toBe('confirmed');
  for (const [p,d] of store.documents) if (p.includes('/slotLocks/')) expect(d.status).toBe('confirmed');
  expect(await expireBookingHoldService(store, `orgs/org-1/jobs/${keyOf('expireBookingHold', id)}`, () => now + 900001)).toBe('already_processed');
  const count = store.documents.size;
  await settleBookingPayment(store, 'org-1', id, bill(true), eligibleCoach, () => now + 1001);
  expect(store.documents.size).toBe(count);
});
it('late success records a resolution case and never overwrites expired/replacement reservations', async () => {
  await createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now);
  await expireBookingHoldService(store, `orgs/org-1/jobs/${keyOf('expireBookingHold', id)}`, () => now + 900001);
  for (const [p,d] of store.documents) if (p.includes('/slotLocks/')) store.documents.set(p, { ...d, bookingId: 'replacement', status: 'confirmed' });
  const protectedBefore = [...store.documents].filter(([p]) => !p.includes('/transactions/'));
  const result = await settleBookingPayment(store, 'org-1', id, bill(true), eligibleCoach, () => now + 900002);
  expect(result.status).toBe('reconciliation_required');
  expect([...store.documents].filter(([p]) => !p.includes('/transactions/'))).toEqual(protectedBefore);
  expect(store.documents.get(`orgs/org-1/transactions/${id}`)?.paymentStatus).toBe('cleared');
});
it('rejects forged fields/owners and never treats a due bill as confirmation', async () => {
  await expect(createBookingPayment(store, auth('coach-1'), input(), gateway, eligibleCoach, () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(createBookingPayment(store, auth(), { ...input(), amountMinor: 1 }, gateway, eligibleCoach, () => now)).rejects.toThrow();
  await createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now);
  expect((await settleBookingPayment(store, 'org-1', id, bill(), eligibleCoach, () => now)).status).toBe('awaiting_payment');
  await expect(settleBookingPayment(store, 'org-1', id, { ...bill(true), amount: 1 }, eligibleCoach, () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('quarantines ambiguous bill creation without a second provider create', async () => {
  const uncertain: BillplzGateway = { ...gateway, create: async () => { creates++; throw Error('timeout'); } };
  const result = await createBookingPayment(store, auth(), input(), uncertain, eligibleCoach, () => now);
  expect(result.status).toBe('reconciliation_required');
  await createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now);
  expect(creates).toBe(1);
});
it('does not confirm a hold at a branch removed from publication even if another shared branch remains', async () => {
  await createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now);
  store.documents.get('orgs/org-1/members/coach-1')!.branchIds=['branch-1','branch-2'];
  store.documents.get('orgs/org-1/coaches/coach-1')!.branchIds=['branch-2'];
  store.documents.set('orgs/org-1/branches/branch-2',{status:'active'});
  expect((await settleBookingPayment(store,'org-1',id,bill(true),eligibleCoach,()=>now+1000)).status).toBe('reconciliation_required');
  expect(store.documents.get(`orgs/org-1/bookings/${id}`)?.status).toBe('pending_hold');
});
it('keeps other day reservations and metadata verbatim and never downgrades a paid transaction', async () => {
  await createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now);
  const day=store.documents.get(`orgs/org-1/bookingDays/${keyOf('member-1','2026-10-02')}`)!;
  const other={bookingId:'old',status:'pending_hold',expiresAtMillis:now-1};
  day.reservations=[...(day.reservations as object[]),other]; day.extra='preserved';
  await settleBookingPayment(store,'org-1',id,bill(true),eligibleCoach,()=>now+1000);
  expect(store.documents.get(`orgs/org-1/bookingDays/${keyOf('member-1','2026-10-02')}`)).toMatchObject({extra:'preserved',reservations:[{bookingId:id,status:'confirmed'},other]});
  expect((await settleBookingPayment(store,'org-1',id,bill(),eligibleCoach,()=>now+2000)).status).toBe('confirmed');
});
it('never reopens hosted checkout after hold expiry; a later verified payment is still recorded', async () => {
  await createBookingPayment(store, auth(), input(), gateway, eligibleCoach, () => now);
  const closed=await createBookingPayment(store,auth(),input(),gateway,eligibleCoach,()=>now+900001);
  expect(closed.status).toBe('reconciliation_required');expect(closed).not.toHaveProperty('checkoutUrl');
  const paid=await readBookingPayment(store,auth(),input(),gateway,eligibleCoach,()=>now+900002);
  expect(paid.status).toBe('reconciliation_required');
  expect(store.documents.get(`orgs/org-1/transactions/${id}`)?.paymentStatus).toBe('cleared');
});
it('records paid reconciliation when the advance window shrinks after checkout',async()=>{
  const futureStart=command.startAtMillis+2*86400000;
  store.documents.set('orgs/org-1/coachAvailability/coach-1/days/2026-10-04',{schemaVersion:1,revision:1,timeZone:'Asia/Kuala_Lumpur',policyVersion:'booking-v1',createdAtMillis:now,updatedAtMillis:now,windows:[{branchId:'branch-1',startAtMillis:futureStart,endAtMillis:futureStart+14400000}]});
  id=(await createBookingHoldService(store,'member-1',{...command,requestId:'future-request',startAtMillis:futureStart},eligibleCoach,()=>now)).bookingId;
  await createBookingPayment(store,auth(),input(),gateway,eligibleCoach,()=>now);
  store.documents.set('orgs/org-1/coachAvailability/coach-1',{schemaVersion:1,revision:1,timeZone:'Asia/Kuala_Lumpur',policyVersion:'booking-v1',createdAtMillis:now,updatedAtMillis:now,exceptions:[],weeklyAvailability:{dailyCapacityHours:8,advanceBookingWindowDays:1,schedule:Array.from({length:7},(_,i)=>({dayOfWeek:i+1,isActive:true,startMinute:480,endMinute:1020,branchId:'branch-1'}))}});
  expect((await settleBookingPayment(store,'org-1',id,bill(true),eligibleCoach,()=>now+1000)).status).toBe('reconciliation_required');
  expect(store.documents.get(`orgs/org-1/transactions/${id}`)?.paymentStatus).toBe('cleared');
});
it('Member pending cancellation followed by paid callback never confirms or reports a refund',async()=>{
  await createBookingPayment(store,auth(),input(),gateway,eligibleCoach,()=>now);
  const b=store.documents.get(`orgs/org-1/bookings/${id}`)!;
  store.documents.set(`orgs/org-1/bookings/${id}`,{...b,status:'cancelled',resolvedAtMillis:now+1000,resolution:'member_cancelled'});
  expect((await settleBookingPayment(store,'org-1',id,bill(true),eligibleCoach,()=>now+2000)).status).toBe('reconciliation_required');
  expect(store.documents.get(`orgs/org-1/transactions/${id}`)?.paymentStatus).toBe('cleared');
  expect(store.documents.get(`orgs/org-1/bookings/${id}`)?.status).toBe('cancelled');
});
it('cancellation during Bill creation never opens hosted checkout',async()=>{
  const cancelling:BillplzGateway={...gateway,create:async()=>{
    const b=store.documents.get(`orgs/org-1/bookings/${id}`)!;
    store.documents.set(`orgs/org-1/bookings/${id}`,{...b,status:'cancelled',resolvedAtMillis:now+1,resolution:'member_cancelled'});
    return bill();
  }};
  const result=await createBookingPayment(store,auth(),input(),cancelling,eligibleCoach,()=>now+2);
  expect(result.status).toBe('reconciliation_required');expect(result).not.toHaveProperty('checkoutUrl');
});
it('cancellation during independent provider lookup cannot return a checkout URL',async()=>{
  await createBookingPayment(store,auth(),input(),gateway,eligibleCoach,()=>now);
  const cancelling:BillplzGateway={...gateway,get:async()=>{
    const b=store.documents.get(`orgs/org-1/bookings/${id}`)!;
    store.documents.set(`orgs/org-1/bookings/${id}`,{...b,status:'cancelled',resolvedAtMillis:now+1,resolution:'member_cancelled'});
    return bill();
  }};
  const result=await readBookingPayment(store,auth(),input(),cancelling,eligibleCoach,()=>now+2);
  expect(result.status).toBe('reconciliation_required');expect(result).not.toHaveProperty('checkoutUrl');
});
