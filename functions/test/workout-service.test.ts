import { beforeEach, expect, it } from 'vitest';
import { acknowledgeWorkoutConsent, revokeWorkoutConsent, submitWorkoutSession } from '../src/modules/workouts/workout-service';
import { parseSubmitWorkoutSession } from '../src/modules/workouts/workout-validation';
import { keyOf } from '../src/platform/idempotency';
import { MemoryStore } from './memory-store';

import { time, actor, consentCommand, tuple, submission, workoutSeeds } from './workout-fixture';
const seedWorkout = (store: MemoryStore) => {
  for (const [path, data] of Object.entries(workoutSeeds)) store.documents.set(path, structuredClone(data));
};
let store: MemoryStore;
beforeEach(() => { store = new MemoryStore(); seedWorkout(store); });
const consent = () => acknowledgeWorkoutConsent(store, actor, consentCommand, () => time - 120000);
async function input() { return { ...submission, consentAcknowledgementId: (await consent()).acknowledgementId }; }
const submit = (data: unknown, auth = actor) => submitWorkoutSession(store, auth, data,
  { clock: () => time, enabledTuples: [tuple] });

it('issues bounded server consent with stable concurrent retry', async () => {
  const [a, b] = await Promise.all([consent(), consent()]);
  expect(a).toEqual(b);
  expect(a.acknowledgedAtMillis).toBe(time - 120000);
  expect(a.acknowledgementId).toMatch(/^[a-f0-9]{64}$/);
  expect(store.documents.size).toBe(6);
  await expect(acknowledgeWorkoutConsent(store, actor, { ...consentCommand, consented: false })).rejects.toMatchObject({ name: 'InputValidationError' });
});
it('production policy rejects acceptance until physical validation enables a tuple', async () => {
  await expect(submitWorkoutSession(store, actor, await input(), { clock: () => time })).rejects.toMatchObject({ code: 'failed-precondition' });
  expect([...store.documents.keys()].filter(p => p.includes('/workoutSessions/'))).toHaveLength(0);
});
it('deduplicates concurrent same-request and same-session new-request retries', async () => {
  const data = await input();
  const [a, b] = await Promise.all([submit(data), submit(data)]);
  expect(a).toEqual(b);
  const c = await submit({ ...data, requestId: 'upload-2' });
  expect(c.acceptedAtMillis).toBe(a.acceptedAtMillis);
  expect(c.requestId).toBe('upload-2');
  expect([...store.documents.keys()].filter(p => p.includes('/workoutSessions/'))).toHaveLength(1);
  const saved = store.documents.get(`orgs/gainpath/workoutSessions/${keyOf(actor.uid, data.sessionId)}`)!;
  expect(saved.memberId).toBe(actor.uid);
  expect(saved.formScorePercent).toBe(88);
  expect(saved.status).toBe('accepted');
  expect(saved).not.toHaveProperty('points');
});
it.each([
  { repetitions: 9 }, { requestId: 'upload-2', formScorePercent: 87 },
  { sessionId: 'session-2' }, { detectorVersion: 'other-version' },
])('rejects conflicting command/session/version: %j', async change => {
  const data = await input(); await submit(data);
  await expect(submit({ ...data, ...change })).rejects.toMatchObject({ code: change.detectorVersion ? 'failed-precondition' : 'already-exists' });
});
it.each([
  { schemaVersion: 1 }, { provenance: 'simulated' }, { detectorId: 'fixture' }, { cameraView: 'front' },
  { rawFrames: [] }, { video: 'data' }, { acceptedAtMillis: 1 }, { landmarks: [] },
  { repetitions: 0.5 }, { trackedDurationMillis: -1 }, { rejectedDurationMillis: 86400001 },
  { endedAtMillis: submission.startedAtMillis }, { formScorePercent: NaN },
  { formScorePercent: Infinity }, { formScorePercent: 101 }, { requestId: '../path' },
  { trackedDurationMillis: 59000, rejectedDurationMillis: 1 },
  { trackedDurationMillis: 0, repetitions: 1, formScorePercent: null },
])('rejects malformed/unbounded submission: %j', change => {
  expect(() => parseSubmitWorkoutSession({ ...submission, ...change })).toThrow();
});
it('requires all v2 fields while allowing a genuinely unavailable score', () => {
  const { formScorePercent: _, ...missing } = submission;
  expect(() => parseSubmitWorkoutSession(missing)).toThrow();
  expect(parseSubmitWorkoutSession({ ...submission, formScorePercent: null }).formScorePercent).toBeNull();
});
it.each([undefined, { uid: actor.uid, token: { email_verified: false } }])('requires authenticated verified email', async auth => {
  await expect(acknowledgeWorkoutConsent(store, auth, consentCommand)).rejects.toMatchObject({ code: auth ? 'permission-denied' : 'unauthenticated' });
});
it.each([{ memberId: 'other' }, { organizationId: 'other' }])('rejects forged identity/org: %j', async change => {
  await expect(acknowledgeWorkoutConsent(store, actor, { ...consentCommand, ...change })).rejects.toMatchObject({ code: 'permission-denied' });
});
it.each([{ status: 'suspended', role: 'member' }, { status: 'active', role: 'admin' },
  { status: 'active', role: 'coach' }])('checks authoritative active member role: %j', async change => {
  store.documents.set(`orgs/gainpath/members/${actor.uid}`, { branchIds: [], ...change });
  await expect(consent()).rejects.toMatchObject({ code: 'permission-denied' });
});
it('requires current consent before start, non-revocation and correct acknowledgement', async () => {
  await expect(submit(submission)).rejects.toMatchObject({ code: 'failed-precondition' });
  const data = await input();
  await expect(submit({ ...data, consentAcknowledgementId: 'wrong' })).rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(submit({ ...data, startedAtMillis: time - 180000 })).rejects.toMatchObject({ code: 'failed-precondition' });
  const revoke = { schemaVersion: 1, requestId: 'revoke-1', organizationId: 'gainpath', memberId: actor.uid,
    consentVersion: 'pose-local-summary-v1', acknowledgementId: data.consentAcknowledgementId };
  const a = await revokeWorkoutConsent(store, actor, revoke, () => time);
  expect(await revokeWorkoutConsent(store, actor, revoke, () => time + 1)).toEqual(a);
  await expect(submit(data)).rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(consent()).rejects.toMatchObject({ code: 'failed-precondition' });
  const fresh = await acknowledgeWorkoutConsent(store, actor, { ...consentCommand, requestId: 'consent-2' }, () => time + 1);
  expect(fresh.acknowledgementId).not.toBe(data.consentAcknowledgementId);
  await revokeWorkoutConsent(store, actor, revoke, () => time + 2);
  expect(store.documents.get(`orgs/gainpath/workoutConsents/${actor.uid}`)?.acknowledgementId).toBe(fresh.acknowledgementId);
  expect(store.documents.get(`orgs/gainpath/workoutConsents/${actor.uid}`)?.revokedAtMillis).toBeNull();
});
it.each(['inactive-exercise', 'draft', 'missing-exercise', 'wrong-kind'])('rejects invalid current catalog: %s', async state => {
  const data = await input();
  if (state === 'inactive-exercise') store.documents.set(`orgs/gainpath/exerciseVideos/${tuple.exerciseId}`, { isActive: false });
  else store.documents.set('orgs/gainpath/content/routine-1', { schemaVersion: 1,
    kind: state === 'wrong-kind' ? 'tutorial' : 'routine', status: state === 'draft' ? 'draft' : 'published',
    exercises: state === 'missing-exercise' ? [] : [{ exerciseId: tuple.exerciseId, sets: 3, reps: 10 }] });
  await expect(submit(data)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('rejects future chronology and implausible rep evidence without writing acceptance', async () => {
  const data = await input();
  await expect(submit({ ...data, endedAtMillis: time + 1 })).rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(submit({ ...data, repetitions: 100 })).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('rechecks membership and consent on accepted retries', async () => {
  const data = await input(); await submit(data);
  store.documents.set(`orgs/gainpath/members/${actor.uid}`, { role: 'member', status: 'suspended', branchIds: [] });
  await expect(submit(data)).rejects.toMatchObject({ code: 'permission-denied' });
});
