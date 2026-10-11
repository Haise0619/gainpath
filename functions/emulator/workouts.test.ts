import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';
import { acknowledgeWorkoutConsent, revokeWorkoutConsent, submitWorkoutSession } from '../src/modules/workouts/workout-service';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { type CallableRequest } from 'firebase-functions/v2/https';
import { acknowledgeWorkoutConsentCommand, revokeWorkoutConsentCommand, submitWorkoutSessionCommand } from '../src/modules/workouts/workout-callables';
import { actor, time, consentCommand, tuple, submission, workoutSeeds } from '../test/workout-fixture';

let app: App;
let db: Firestore;
beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Firestore emulator required; never target a live project.');
  app = initializeApp({ projectId: 'demo-gainpath' });
  db = getFirestore(app);
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });
beforeEach(async () => {
  await db.recursiveDelete(db.collection('orgs'));
  await db.recursiveDelete(db.collection('users'));
  const batch = db.batch();
  for (const [path, data] of Object.entries(workoutSeeds)) batch.set(db.doc(path), data);
  await batch.commit();
});
const consent = () => acknowledgeWorkoutConsent(new FirestoreStore(db), actor, consentCommand, () => time - 120000);
const submit = (data: unknown) => submitWorkoutSession(new FirestoreStore(db), actor, data,
  { clock: () => time, enabledTuples: [tuple] });
async function input() { return { ...submission, consentAcknowledgementId: (await consent()).acknowledgementId }; }

it('deduplicates real concurrent consent transactions', async () => {
  const results = await Promise.all([consent(), consent(), consent()]);
  expect(results[0]).toEqual(results[1]);
  expect(results[1]).toEqual(results[2]);
  expect((await db.collection('orgs/gainpath/workoutConsents').get()).size).toBe(1);
  expect((await db.collection('orgs/gainpath/commandReceipts').get()).size).toBe(1);
});
it('deduplicates command and session retries under real transaction contention', async () => {
  const data = await input();
  const results = await Promise.all([submit(data), submit(data), submit({ ...data, requestId: 'upload-2' })]);
  expect(results[0]).toEqual(results[1]);
  expect(results[2].acceptedAtMillis).toBe(results[0].acceptedAtMillis);
  expect((await db.collection('orgs/gainpath/workoutSessions').get()).size).toBe(1);
  expect((await db.collection('orgs/gainpath/commandReceipts').get()).size).toBe(3);
});
it('allows only one competing payload to own a session', async () => {
  const data = await input();
  const results = await Promise.allSettled([submit(data), submit({ ...data, requestId: 'upload-2', repetitions: 9 })]);
  expect(results.filter(result => result.status === 'fulfilled')).toHaveLength(1);
  const rejected = results.find(result => result.status === 'rejected') as PromiseRejectedResult;
  expect(rejected.reason.code).toBe('already-exists');
  expect((await db.collection('orgs/gainpath/workoutSessions').get()).size).toBe(1);
});
it('serializes revocation with acceptance and rejects every post-revocation retry', async () => {
  const data = await input();
  const revoke = { schemaVersion: 1, requestId: 'revoke-1', organizationId: 'gainpath', memberId: actor.uid,
    consentVersion: 'pose-local-summary-v1', acknowledgementId: data.consentAcknowledgementId };
  const results = await Promise.allSettled([
    submit(data), revokeWorkoutConsent(new FirestoreStore(db), actor, revoke, () => time),
  ]);
  expect(results[1].status).toBe('fulfilled');
  // Either serial order is legal: a prior acceptance or rejection after revoke.
  if (results[0].status === 'rejected') expect(results[0].reason.code).toBe('failed-precondition');
  expect((await db.doc(`orgs/gainpath/workoutConsents/${actor.uid}`).get()).data()?.revokedAtMillis).toBe(time);
  await expect(submit(data)).rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(consent()).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('keeps runtime acceptance closed even with real valid server consent and catalog', async () => {
  const data = await input();
  await expect(submitWorkoutSession(new FirestoreStore(db), actor, data, { clock: () => time }))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  expect((await db.collection('orgs/gainpath/workoutSessions').get()).empty).toBe(true);
});

it('wires callable consent/revoke receipts and maps malformed/auth/closed-policy errors', async () => {
  const request = (data: unknown, auth: unknown = actor) => ({ data, auth }) as CallableRequest;
  await expect(acknowledgeWorkoutConsentCommand.run(request(consentCommand, null)))
    .rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(acknowledgeWorkoutConsentCommand.run(request({ ...consentCommand, consented: false })))
    .rejects.toMatchObject({ code: 'invalid-argument' });
  await expect(acknowledgeWorkoutConsentCommand.run(request(consentCommand, { ...actor, token: { email_verified: false } })))
    .rejects.toMatchObject({ code: 'permission-denied' });
  const acknowledgement = await acknowledgeWorkoutConsentCommand.run(request(consentCommand));
  expect(acknowledgement.memberId).toBe(actor.uid);
  expect(acknowledgement.acknowledgedAtMillis).toBeGreaterThan(0);
  const clockNow = Date.now();
  const data = { ...submission, startedAtMillis: acknowledgement.acknowledgedAtMillis,
    endedAtMillis: clockNow + 1, consentAcknowledgementId: acknowledgement.acknowledgementId,
    repetitions: 0, trackedDurationMillis: 0, rejectedDurationMillis: 0, formScorePercent: null };
  await expect(submitWorkoutSessionCommand.run(request(data)))
    .rejects.toMatchObject({ code: 'failed-precondition', message: expect.stringContaining('not enabled') });
  await expect(submitWorkoutSessionCommand.run(request({ ...data, enabledTuples: [tuple] })))
    .rejects.toMatchObject({ code: 'invalid-argument' });
  const revocation = await revokeWorkoutConsentCommand.run(request({ schemaVersion: 1, requestId: 'revoke-1',
    organizationId: 'gainpath', memberId: actor.uid, consentVersion: 'pose-local-summary-v1',
    acknowledgementId: acknowledgement.acknowledgementId }));
  expect(revocation.revokedAtMillis).toBeGreaterThanOrEqual(acknowledgement.acknowledgedAtMillis);
  expect((await db.collection('orgs/gainpath/workoutSessions').get()).empty).toBe(true);
});
