import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { listAdminBookingPayments, type PaymentAdminDependencies } from '../src/modules/commerce/booking-payment-admin';
import { membershipOverview } from '../src/modules/commerce/membership-payment-service';
import { getCoachAvailabilityService } from '../src/modules/coaching/coach-availability-service';
import { getCoachRatingsCommand } from '../src/modules/coaching/coach-rating-callable';
import { getCoachRatingsPilotCommand } from '../src/modules/coaching/coach-rating-pilot-callable';
import { seeds, now } from '../test/booking-fixture';
import { localFirestoreEmulator } from './loopback-emulator';

const emulator = localFirestoreEmulator();
const projectId = 'demo-gainpath-read-performance';
let app: App, db: Firestore;
const memberAuth = { uid: 'member-1', token: { email_verified: true } };
beforeAll(() => { app = initializeApp({ projectId }); db = getFirestore(app); });
beforeEach(async () => {
  await fetch(`http://${emulator.authority}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  const batch = db.batch();
  for (const [path, data] of Object.entries(seeds)) batch.set(db.doc(path), data);
  batch.set(db.doc('users/admin'), { organizationId: 'org-1' });
  batch.set(db.doc('orgs/org-1/members/admin'), { organizationId: 'org-1', role: 'admin', status: 'active', branchIds: [] });
  await batch.commit();
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });

it('US and Singapore handlers return identical persisted aggregates and identical scope failures', async () => {
  const batch = db.batch();
  for (const [id, stars] of [['one', 4], ['two', 5], ['invalid', 9]] as const) {
    batch.set(db.doc(`orgs/org-1/coaches/coach-1/reviews/${id}`), { stars });
  }
  await batch.commit();
  // .run exercises the shared application handler, not SDK token validation;
  // actual HTTP App Check rejection is covered by coach-rating-pilot.test.ts.
  const request = { auth: memberAuth, data: { schemaVersion: 1, organizationId: 'org-1', coachIds: ['coach-1', 'coach-1'] } } as any;
  for (const command of [getCoachRatingsCommand, getCoachRatingsPilotCommand]) {
    expect(await command.run(request)).toEqual({ schemaVersion: 1, records: [{ coachId: 'coach-1', reviewCount: 2, averageRating: 4.5 }] });
    await expect(command.run({ ...request, auth: undefined })).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(command.run({ ...request, auth: { ...memberAuth, token: { email_verified: false } } })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(command.run({ ...request, data: { ...request.data, organizationId: 'other' } })).rejects.toMatchObject({ code: 'permission-denied' });
  }
  await db.doc('orgs/org-1/coaches/coach-1').update({ status: 'draft' });
  for (const command of [getCoachRatingsCommand, getCoachRatingsPilotCommand]) {
    await expect(command.run(request)).rejects.toMatchObject({ code: 'permission-denied' });
  }
});
it('Admin batched transaction projection retains separate Membership routing and Member isolation', async () => {
  await db.doc('orgs/org-1/members/member-1').update({ displayName: 'Fixture Member', email: 'private@example.invalid' });
  const data = { schemaVersion: 1, transactionId: 'membership', organizationId: 'org-1', kind: 'MembershipPurchase',
    memberId: 'member-1', environment: 'sandbox', provider: 'billplz', currency: 'MYR', amountMinor: 100, durationDays: 30,
    paymentStatus: 'cleared', fulfilmentStatus: 'confirmed' };
  const unavailable = async (): Promise<never> => { throw Error('No provider operation allowed'); };
  const deps: PaymentAdminDependencies = { collectionId: 'fixture', bills: { get: unavailable, create: unavailable }, readIdentity: unavailable,
    reader: { list: async () => [{ id: 'membership', data }], events: async () => [] } };
  const store = new FirestoreStore(db), input = { schemaVersion: 1, organizationId: 'org-1' };
  const page = await listAdminBookingPayments(store, { uid: 'admin', token: { email_verified: true } }, input, deps);
  expect(page.records).toHaveLength(1);
  expect(page.records[0]).toMatchObject({ transactionId: 'membership', bookingId: 'membership', kind: 'MembershipPurchase', memberDisplayName: 'Fixture Member' });
  expect(page.records[0]).not.toHaveProperty('email');
  await expect(listAdminBookingPayments(store, memberAuth, input, deps)).rejects.toMatchObject({ code: 'permission-denied' });
  expect((await db.collection('orgs/org-1/transactions').get()).empty).toBe(true);
});
it('reads availability through real getAll and preserves scope, day order and empty windows', async () => {
  const result = await getCoachAvailabilityService(new FirestoreStore(db), { uid: 'coach-1', token: { email_verified: true } },
    { schemaVersion: 1, organizationId: 'org-1', coachId: 'coach-1', dayCount: 2 }, () => now);
  expect(result.days.map(d => d.localDate)).toEqual(['2026-10-01', '2026-10-02']);
  expect(result.assignedBranchIds).toEqual(['branch-1']);
  expect(result.days[0].windows).toEqual([]);
  expect(result.days[1].windows).toHaveLength(1);
  await db.doc('orgs/org-1/branches/branch-1').update({ status: 'inactive' });
  await expect(getCoachAvailabilityService(new FirestoreStore(db), { uid: 'coach-1', token: { email_verified: true } },
    { schemaVersion: 1, organizationId: 'org-1', coachId: 'coach-1', dayCount: 2 }, () => now)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('Membership still rejects a revocation during history reads after parallel initial checks', async () => {
  const input = { schemaVersion: 1, organizationId: 'org-1' }, store = new FirestoreStore(db);
  const identity = async () => ({ exists: true, disabled: false, emailVerified: true });
  const reader = { plans: async () => [], payments: async () => [] };
  expect((await membershipOverview(store, memberAuth, input, reader, () => now, identity)).entitlement.effectiveTier).toBe('free');
  await expect(membershipOverview(store, memberAuth, input, { ...reader, payments: async () => {
    await db.doc('orgs/org-1/members/member-1').update({ status: 'inactive' });
    return [];
  } }, () => now, identity)).rejects.toMatchObject({ code: 'permission-denied' });
});
