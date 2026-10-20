// Synthetic identities and synthetic App Check transport ONLY in local emulators.
// Functions emulator skips cryptographic verification: this is NOT attestation.
const assert = require('node:assert/strict');
const { initializeApp: adminApp, deleteApp: deleteAdminApp } = require('firebase-admin/app');
const { getAuth: adminAuth } = require('firebase-admin/auth');
const { getFirestore: adminFirestore } = require('firebase-admin/firestore');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInWithEmailAndPassword } = require('firebase/auth');
const { initializeAppCheck, CustomProvider } = require('firebase/app-check');
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require('firebase/functions');
const { getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc } = require('firebase/firestore');

async function main() {
  if (process.env.GCLOUD_PROJECT !== 'demo-gainpath'
    || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:19093'
    || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18393') {
    throw Error('Dedicated isolated demo-gainpath emulators required.');
  }
  const app = adminApp({ projectId: 'demo-gainpath' }, 'b3-smoke');
  const db = adminFirestore(app), identity = adminAuth(app), clients = [];
  const organizationId = 'b3-smoke', root = `orgs/${organizationId}`, coachId = 'b3-coach';
  const password = 'SyntheticB3Only123!';
  try {
    const batch = db.batch();
    batch.set(db.doc(root), { status: 'active' });
    batch.set(db.doc(`${root}/branches/main`), { status: 'active' });
    batch.set(db.doc(`${root}/settings/booking`), { schemaVersion: 1, policyVersion: 'booking-v1',
      timeZone: 'Asia/Kuala_Lumpur', maxActiveBookingsPerMemberPerDay: 2, holdMinutes: 15 });
    for (const [uid, role] of [['b3-member', 'member'], ['b3-other', 'member'], [coachId, 'coach'],
      ['b3-admin', 'admin'], ['b3-staff', 'staff'], ['b3-cross', 'member']]) {
      await identity.createUser({ uid, email: `${uid}@b3-fixture.test`, password, emailVerified: true });
      batch.set(db.doc(`users/${uid}`), { organizationId: uid === 'b3-cross' ? 'elsewhere' : organizationId });
      batch.set(db.doc(`${root}/members/${uid}`), { organizationId, role, status: 'active', branchIds: role === 'admin' ? [] : ['main'] });
    }
    await batch.commit();
    async function client(uid, attested = true) {
      const instance = initializeApp({ projectId: 'demo-gainpath', apiKey: 'synthetic-emulator-key',
        appId: 'synthetic-b3-emulator-app' }, `b3-${uid}-${clients.length}`);
      clients.push(instance);
      if (attested) {
        // No Firebase exchange/registered debug secret. Never print this header.
        const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
        initializeAppCheck(instance, { isTokenAutoRefreshEnabled: false, provider: new CustomProvider({
          getToken: async () => ({ token: `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
            sub: 'synthetic-b3-emulator-app', iss: 'emulator-fixture-only', aud: 'demo-gainpath',
            iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600,
          })}.emulator-only`, expireTimeMillis: Date.now() + 3600000 }),
        }) });
      }
      const auth = getAuth(instance);
      connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, { disableWarnings: true });
      await signInWithEmailAndPassword(auth, `${uid}@b3-fixture.test`, password);
      const functions = getFunctions(instance); connectFunctionsEmulator(functions, '127.0.0.1', 18533);
      const firestore = getFirestore(instance); connectFirestoreEmulator(firestore, '127.0.0.1', 18393);
      return { uid, firestore, call: async (name, input) => (await httpsCallable(functions, name)(input)).data };
    }
    const coach = await client(coachId), admin = await client('b3-admin');
    const members = [await client('b3-member'), await client('b3-other')];
    await coach.call('saveCoachProfileCommand', { schemaVersion: 1, organizationId, requestId: 'profile-create', expectedRevision: 0,
      patch: { displayName: 'Synthetic Coach', specialty: 'Strength', bio: 'Isolated emulator fixture',
        specializationTags: ['Strength'], yearsExperience: null } });
    await admin.call('setCoachDirectoryStatusCommand', { schemaVersion: 1, organizationId, coachId,
      requestId: 'profile-publish', action: 'publish', expectedProfileRevision: 1, expectedPublicRevision: 0,
      expectedCoachBranchIds: ['main'] });
    assert.equal((await getDoc(doc(members[0].firestore, `${root}/coaches/${coachId}`))).data().status, 'published');
    await assert.rejects(getDoc(doc(members[0].firestore, `${root}/coachProfiles/${coachId}`)), e => e.code === 'permission-denied');

    const availabilityRequest = { schemaVersion: 1, organizationId, coachId, dayCount: 2 };
    const context = await coach.call('getCoachAvailabilityCommand', availabilityRequest);
    const day = context.days.find(d => d.editable); assert.ok(day);
    const window = { branchId: 'main', startAtMillis: day.boundaries[20].atMillis, endAtMillis: day.boundaries[24].atMillis };
    await coach.call('saveCoachAvailabilityDayCommand', { schemaVersion: 1, organizationId, requestId: 'availability-create',
      localDate: day.localDate, expectedRevision: 0, expectedPolicyVersion: context.policyVersion,
      expectedTimeZone: context.timeZone, expectedCoachBranchIds: context.assignedBranchIds, windows: [window] });
    const schedule = await members[0].call('getCoachAvailabilityCommand', availabilityRequest);
    assert.deepEqual(schedule.days.find(d => d.localDate === day.localDate).windows, [window]);

    const optionsInput = { schemaVersion: 1, organizationId, coachId, localDate: day.localDate, durationMinutes: 60 };
    const options = await members[0].call('getMemberBookingOptionsCommand', optionsInput);
    assert.equal(options.options.length, 3);
    const selected = options.options[0];
    const requests = members.map((m, i) => ({ schemaVersion: 1, organizationId, coachId, memberId: m.uid,
      branchId: selected.branchId, startAtMillis: selected.startAtMillis, durationMinutes: 60, requestId: `hold-${i}` }));
    const race = await Promise.allSettled(members.map((m, i) => m.call('createBookingHold', requests[i])));
    assert.equal(race.filter(r => r.status === 'fulfilled').length, 1);
    assert.equal(race.filter(r => r.status === 'rejected' && r.reason.code === 'functions/aborted').length, 1);
    const winnerIndex = race.findIndex(r => r.status === 'fulfilled'), winner = members[winnerIndex];
    const request = requests[winnerIndex], hold = race[winnerIndex].value;
    assert.equal(hold.status, 'pending_hold');
    assert.deepEqual(await winner.call('createBookingHold', request), hold);
    await assert.rejects(winner.call('createBookingHold', { ...request, durationMinutes: 30 }), e => e.code === 'functions/already-exists');
    const record = (await db.doc(`${root}/bookings/${hold.bookingId}`).get()).data();
    assert.equal(record.memberId, winner.uid); assert.equal(record.status, 'pending_hold');
    assert.equal((await db.collection(`${root}/bookings`).get()).size, 1);
    const locks = await db.collection(`${root}/slotLocks`).get();
    assert.equal(locks.size, 2); assert.ok(locks.docs.every(d => d.data().bookingId === hold.bookingId));

    const listInput = { schemaVersion: 1, organizationId };
    const pages = await Promise.all([winner.call('getBookingListCommand', listInput), coach.call('getBookingListCommand', listInput),
      admin.call('getBookingListCommand', { ...listInput, coachId })]);
    const expiryParts = new Intl.DateTimeFormat('en-CA', { timeZone: context.timeZone, year: 'numeric', month: '2-digit', day: '2-digit' })
      .formatToParts(new Date(hold.holdExpiresAtMillis));
    const expiryPart = type => expiryParts.find(p => p.type === type).value;
    const expiryDate = `${expiryPart('year')}-${expiryPart('month')}-${expiryPart('day')}`;
    for (const page of pages) {
      assert.equal(page.records.length, 1);
      assert.equal(page.records[0].bookingId, hold.bookingId);
      assert.equal(page.records[0].status, 'pending_hold');
      assert.equal(page.records[0].holdExpiresAtMillis, hold.holdExpiresAtMillis);
      assert.ok(page.records[0].expiryLabel.startsWith(expiryDate));
      assert.equal(Object.hasOwn(page.records[0], 'createdBy'), false);
    }
    assert.equal((await members[1 - winnerIndex].call('getBookingListCommand', listInput)).records.length, 0);
    assert.equal((await winner.call('getMemberBookingOptionsCommand', optionsInput)).options.length, 1);
    assert.equal((await getDoc(doc(winner.firestore, `${root}/bookings/${hold.bookingId}`))).data().bookingId, hold.bookingId);
    await assert.rejects(setDoc(doc(winner.firestore, `${root}/bookings/${hold.bookingId}`), { status: 'confirmed' }), e => e.code === 'permission-denied');
    const staff = await client('b3-staff'), cross = await client('b3-cross');
    await assert.rejects(staff.call('getBookingListCommand', { ...listInput, coachId }), e => e.code === 'functions/permission-denied');
    await assert.rejects(cross.call('getBookingListCommand', listInput), e => e.code === 'functions/permission-denied');
    await assert.rejects(cross.call('getMemberBookingOptionsCommand', optionsInput), e => e.code === 'functions/permission-denied');

    const protectedSnapshot = async () => {
      const result = {};
      for (const name of ['bookings', 'slotLocks', 'bookingDays', 'commandReceipts', 'jobs']) {
        const rows = await db.collection(`${root}/${name}`).get();
        result[name] = rows.docs.map(d => [d.id, d.data()]);
      }
      return result;
    };
    const before = await protectedSnapshot(), missingHeader = await client(winner.uid, false);
    await assert.rejects(missingHeader.call('getMemberBookingOptionsCommand', optionsInput), e => e.code === 'functions/unauthenticated');
    await assert.rejects(missingHeader.call('createBookingHold', { ...request, requestId: 'missing-header',
      startAtMillis: selected.startAtMillis + 3600000 }), e => e.code === 'functions/unauthenticated');
    const cancelInput = { schemaVersion: 1, organizationId, bookingId: hold.bookingId, requestId: 'cancel-hold' };
    if (process.argv.includes('--b4')) {
      await assert.rejects(missingHeader.call('cancelBookingHoldCommand', cancelInput), e => e.code === 'functions/unauthenticated');
      await assert.rejects(members[1 - winnerIndex].call('cancelBookingHoldCommand', cancelInput), e => e.code === 'functions/permission-denied');
      await assert.rejects(coach.call('cancelBookingHoldCommand', cancelInput), e => e.code === 'functions/permission-denied');
      await assert.rejects(admin.call('cancelBookingHoldCommand', cancelInput), e => e.code === 'functions/permission-denied');
      await assert.rejects(cross.call('cancelBookingHoldCommand', cancelInput), e => e.code === 'functions/permission-denied');
    }
    assert.deepEqual(await protectedSnapshot(), before);
    if (process.argv.includes('--b4')) {
      const cancelled = await winner.call('cancelBookingHoldCommand', cancelInput);
      assert.equal(cancelled.status, 'cancelled');
      assert.deepEqual(await winner.call('cancelBookingHoldCommand', cancelInput), cancelled);
      for (const [actor, input] of [[winner, listInput], [coach, listInput], [admin, { ...listInput, coachId }]]) {
        const page = await actor.call('getBookingListCommand', input);
        assert.equal(page.records[0].bookingId, hold.bookingId); assert.equal(page.records[0].status, 'cancelled');
      }
      assert.equal((await winner.call('getMemberBookingOptionsCommand', optionsInput)).options.length, 3);
      const next = await winner.call('createBookingHold', { ...request, requestId: 'replacement-after-cancel' });
      // Real Firestore batch adapter with a deterministic server clock; NOT a
      // claim that Cloud Scheduler/IAM has been exercised by this local smoke.
      const { runBookingExpiryBatch } = require('../lib/modules/coaching/booking-expiry-worker');
      const expired = await runBookingExpiryBatch(db, () => next.holdExpiresAtMillis);
      assert.equal(expired.processed, 1); assert.equal(expired.retry, 0);
      assert.equal((await db.doc(`${root}/bookings/${next.bookingId}`).get()).data().status, 'expired');
      for (const [actor, input] of [[winner, listInput], [coach, listInput], [admin, { ...listInput, coachId }]]) {
        assert.equal((await actor.call('getBookingListCommand', input)).records.find(r => r.bookingId === next.bookingId).status, 'expired');
      }
      console.log('B4 SDK emulator smoke passed: owner cancellation/replay, role and missing-header denial, three-role terminal visibility, replacement hold and real Firestore expiry batch. Scheduler triggering and cryptographic App Check remain unverified.');
    }
    // Withdrawal blocks new options, not authorized persisted visibility/replay.
    await admin.call('setCoachDirectoryStatusCommand', { schemaVersion: 1, organizationId, coachId,
      requestId: 'profile-deactivate', action: 'deactivate', expectedPublicRevision: 1 });
    await assert.rejects(winner.call('getMemberBookingOptionsCommand', optionsInput), e => e.code === 'functions/failed-precondition');
    assert.deepEqual(await winner.call('createBookingHold', request), hold);
    assert.ok((await coach.call('getBookingListCommand', listInput)).records.some(r => r.bookingId === hold.bookingId));
    for (const name of ['workoutSessions', 'workoutConsents']) assert.ok((await db.collection(`${root}/${name}`).get()).empty);
    console.log('B3 SDK emulator smoke passed: trusted profile/publication and B2 schedule → eligible options → one concurrent pending hold → persisted same ID/status/expiry across Member/Coach/Admin; replay, scoped denial, two locks, missing-App-Check-header zero writes. Synthetic transport only; no cryptographic attestation.');
  } finally {
    await Promise.all(clients.map(deleteApp)); await db.terminate(); await deleteAdminApp(app);
  }
}
main().catch(error => { console.error('B3 SDK emulator smoke failed:', error.code ?? error.name); process.exitCode = 1; });
