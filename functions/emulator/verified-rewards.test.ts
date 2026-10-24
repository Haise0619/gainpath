import { readFileSync } from 'node:fs';
import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { assertFails, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { rewardsCommand } from '../src/modules/gamification/verified-rewards-service';
import { localFirestoreEmulator } from './loopback-emulator';
const emulator = localFirestoreEmulator();

const projectId = 'demo-gainpath-rewards', org = 'gainpath', now = 1800000000000, day = 86400000;
let app: App, db: Firestore;
const path = (collection: string, id: string) => `orgs/${org}/${collection}/${id}`;
const identity = async () => ({ exists: true, disabled: false, emailVerified: true });
const command = (uid: string, action: string, fields = {}) => rewardsCommand(new FirestoreStore(db),
  { uid, token: { email_verified: true } }, { schemaVersion: 1, organizationId: org, action, ...fields }, identity, () => now);
beforeAll(() => {
  app = initializeApp({ projectId }, 'verified-rewards-local'); db = getFirestore(app);
});
beforeEach(async () => {
  await fetch(`http://${emulator.authority}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  const batch = db.batch();
  batch.set(db.doc(`orgs/${org}`), { status: 'active' });
  for (const uid of ['one', 'two', 'admin']) {
    batch.set(db.doc(`users/${uid}`), { organizationId: org });
    batch.set(db.doc(path('members', uid)), { organizationId: org, userId: uid, role: uid === 'admin' ? 'admin' : 'member', status: 'active', branchIds: [] });
    batch.set(db.doc(path('membershipAccounts', uid)), { organizationId: org, memberId: uid, planId: 'basic', expiresAtMillis: now + day, lastTransactionId: uid });
    batch.set(db.doc(path('transactions', uid)), { schemaVersion: 1, transactionId: uid, organizationId: org, memberId: uid,
      planId: 'basic', kind: 'MembershipPurchase', environment: 'sandbox', provider: 'billplz', currency: 'MYR', paymentStatus: 'cleared',
      fulfilmentStatus: 'confirmed', billId: uid, collectionId: 'synthetic', amountMinor: 1, durationDays: 30,
      clearedAtMillis: now - 29 * day, expiresAtMillis: now + day, planName: 'Synthetic', benefits: [] });
    batch.set(db.doc(path('rewardEvents', uid)), { schemaVersion: 1, eventId: uid, organizationId: org, memberId: uid,
      sourceId: 'synthetic', producerVersion: 'test-v1', rewardPolicyVersion: 'test-v1', verification: 'trusted', occurredAtMillis: now - 1, recordedAtMillis: now });
  }
  batch.set(db.doc(path('rewardPolicies', 'current')), { schemaVersion: 1, organizationId: org, version: 'test-v1', enabled: true,
    effectiveFromMillis: now - day, effectiveUntilMillis: now + day, timezone: 'Asia/Kuala_Lumpur', unknownHistoricalTier: 'base_only',
    exchangeRate: { version: 'test-v1', currency: 'MYR', pointsPerUnit: 1, unitValueMinor: 100 }, itemIds: ['item'],
    sources: [{ sourceId: 'synthetic', producerVersion: 'test-v1', basePoints: 5, maxEventAgeMillis: day, dailyEvents: 1, dailyAwardPoints: 5 }] });
  batch.set(db.doc(path('rewardItems', 'item')), { schemaVersion: 1, organizationId: org, itemId: 'item', title: 'Synthetic reward',
    active: true, pointCost: 5, valueMinor: 500, stock: 1, premiumOnly: false, exchangeRateVersion: 'test-v1' });
  await batch.commit();
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });
it('real Firestore retries award duplicates once and allocate the last stock to one owner', async () => {
  await Promise.all(Array.from({ length: 6 }, () => command('one', 'award', { eventId: 'one' })));
  expect((await db.doc(path('rewardBalances', 'one')).get()).data()?.points).toBe(5);
  expect((await db.collection(`orgs/${org}/rewardAwards`).get()).size).toBe(1);
  await command('two', 'award', { eventId: 'two' });
  const outcomes = await Promise.allSettled(['one', 'two'].map(uid => command(uid, 'redeem', { itemId: 'item', requestId: 'last-stock' })));
  expect(outcomes.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  expect((await db.doc(path('rewardItems', 'item')).get()).data()?.stock).toBe(0);
  const receipts = await db.collection(`orgs/${org}/rewardRedemptions`).get(); expect(receipts.size).toBe(1);
  const r = receipts.docs[0].data();
  await Promise.all(Array.from({ length: 5 }, () => command('admin', 'fulfil', { redemptionId: r.redemptionId })));
  expect((await receipts.docs[0].ref.get()).data()).toMatchObject({ status: 'fulfilled', fulfilledBy: 'admin', fulfilledAtMillis: now });
});
it('Members and Admin cannot bypass commands to read or forge trusted reward paths', async () => {
  const env = await initializeTestEnvironment({ projectId, firestore: { host: emulator.host, port: emulator.port, rules: readFileSync('../firebase/firestore.rules', 'utf8') } });
  try {
    for (const uid of ['one', 'admin']) {
      const client = env.authenticatedContext(uid, { email_verified: true }).firestore();
      for (const collection of ['rewardPolicies', 'rewardEvents', 'rewardAwards', 'rewardBalances', 'rewardCaps', 'rewardItems', 'rewardRedemptions']) {
        const ref = doc(client, path(collection, uid));
        await assertFails(getDoc(ref)); await assertFails(setDoc(ref, { points: 999, stock: 999, status: 'fulfilled' }));
      }
    }
  } finally { await env.cleanup(); }
});
