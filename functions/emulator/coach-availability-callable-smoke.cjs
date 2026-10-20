// Real Auth + callable HTTP + Firestore smoke, never a live-project fixture.
const assert = require('node:assert/strict');
const { initializeApp: adminApp, deleteApp: deleteAdminApp } = require('firebase-admin/app');
const { getAuth: adminAuth } = require('firebase-admin/auth');
const { getFirestore: adminFirestore } = require('firebase-admin/firestore');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInWithEmailAndPassword } = require('firebase/auth');
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require('firebase/functions');
const { getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc } = require('firebase/firestore');

async function main() {
  if (process.env.GCLOUD_PROJECT !== 'demo-gainpath' || !process.env.FIREBASE_AUTH_EMULATOR_HOST?.startsWith('127.0.0.1:') || !process.env.FIRESTORE_EMULATOR_HOST?.startsWith('127.0.0.1:')) throw Error('Isolated local emulators required.');
  const app = adminApp({ projectId: 'demo-gainpath' }, 'b2-callable-smoke'), db = adminFirestore(app), identity = adminAuth(app);
  const root = 'orgs/b2-smoke', clients = [];
  try {
    // This isolated project owns these synthetic IDs; no production account exists.
    const batch = db.batch(); batch.set(db.doc(root), { status: 'active' });
    for (const id of ['main', 'other']) batch.set(db.doc(`${root}/branches/${id}`), { status: 'active' });
    batch.set(db.doc(`${root}/settings/booking`), { schemaVersion: 1, policyVersion: 'booking-v1', timeZone: 'Asia/Kuala_Lumpur', maxActiveBookingsPerMemberPerDay: 2, holdMinutes: 15 });
    batch.set(db.doc(`${root}/coaches/coach`), { schemaVersion: 1, status: 'published', branchIds: ['main', 'other'], displayName: 'Synthetic Coach', specialty: 'Strength', bio: 'Emulator fixture', specializationTags: ['Strength'], yearsExperience: null, revision: 1, sourceRevision: 1, createdAtMillis: 1, updatedAtMillis: 1, publishedAtMillis: 1 });
    for (const uid of ['coach', 'member', 'admin', 'staff', 'cross-org']) {
      const role = uid === 'cross-org' ? 'member' : uid;
      batch.set(db.doc(`users/${uid}`), { organizationId: uid === 'cross-org' ? 'elsewhere' : 'b2-smoke' });
      batch.set(db.doc(`${root}/members/${uid}`), { organizationId: 'b2-smoke', role, status: 'active', branchIds: role === 'coach' ? ['main', 'other'] : role === 'admin' ? [] : ['main'] });
      await identity.createUser({ uid, email: `${uid}@b2-fixture.test`, password: 'SyntheticFixtureOnly123!', emailVerified: true });
    }
    await batch.commit();
    async function client(uid) {
      const instance = initializeApp({ projectId: 'demo-gainpath', apiKey: 'synthetic-emulator-key', appId: 'synthetic-emulator-app' }, `b2-${uid}`); clients.push(instance);
      const auth = getAuth(instance); connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, { disableWarnings: true });
      await signInWithEmailAndPassword(auth, `${uid}@b2-fixture.test`, 'SyntheticFixtureOnly123!');
      const functions = getFunctions(instance); connectFunctionsEmulator(functions, '127.0.0.1', 18501);
      const firestore = getFirestore(instance); connectFirestoreEmulator(firestore, '127.0.0.1', 18380);
      return { call: async (name, input) => (await httpsCallable(functions, name)(input)).data, firestore };
    }
    const coach = await client('coach'), member = await client('member'), admin = await client('admin');
    const query = { schemaVersion: 1, organizationId: 'b2-smoke', coachId: 'coach', dayCount: 7 };
    const context = await coach.call('getCoachAvailabilityCommand', query);
    const day = context.days.find(d => d.editable); assert.ok(day);
    const windows = [{ branchId: 'main', startAtMillis: day.boundaries[20].atMillis, endAtMillis: day.boundaries[22].atMillis }];
    const save = { schemaVersion: 1, organizationId: 'b2-smoke', requestId: 'create', localDate: day.localDate, expectedRevision: 0, expectedPolicyVersion: context.policyVersion, expectedTimeZone: context.timeZone, expectedCoachBranchIds: context.assignedBranchIds, windows };
    const created = await coach.call('saveCoachAvailabilityDayCommand', save); assert.equal(created.revision, 1);
    assert.deepEqual(await coach.call('saveCoachAvailabilityDayCommand', save), created);
    for (const actor of [member, admin]) {
      const result = await actor.call('getCoachAvailabilityCommand', query);
      const loaded = result.days.find(d => d.localDate === day.localDate);
      assert.deepEqual(loaded.windows, windows); assert.ok(loaded.displayTimes.every(t => t.label.includes('GMT+8')));
    }
    await assert.rejects(admin.call('saveCoachAvailabilityDayCommand', save), e => e.code === 'functions/permission-denied');
    const changed = { ...save, requestId: 'edit', expectedRevision: 1, windows: [{ ...windows[0], endAtMillis: day.boundaries[23].atMillis }] };
    await coach.call('saveCoachAvailabilityDayCommand', changed);
    await assert.rejects(coach.call('saveCoachAvailabilityDayCommand', { ...save, requestId: 'stale' }), e => e.code === 'functions/aborted');
    const cross = await client('cross-org'), staff = await client('staff');
    for (const denied of [cross, staff]) await assert.rejects(denied.call('getCoachAvailabilityCommand', query), e => e.code === 'functions/permission-denied');
    const path = `${root}/coachAvailability/coach/days/${day.localDate}`;
    for (const actor of [coach, member, admin]) {
      await assert.rejects(getDoc(doc(actor.firestore, path)), e => e.code === 'permission-denied');
      await assert.rejects(setDoc(doc(actor.firestore, path), { schemaVersion: 1, windows: [] }), e => e.code === 'permission-denied');
    }
    await coach.call('saveCoachAvailabilityDayCommand', { ...save, requestId: 'remove', expectedRevision: 2, windows: [] });
    assert.equal((await db.doc(path).get()).data().revision, 3);
    assert.deepEqual((await member.call('getCoachAvailabilityCommand', query)).days.find(d => d.localDate === day.localDate).windows, []);
    for (const name of ['bookings', 'slotLocks', 'jobs', 'workoutSessions', 'workoutConsents']) assert.ok((await db.collection(`${root}/${name}`).get()).empty);
    console.log('B2 real callable smoke passed: verified synthetic Coach CRUD → persisted Firebase emulator → Member/Admin reads; scoped denial, replay, stale revision and direct-access denial. No booking/workout mutation.');
  } finally {
    await Promise.all(clients.map(deleteApp)); await db.terminate(); await deleteAdminApp(app);
  }
}
main().catch(error => { console.error('B2 callable smoke failed:', error.code ?? error.name); process.exitCode = 1; });
