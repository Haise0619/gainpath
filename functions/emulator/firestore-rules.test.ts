import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs, serverTimestamp, deleteDoc } from 'firebase/firestore';
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
      'orgs/o/members/coach': { role: 'coach', status: 'active', branchIds: ['a'] },
      'orgs/o/members/suspended': { role: 'member', status: 'suspended', branchIds: ['a'] },
      'orgs/o/bookings/own': { memberId: 'member', coachId: 'coach', branchId: 'a' },
      'orgs/o/bookings/other': { memberId: 'other', coachId: 'coach', branchId: 'b' },
      'orgs/elsewhere/bookings/other': { memberId: 'other', coachId: 'coach', branchId: 'a' },
      'orgs/o/workoutSessions/own': { memberId: 'member' },
      'orgs/o/workoutConsents/member': { memberId: 'member', revokedAtMillis: null },
      'orgs/o/workoutConsents/admin': { memberId: 'admin', revokedAtMillis: null },
      'orgs/o/reports/branch-b': { branchId: 'b' },
      'orgs/o/content/draft': { status: 'draft' },
      'orgs/o/content/published': { status: 'published' },
      'orgs/o/exerciseVideos/squat': { exerciseName: 'Squat', muscleCategory: 'Lower body', videoUrl: '', isActive: true },
      'orgs/o/routineBlueprints/strength': { schemaVersion: 1, name: 'Strength', sessionDurationMin: 30,
        days: [{ dayNumber: 1, exercises: [{ exerciseId: 'squat', sets: 3, reps: 8 }] }] },
      'system/paymentIngress/events/event': { status: 'received' },
    };
    await Promise.all(Object.entries(documents).map(([path, data]) => setDoc(doc(db, path), data)));
  });
});
const dbFor = (uid: string, claims: Record<string, unknown> = {}) =>
  env.authenticatedContext(uid, { email_verified: true, ...claims }).firestore();

it('allows only owner get of server consent for verified active ordinary members', async () => {
  await assertSucceeds(getDoc(doc(dbFor('member'), 'orgs/o/workoutConsents/member')));
  await assertFails(getDocs(collection(dbFor('member'), 'orgs/o/workoutConsents')));
  for (const uid of ['other', 'staff', 'coach', 'admin', 'suspended']) {
    await assertFails(getDoc(doc(dbFor(uid), 'orgs/o/workoutConsents/member')));
  }
  await assertFails(getDoc(doc(dbFor('admin'), 'orgs/o/workoutConsents/admin')));
  await assertFails(getDoc(doc(dbFor('member', { email_verified: false }), 'orgs/o/workoutConsents/member')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'orgs/o/workoutConsents/member')));
  await assertFails(getDoc(doc(dbFor('member'), 'orgs/elsewhere/workoutConsents/member')));
  for (const uid of ['member', 'admin']) {
    const ref = doc(dbFor(uid), 'orgs/o/workoutConsents/member');
    await assertFails(setDoc(ref, { memberId: uid, revokedAtMillis: null }));
    await assertFails(updateDoc(ref, { revokedAtMillis: 1 }));
    await assertFails(deleteDoc(ref));
  }
});

it('preserves private workout owner/admin reads and forbids all client acceptance writes', async () => {
  for (const uid of ['member', 'admin']) {
    await assertSucceeds(getDoc(doc(dbFor(uid), 'orgs/o/workoutSessions/own')));
    const ref = doc(dbFor(uid), 'orgs/o/workoutSessions/own');
    await assertFails(setDoc(ref, { memberId: uid, status: 'accepted' }));
    await assertFails(updateDoc(ref, { status: 'accepted' }));
    await assertFails(deleteDoc(ref));
  }
  for (const uid of ['other', 'coach', 'staff', 'suspended']) {
    await assertFails(getDoc(doc(dbFor(uid), 'orgs/o/workoutSessions/own')));
  }
  await assertFails(getDocs(collection(dbFor('member'), 'orgs/o/workoutSessions')));
  expect((await assertSucceeds(getDocs(query(collection(dbFor('member'), 'orgs/o/workoutSessions'),
    where('memberId', '==', 'member'))))).size).toBe(1);
  await assertFails(getDoc(doc(dbFor('member', { email_verified: false }), 'orgs/o/workoutSessions/own')));
});

const fitnessProfile = () => ({
  schemaVersion: 1, gender: 'unspecified', age: 25, heightCm: 165, weightKg: 65,
  experience: 'beginner', activity: 'lightlyActive', goals: ['generalFitness'],
  updatedAt: serverTimestamp(),
});

const memberPreferences = () => ({
  schemaVersion: 1, pushNotifications: false, emailUpdates: false,
  voiceCoaching: false, updatedAt: serverTimestamp(),
});

it('stores only a verified member’s own bounded preferences', async () => {
  const own = doc(dbFor('member'), 'orgs/o/preferences/member');
  expect((await assertSucceeds(getDoc(own))).exists()).toBe(false);
  await assertSucceeds(setDoc(own, memberPreferences()));
  await assertSucceeds(updateDoc(own, { voiceCoaching: true, updatedAt: serverTimestamp() }));
  expect((await assertSucceeds(getDoc(own))).data()?.voiceCoaching).toBe(true);
  await assertFails(getDocs(collection(dbFor('member'), 'orgs/o/preferences')));
  await assertFails(deleteDoc(own));
  for (const uid of ['other', 'staff', 'coach', 'admin', 'suspended']) {
    await assertFails(getDoc(doc(dbFor(uid), 'orgs/o/preferences/member')));
    await assertFails(setDoc(doc(dbFor(uid), 'orgs/o/preferences/member'), memberPreferences()));
  }
  await assertFails(getDoc(doc(dbFor('member', { email_verified: false }), 'orgs/o/preferences/member')));
  await assertFails(setDoc(doc(dbFor('member'), 'orgs/elsewhere/preferences/member'), memberPreferences()));
  for (const bad of [{ role: 'admin' }, { pushNotifications: 'yes' },
      { emailUpdates: 1 }, { updatedAt: null }, { schemaVersion: 2 }]) {
    await assertFails(setDoc(own, { ...memberPreferences(), ...bad }));
  }
});

it('allows a verified member to create, read and edit only their private fitness profile', async () => {
  const own = doc(dbFor('member'), 'orgs/o/profiles/member');
  expect((await assertSucceeds(getDoc(own))).exists()).toBe(false);
  await assertSucceeds(setDoc(own, fitnessProfile()));
  await assertSucceeds(updateDoc(own, { weightKg: 70, updatedAt: serverTimestamp() }));
  expect((await assertSucceeds(getDoc(own))).data()?.weightKg).toBe(70);
  for (const uid of ['other', 'staff', 'coach', 'admin', 'suspended']) {
    await assertFails(getDoc(doc(dbFor(uid), 'orgs/o/profiles/member')));
    await assertFails(setDoc(doc(dbFor(uid), 'orgs/o/profiles/member'), fitnessProfile()));
  }
  await assertFails(getDocs(collection(dbFor('member'), 'orgs/o/profiles')));
  await assertFails(deleteDoc(own));
});

it('rejects unauthenticated, unverified, suspended, non-member and cross-organization profiles', async () => {
  for (const db of [env.unauthenticatedContext().firestore(), dbFor('member', { email_verified: false })]) {
    await assertFails(getDoc(doc(db, 'orgs/o/profiles/member')));
    await assertFails(setDoc(doc(db, 'orgs/o/profiles/member'), fitnessProfile()));
  }
  for (const uid of ['suspended', 'coach', 'staff', 'admin']) {
    await assertFails(setDoc(doc(dbFor(uid), `orgs/o/profiles/${uid}`), fitnessProfile()));
  }
  await assertFails(setDoc(doc(dbFor('member'), 'orgs/elsewhere/profiles/member'), fitnessProfile()));
  await assertFails(getDoc(doc(dbFor('member'), 'orgs/elsewhere/profiles/member')));
});

it('validates fitness profile fields and forbids privilege injection', async () => {
  const own = doc(dbFor('member'), 'orgs/o/profiles/member');
  const invalid = [
    { role: 'admin' }, { schemaVersion: 2 }, { schemaVersion: '1' },
    { age: 12 }, { age: 81 }, { age: 25.5 }, { heightCm: 129 }, { heightCm: 211 },
    { weightKg: 34 }, { weightKg: 161 }, { weightKg: '65' },
    { gender: 'unknown' }, { experience: 'expert' }, { activity: 'unknown' },
    { goals: [] }, { goals: ['unknown'] }, { goals: ['buildMuscle', 'buildMuscle'] },
    { goals: 'generalFitness' }, { updatedAt: null },
  ];
  for (const override of invalid) {
    await assertFails(setDoc(own, { ...fitnessProfile(), ...override }));
  }
  const { experience: _, ...incomplete } = fitnessProfile();
  await assertFails(setDoc(own, incomplete));
  await assertSucceeds(setDoc(own, fitnessProfile()));
  await assertFails(updateDoc(own, { role: 'coach', updatedAt: serverTimestamp() }));
});

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

it('published tutorial snapshots retain member scope without exposing staff catalog or drafts', async () => {
  const media = { schemaVersion: 1, kind: 'routine', status: 'published',
    exercises: [{ exerciseId: 'squat', videoUrl: 'https://media.example.test/squat.mp4' }] };
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'orgs/o/content/tutorial'), media);
    await setDoc(doc(context.firestore(), 'orgs/elsewhere/content/tutorial'), media);
    await setDoc(doc(context.firestore(), 'orgs/o/content/tutorial-draft'), { ...media, status: 'draft' });
  });
  const member = dbFor('member');
  const result = await assertSucceeds(getDoc(doc(member, 'orgs/o/content/tutorial')));
  expect(result.data()?.exercises).toEqual(media.exercises);
  await assertSucceeds(getDocs(query(collection(member, 'orgs/o/content'),
    where('status', '==', 'published'), where('kind', '==', 'routine'))));
  await assertFails(getDoc(doc(member, 'orgs/o/content/tutorial-draft')));
  await assertFails(getDoc(doc(member, 'orgs/elsewhere/content/tutorial')));
  await assertFails(getDoc(doc(member, 'orgs/o/exerciseVideos/squat')));
  await assertFails(getDoc(doc(dbFor('member', { email_verified: false }), 'orgs/o/content/tutorial')));
  await assertFails(getDoc(doc(dbFor('suspended'), 'orgs/o/content/tutorial')));
  await assertFails(setDoc(doc(member, 'orgs/o/content/tutorial'), media));
});

it('allows Admin and Staff to create, list, and update exercises and routine blueprints without hard delete', async () => {
  for (const uid of ['staff', 'admin']) {
    const exercise = doc(dbFor(uid), `orgs/o/exerciseVideos/new-${uid}`);
    await assertSucceeds(setDoc(exercise, {
      exerciseName: 'Deadlift', muscleCategory: 'Lower body', videoUrl: '', isActive: true,
      schemaVersion: 1, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(exercise, { exerciseName: 'Romanian deadlift', updatedAt: serverTimestamp() }));
    await assertSucceeds(getDoc(exercise));
    await assertSucceeds(getDocs(collection(dbFor(uid), 'orgs/o/exerciseVideos')));
    const blueprint = doc(dbFor(uid), `orgs/o/routineBlueprints/new-${uid}`);
    const source = { schemaVersion: 1, name: 'Strength', sessionDurationMin: 30,
      days: [{ dayNumber: 1, exercises: [{ exerciseId: 'squat', sets: 3, reps: 8 }] }],
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(), updatedBy: uid };
    await assertSucceeds(setDoc(blueprint, source));
    await assertSucceeds(updateDoc(blueprint, { name: 'Strength A', updatedAt: serverTimestamp(), updatedBy: uid }));
    await assertSucceeds(getDocs(collection(dbFor(uid), 'orgs/o/routineBlueprints')));
    await assertFails(deleteDoc(blueprint));
  }
});

it('denies member, coach, unverified, cross-organization, malformed, and published-content writes', async () => {
  const exerciseData = { exerciseName: 'Squat', muscleCategory: 'Lower body', videoUrl: '', isActive: true,
    schemaVersion: 1, createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
  const blueprintData = { schemaVersion: 1, name: 'Strength', sessionDurationMin: 30,
    days: [{ dayNumber: 1, exercises: [{ exerciseId: 'squat', sets: 3, reps: 8 }] }],
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), updatedBy: 'staff' };
  for (const uid of ['member', 'coach', 'suspended']) {
    await assertFails(setDoc(doc(dbFor(uid), `orgs/o/exerciseVideos/${uid}`), exerciseData));
    await assertFails(setDoc(doc(dbFor(uid), `orgs/o/routineBlueprints/${uid}`), blueprintData));
  }
  await assertFails(setDoc(doc(dbFor('staff', { email_verified: false }), 'orgs/o/exerciseVideos/unverified'), exerciseData));
  await assertFails(setDoc(doc(dbFor('staff'), 'orgs/elsewhere/exerciseVideos/cross-org'), exerciseData));
  await assertFails(setDoc(doc(dbFor('staff'), 'orgs/o/exerciseVideos/arbitrary'), { ...exerciseData, role: 'admin' }));
  await assertFails(setDoc(doc(dbFor('staff'), 'orgs/o/routineBlueprints/arbitrary'), { ...blueprintData, assignedMembers: 12 }));
  await assertFails(setDoc(doc(dbFor('staff'), 'orgs/o/content/client-write'), { ...blueprintData, kind: 'routine', status: 'published' }));
  await assertFails(deleteDoc(doc(dbFor('admin'), 'orgs/o/exerciseVideos/squat')));
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
