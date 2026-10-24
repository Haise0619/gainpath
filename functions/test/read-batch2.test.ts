import { expect, it } from 'vitest';
import { listAdminBookingPayments, getAdminBookingPayment } from '../src/modules/commerce/booking-payment-admin';
import { getCoachCertifications } from '../src/modules/coaching/coach-certification-service';
import { getCoachPublishedPhoto } from '../src/modules/coaching/coach-photo-service';
import { fixture, auth, input, org, certificationId } from './read-batch2-fixture';

it('keeps all three Admin list authorization snapshots with one RPC per snapshot and no writes', async () => {
  const { store, deps } = fixture(), before = structuredClone([...store.documents]);
  const result = await listAdminBookingPayments(store, auth, input, deps);
  expect(result.records).toHaveLength(20); expect(result.nextAfterId).toBe('payment19');
  expect(store.readRpcs).toBe(3);
  expect(store.batches.filter(paths => paths.includes(`orgs/${org}/members/admin`))).toHaveLength(3);
  expect(store.batches.flat().filter(p => p === `orgs/${org}/members/member`)).toHaveLength(1);
  expect([...store.documents]).toEqual(before);
});
it('keeps payment freshness after events and rechecks every detail authorization snapshot', async () => {
  const { store, deps } = fixture();
  deps.reader.events = async () => {
    store.documents.get(`orgs/${org}/transactions/payment00`)!.refundStatus = 'approved';
    return [{ id: 'event', data: { event: 'reviewed', secret: 'never expose' } }];
  };
  const result = await getAdminBookingPayment(store, auth, { ...input, bookingId: 'payment00' }, deps);
  expect(result.payment.refundStatus).toBe('approved'); expect(result.events).toEqual([{ id: 'event', event: 'reviewed' }]);
  expect(store.readRpcs).toBe(3);
});
it('never releases payment details when Admin authority is revoked during event retrieval', async () => {
  const { store, deps } = fixture();
  deps.reader.events = async () => { store.documents.get(`orgs/${org}/members/admin`)!.role = 'member'; return []; };
  await expect(getAdminBookingPayment(store, auth, { ...input, bookingId: 'payment00' }, deps)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('batches the bounded certification page and its descending history while preserving cursors', async () => {
  const { store } = fixture();
  const first = await getCoachCertifications(store, auth, { ...input, coachId: 'coach' });
  expect(first.certifications).toHaveLength(20); expect(first.nextCursor).toBe((19).toString(16).padStart(32, '0'));
  expect(store.readRpcs).toBe(2);
  store.batches.length = 0; store.singles.length = 0;
  const detail = await getCoachCertifications(store, auth, { ...input, coachId: 'coach', certificationId });
  expect(detail.certifications[0].history.map((h: any) => h.revision)).toEqual(Array.from({ length: 20 }, (_, i) => 20 - i));
  expect(store.readRpcs).toBe(3);
});
it('photo checks scope/publication before and after download without repeated reads inside a snapshot', async () => {
  const { store, photoPath } = fixture(), before = structuredClone([...store.documents]);
  const result = await getCoachPublishedPhoto(store, { ...auth, uid: 'member' }, { ...input, coachId: 'coach' }, async () => ({ contentType: 'image/png', bytesBase64: 'fixture' }));
  expect(result.photoPath).toBe(photoPath); expect(store.readRpcs).toBe(2); expect(store.documentReads).toBe(8);
  expect([...store.documents]).toEqual(before);
  await expect(getCoachPublishedPhoto(store, { ...auth, uid: 'member' }, { ...input, coachId: 'coach' }, async () => {
    store.documents.get(`orgs/${org}/members/member`)!.status = 'inactive';
    return { contentType: 'image/png', bytesBase64: 'fixture' };
  })).rejects.toMatchObject({ code: 'permission-denied' });
});
