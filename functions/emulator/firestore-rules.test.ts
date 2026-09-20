import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';

let env: RulesTestEnvironment;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run using test:emulator; never target a live project.');
  env = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: {
    rules: readFileSync('../firebase/firestore.rules', 'utf8'),
  } });
});
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    const documents = {
      'orgs/o/members/member': { role: 'member', status: 'active', branchIds: ['a'], displayName: 'Member' },
      'orgs/o/members/other': { role: 'member', status: 'active', branchIds: ['b'] },
      'orgs/o/members/staff': { role: 'staff', status: 'active', branchIds: ['a'] },
      'orgs/o/members/admin': { role: 'admin', status: 'active', branchIds: [] },
      'orgs/o/members/suspended': { role: 'member', status: 'suspended', branchIds: ['a'] },
      'orgs/o/bookings/own': { memberId: 'member', coachId: 'coach', branchId: 'a' },
      'orgs/o/bookings/other': { memberId: 'other', coachId: 'coach', branchId: 'b' },
      'orgs/elsewhere/bookings/other': { memberId: 'other', coachId: 'coach', branchId: 'a' },
      'orgs/o/workoutSessions/own': { memberId: 'member' },
      'orgs/o/reports/branch-b': { branchId: 'b' },
      'orgs/o/content/draft': { status: 'draft' },
      'orgs/o/content/published': { status: 'published' },
      'system/paymentIngress/events/event': { status: 'received' },
    };
    await Promise.all(Object.entries(documents).map(([path, data]) => setDoc(doc(db, path), data)));
  });
});
const dbFor = (uid: string, claims: Record<string, unknown> = {}) =>
  env.authenticatedContext(uid, { email_verified: true, ...claims }).firestore();

it('allows an owner and rejects another member, unauthenticated and cross-organization reads', async () => {
  await assertSucceeds(getDoc(doc(dbFor('member'), 'orgs/o/bookings/own')));
  await assertFails(getDoc(doc(dbFor('other'), 'orgs/o/bookings/own')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'orgs/o/bookings/own')));
  await assertFails(getDoc(doc(dbFor('admin'), 'orgs/elsewhere/bookings/other')));
});
it('scopes staff bookings, reports and membership reads to assigned branches', async () => {
  await assertSucceeds(getDoc(doc(dbFor('staff'), 'orgs/o/bookings/own')));
  await assertFails(getDoc(doc(dbFor('staff'), 'orgs/o/bookings/other')));
  await assertFails(getDoc(doc(dbFor('staff'), 'orgs/o/reports/branch-b')));
  await assertFails(getDoc(doc(dbFor('staff'), 'orgs/o/members/other')));
  await assertSucceeds(getDoc(doc(dbFor('admin'), 'orgs/o/bookings/other')));
});
it('denies stale claim escalation and suspended profile edits', async () => {
  await assertFails(getDoc(doc(dbFor('other', { role: 'admin' }), 'orgs/o/bookings/own')));
  await assertFails(updateDoc(doc(dbFor('suspended'), 'orgs/o/members/suspended'), { displayName: 'Changed' }));
  await assertFails(updateDoc(doc(dbFor('member'), 'orgs/o/members/member'), { role: 'admin' }));
  await assertSucceeds(updateDoc(doc(dbFor('member'), 'orgs/o/members/member'), { displayName: 'Changed' }));
});
it('protects server-owned writes even from admin client SDKs', async () => {
  for (const path of ['bookings/new', 'slotLocks/new', 'bookingDays/new', 'jobs/new', 'commandReceipts/new',
    'content/new', 'coaches/new', 'workoutSessions/new', 'rewardLedger/new', 'settings/booking']) {
    await assertFails(setDoc(doc(dbFor('admin'), `orgs/o/${path}`), { status: 'published' }));
  }
  await assertFails(getDoc(doc(dbFor('admin'), 'system/paymentIngress/events/event')));
});
it('only exposes published content to ordinary members', async () => {
  await assertSucceeds(getDoc(doc(dbFor('member'), 'orgs/o/content/published')));
  await assertFails(getDoc(doc(dbFor('member'), 'orgs/o/content/draft')));
});
it('lets an unverified account read only its own assignment', async () => {
  const unverified = dbFor('member', { email_verified: false });
  await assertSucceeds(getDoc(doc(unverified, 'orgs/o/members/member')));
  await assertFails(getDoc(doc(unverified, 'orgs/o/content/published')));
  await assertFails(getDoc(doc(unverified, 'orgs/o/bookings/own')));
});
it('requires query constraints rather than filtering forbidden results', async () => {
  const own = query(collection(dbFor('member'), 'orgs/o/bookings'), where('memberId', '==', 'member'));
  expect((await assertSucceeds(getDocs(own))).size).toBe(1);
  await assertFails(getDocs(collection(dbFor('member'), 'orgs/o/bookings')));
  const staff = query(collection(dbFor('staff'), 'orgs/o/bookings'), where('branchId', '==', 'a'));
  expect((await assertSucceeds(getDocs(staff))).size).toBe(1);
});
