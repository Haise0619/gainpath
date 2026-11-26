import { expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { applyXenditRefund, xenditRefundReference } from '../src/modules/commerce/xendit-refund';

it('preserves rights while pending, restores prior paid term once after confirmed refund', async () => {
  const store = new MemoryStore(), org = 'gym', id = 'next', uid = 'member';
  const root = 'orgs/gym/', path = root + 'transactions/next', account = root + 'membershipAccounts/member';
  const previous = { planId: 'basic', planName: 'Basic', benefits: [], expiresAtMillis: 1800000000000, lastTransactionId: 'prior' };
  store.documents.set(root + 'transactions/prior', { ...previous, memberId: uid, paymentStatus: 'cleared' });
  const reference = xenditRefundReference(org,id), payment = 'py-123', expiry = previous.expiresAtMillis + 2592000000;
  store.documents.set(path, { memberId: uid, kind: 'MembershipRenewal', expiresAtMillis: expiry,
    provider: 'xendit', environment: 'sandbox', amountMinor: 8900, refundReference: reference,
    refundPaymentId: payment, refundStatus: 'processing', previousMembershipTerm: previous });
  store.documents.set(account, { ...previous, lastTransactionId: id, expiresAtMillis: expiry, refundInProgress: id });
  store.documents.set(root + 'membershipBilling/member', { cancelled: true, bill: { paymentId: id } });
  const result = { refund_id: 'rfd-11111111-1111-1111-1111-111111111111', reference_id: reference, payment_id: payment, currency: 'MYR', amount: 89 };
  await applyXenditRefund(store,org,id,{...result,status:'PENDING'},1);
  expect(store.documents.get(account)?.expiresAtMillis).toBe(expiry);
  await expect(applyXenditRefund(store,org,id,{...result,amount:88,status:'SUCCEEDED'},2)).rejects.toThrow();
  await Promise.all([applyXenditRefund(store,org,id,{...result,status:'SUCCEEDED'},2),
    applyXenditRefund(store,org,id,{...result,status:'SUCCEEDED'},2)]);
  expect(store.documents.get(account)).toMatchObject({...previous,refundInProgress:null});
  expect(store.documents.get(path)?.refundStatus).toBe('completed');
  expect(store.documents.get(root + 'membershipBilling/member')).toEqual({cancelled:true});
});

it('marks cancelled coaching as refunded only after provider success', async () => {
  const store = new MemoryStore(), org = 'gym', id = 'booking';
  const reference = xenditRefundReference(org,id);
  const path = 'orgs/gym/transactions/booking', booking = 'orgs/gym/bookings/booking';
  store.documents.set(path, { memberId:'member',provider:'xendit',environment:'sandbox',amountMinor:12000,
    refundReference:reference,refundPaymentId:'py-123',refundStatus:'processing' });
  store.documents.set(booking,{memberId:'member',status:'cancelled'});
  await applyXenditRefund(store,org,id,{ refund_id:'rfd-11111111-1111-1111-1111-111111111111',
    payment_id:'py-123',reference_id:reference,currency:'MYR',amount:120,status:'FAILED',failure_code:'CHANNEL_UNAVAILABLE' },1);
  expect(store.documents.get(booking)?.status).toBe('cancelled');
  expect(store.documents.get(path)).toMatchObject({ refundStatus:'failed',refundFailureCode:'CHANNEL_UNAVAILABLE' });
});
