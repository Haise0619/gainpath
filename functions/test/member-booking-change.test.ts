import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now, start, command, eligibleCoach } from './booking-fixture';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { memberBookingChange, memberReschedulingOptions } from '../src/modules/coaching/member-booking-change-service';
import { keyOf } from '../src/platform/idempotency';

let store: MemoryStore, id: string;
const auth = { uid: 'member-1', token: { email_verified: true } };
const call = (action: string, extra = {}, time = now, actor = auth) => memberBookingChange(store, actor, {schemaVersion: 1, organizationId: 'org-1', bookingId: id, action, requestId: 'change-1', expectedStartAtMillis: start, reason: 'My availability changed', ...extra}, eligibleCoach, () => time);
beforeEach(async () => {
  store = new MemoryStore();
  Object.entries(seeds).forEach(([p,d]) => store.documents.set(p, structuredClone(d)));
  store.documents.set('orgs/org-1/coaches/coach-1', {status:'published', branchIds:['branch-1'], certificationVerified:true, approvedCertificationCount:1});
  store.documents.set('orgs/org-1/coachProfiles/coach-1/certificationState/current', {certificationVerified:true, approvedCount:1});
  id = (await createBookingHoldService(store, auth.uid, command, eligibleCoach, () => now)).bookingId;
  const path = `orgs/org-1/bookings/${id}`;
  store.documents.set(path, {...store.documents.get(path),status:'confirmed'});
  for (let slot=start;slot<start+3600000;slot+=1800000) {
    const p=`orgs/org-1/slotLocks/${keyOf('coach-1',slot)}`;
    store.documents.set(p,{...store.documents.get(p),status:'confirmed'});
  }
  const day=`orgs/org-1/bookingDays/${keyOf(auth.uid,'2026-10-02')}`;
  store.documents.set(day,{...store.documents.get(day),reservations:[{bookingId:id,status:'confirmed',expiresAtMillis:now+900000}]});
  store.documents.set(`orgs/org-1/transactions/${id}`,{schemaVersion:1,type:'CoachingBooking',environment:'sandbox',provider:'billplz',organizationId:'org-1',bookingId:id,memberId:auth.uid,coachId:'coach-1',branchId:'branch-1',durationMinutes:60,currency:'MYR',amountMinor:10000,paymentStatus:'cleared',fulfilmentStatus:'confirmed'});
});
it('cancels at exactly 12 hours, routes payment to review and replays without duplicate effects', async()=>{
  const r=await call('cancel',{},start-12*3600000);
  expect(r).toMatchObject({status:'cancelled',refundReviewRequired:true});
  const count=store.documents.size;
  expect(await call('cancel',{},start-12*3600000+1)).toEqual(r);
  expect(store.documents.size).toBe(count);
  expect(store.documents.get(`orgs/org-1/transactions/${id}`)).toMatchObject({paymentStatus:'cleared',fulfilmentStatus:'reconciliation_required',amountMinor:10000});
});
it('rejects late cancellations and unauthorized actors without mutations',async()=>{
  const before=structuredClone([...store.documents]);
  await expect(call('cancel',{},start-12*3600000+1)).rejects.toMatchObject({code:'failed-precondition'});
  await expect(call('cancel',{},now,{uid:'coach-1',token:{email_verified:true}})).rejects.toMatchObject({code:'permission-denied'});
  expect([...store.documents]).toEqual(before);
});
it('rejects foreign owners, inactive membership, wrong organization and forged scope without mutations', async () => {
  store.documents.set('users/other-member', { organizationId: 'org-1' });
  store.documents.set('orgs/org-1/members/other-member', { organizationId: 'org-1', role: 'member', status: 'active', branchIds: ['branch-1'] });
  let before = structuredClone([...store.documents]);
  await expect(call('cancel', {}, now, { uid: 'other-member', token: { email_verified: true } })).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(call('cancel', { organizationId: 'other-org' })).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(call('cancel', { memberId: 'other-member' })).rejects.toThrow();
  expect([...store.documents]).toEqual(before);
  store.documents.get('orgs/org-1/members/member-1')!.status = 'inactive';
  before = structuredClone([...store.documents]);
  await expect(call('cancel')).rejects.toMatchObject({ code: 'permission-denied' });
  expect([...store.documents]).toEqual(before);
});
it('replacement options derive the original Coach, branch and duration and exclude only the owned source', async () => {
  const options = await memberReschedulingOptions(store, auth, { schemaVersion: 1, organizationId: 'org-1', bookingId: id, action: 'options', localDate: '2026-10-02' }, eligibleCoach, () => now);
  expect(options.options.length).toBeGreaterThan(0);
  for (const option of options.options) {
    expect(option.branchId).toBe('branch-1');
    expect(option.endAtMillis - option.startAtMillis).toBe(3600000);
    expect(option.startAtMillis).not.toBe(start);
  }
});
it('reschedules at exactly 24 hours atomically without a second payment or self daily-cap conflict',async()=>{
  const payment=structuredClone(store.documents.get(`orgs/org-1/transactions/${id}`));
  const r=await call('reschedule',{newStartAtMillis:start+2*3600000},start-24*3600000);
  expect(r).toMatchObject({status:'confirmed',startAtMillis:start+2*3600000});
  expect(store.documents.get(`orgs/org-1/transactions/${id}`)).toEqual(payment);
  expect(store.documents.get(`orgs/org-1/slotLocks/${keyOf('coach-1',start+2*3600000)}`)).toMatchObject({bookingId:id,status:'confirmed'});
  expect(store.documents.get(`orgs/org-1/slotLocks/${keyOf('coach-1',start)}`)).toMatchObject({status:'pending_hold',expiresAtMillis:start-24*3600000});
});
it('failed replacement, late notice and stale source preserve the original booking and locks',async()=>{
  const target=start+2*3600000;
  store.documents.set(`orgs/org-1/slotLocks/${keyOf('coach-1',target)}`,{schemaVersion:1,coachId:'coach-1',branchId:'branch-1',bookingId:'another-booking',status:'confirmed'});
  const before=structuredClone([...store.documents]);
  await expect(call('reschedule',{newStartAtMillis:target})).rejects.toMatchObject({code:'aborted'});
  await expect(call('reschedule',{newStartAtMillis:target},start-24*3600000+1)).rejects.toMatchObject({code:'failed-precondition'});
  await expect(call('reschedule',{newStartAtMillis:target,expectedStartAtMillis:start+1800000})).rejects.toMatchObject({code:'aborted'});
  expect([...store.documents]).toEqual(before);
});
