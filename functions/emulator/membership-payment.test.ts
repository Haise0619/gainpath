import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { createMembershipPayment, settleMembershipPayment } from '../src/modules/commerce/membership-payment-service';
import { resolveMembershipEntitlement } from '../src/modules/commerce/membership-entitlement';
import type { BillplzGateway, SandboxBill } from '../src/modules/commerce/billplz-sandbox';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { localFirestoreEmulator } from './loopback-emulator';
const emulator = localFirestoreEmulator();
let app: App, db: Firestore;
const projectId = 'demo-gainpath-membership', now = 1800000000000;
const base = { schemaVersion: 1, organizationId: 'gainpath', planId: 'fixture', intent: 'renewal' };
const auth = (uid = 'member') => ({ uid, token: { email_verified: true } });
let creates = 0;
const bills = new Map<string, SandboxBill>();
const gateway: BillplzGateway = {
  create: async input => {
    creates++;
    const b: SandboxBill = { id: `bill${creates}`, collection_id: 'sandbox', reference_1: input.reference, reference_2: 'gainpath',
      amount: input.amountMinor, paid_amount: input.amountMinor, paid: true, state: 'paid', url: 'https://www.billplz-sandbox.com/bills/fixture' };
    bills.set(input.reference, b); return b;
  }, get: async id => [...bills.values()].find(b => b.id === id)!,
};
beforeAll(() => {
  app = initializeApp({ projectId }, 'membership-local'); db = getFirestore(app);
});
beforeEach(async () => {
  await fetch(`http://${emulator.authority}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  creates = 0; bills.clear();
  const batch = db.batch();
  batch.set(db.doc('orgs/gainpath'), { status: 'active' });
  for (const uid of ['member', 'other']) {
    batch.set(db.doc(`users/${uid}`), { organizationId: 'gainpath', email: `${uid}@example.invalid` });
    batch.set(db.doc(`orgs/gainpath/members/${uid}`), { organizationId: 'gainpath', role: 'member', status: 'active', branchIds: [] });
    batch.set(db.doc(`orgs/gainpath/membershipAccounts/${uid}`), { planId: 'fixture', expiresAtMillis: now + 50000 });
  }
  batch.set(db.doc('orgs/gainpath/membershipPlans/fixture'), { active: true, name: 'Synthetic test fixture', amountMinor: 10000, currency: 'MYR', durationDays: 30, benefits: [], version: 'test' });
  await batch.commit();
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });
it('reads Free then verified paid then expired entitlement without mutating paid facts', async () => {
  const store = new FirestoreStore(db), account = db.doc('orgs/gainpath/membershipAccounts/member');
  await account.delete();
  const resolve = (at: number) => store.transact(tx => resolveMembershipEntitlement(tx, auth(), 'gainpath', at));
  expect(await resolve(now)).toMatchObject({ effectiveTier: 'free', paidExpiresAtMillis: null });
  expect((await account.get()).exists).toBe(false);
  const plan = (await db.doc('orgs/gainpath/membershipPlans/fixture').get()).data()!;
  await db.doc('orgs/gainpath/membershipPlans/basic').set(plan);
  const payment = await createMembershipPayment(store, auth(), { ...base, intent: 'purchase', planId: 'basic', requestId: 'basic' }, gateway, () => now);
  const id = String(payment.transactionId);
  expect(await resolve(now)).toMatchObject({ effectiveTier: 'free', paidStatus: 'none' });
  await settleMembershipPayment(store, 'gainpath', id, bills.get(id)!, () => now);
  const expiry = now + 30 * 86400000;
  const before = (await account.get()).data();
  expect(await resolve(now)).toMatchObject({ effectiveTier: 'basic', paidStatus: 'active', paidExpiresAtMillis: expiry });
  expect(await resolve(expiry)).toMatchObject({ effectiveTier: 'free', paidTier: 'basic', paidStatus: 'expired', paidExpiresAtMillis: expiry });
  expect((await account.get()).data()).toEqual(before);
});
it('reserves one provider bill during real Firestore transaction contention', async () => {
  const store = new FirestoreStore(db);
  const results = await Promise.all(Array.from({ length: 6 }, (_, n) => createMembershipPayment(store, auth(), { ...base, requestId: `request${n}` }, gateway, () => now)));
  expect(creates).toBe(1);
  expect(new Set(results.map(r => r.transactionId)).size).toBe(1);
  const id = String(results[0].transactionId), b = bills.get(id)!;
  await Promise.all(Array.from({ length: 6 }, () => settleMembershipPayment(store, 'gainpath', id, b, () => now)));
  expect((await db.doc('orgs/gainpath/membershipAccounts/member').get()).data()?.expiresAtMillis).toBe(now + 50000 + 30 * 86400000);
});
it('allocates the final promo capacity to at most one concurrent Member', async () => {
  await db.doc('orgs/gainpath/promoCodes/LAST').set({ active: true, discountPercent: 10, validFromMillis: now - 1, validToMillis: now + 10000, planIds: ['fixture'], currentRedemptions: 0, maxRedemptions: 1 });
  const results = await Promise.allSettled(['member', 'other'].map(uid => createMembershipPayment(new FirestoreStore(db), auth(uid), { ...base, requestId: uid, promoCode: 'LAST' }, gateway, () => now)));
  expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect(creates).toBe(1);
  expect((await db.doc('orgs/gainpath/promoCodes/LAST').get()).data()?.currentRedemptions).toBe(1);
});
it('serializes distinct cleared renewals without losing remaining time', async () => {
  const store = new FirestoreStore(db);
  const p = await createMembershipPayment(store, auth(), { ...base, requestId: 'one' }, gateway, () => now);
  const id = String(p.transactionId), original = (await db.doc(`orgs/gainpath/transactions/${id}`).get()).data()!;
  const second = 'membership_second', secondBill = { ...bills.get(id)!, id: 'bill-second', reference_1: second };
  await db.doc(`orgs/gainpath/transactions/${second}`).set({ ...original, transactionId: second, billId: 'bill-second' });
  await Promise.all([settleMembershipPayment(store, 'gainpath', id, bills.get(id)!, () => now), settleMembershipPayment(store, 'gainpath', second, secondBill, () => now)]);
  expect((await db.doc('orgs/gainpath/membershipAccounts/member').get()).data()?.expiresAtMillis).toBe(now + 50000 + 60 * 86400000);
});
it('existing Rules deny direct financial writes and cross-account ledger reads', async () => {
  const env = await initializeTestEnvironment({ projectId, firestore: { host: emulator.host, port: emulator.port, rules: readFileSync('../firebase/firestore.rules', 'utf8') } });
  try {
    const client = env.authenticatedContext('member', { email_verified: true }).firestore();
    for (const path of ['orgs/gainpath/membershipAccounts/member', 'orgs/gainpath/transactions/forged', 'orgs/gainpath/membershipPlans/fixture', 'orgs/gainpath/promoCodes/CODE']) {
      await assertFails(setDoc(doc(client, path), { expiresAtMillis: now + 9999999999, amountMinor: 1, status: 'cleared' }));
    }
    await assertFails(getDoc(doc(client, 'orgs/gainpath/transactions/other-members-payment')));
  } finally { await env.cleanup(); }
});
