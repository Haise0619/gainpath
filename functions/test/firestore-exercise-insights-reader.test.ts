import {Firestore} from 'firebase-admin/firestore';
import {createRequire} from 'node:module';
import {resolve} from 'node:path';
import {afterEach, expect, it, vi} from 'vitest';
import {createFirestoreExerciseInsightsReader, type LocalExerciseInsightsReview} from '../src/modules/recommendation/firestore-exercise-insights-reader';

const previous = process.env.FIRESTORE_EMULATOR_HOST;
afterEach(() => {if (previous === undefined) delete process.env.FIRESTORE_EMULATOR_HOST; else process.env.FIRESTORE_EMULATOR_HOST = previous;});
const review: LocalExerciseInsightsReview = {mode: 'local_reviewed_emulator', projectId: 'demo-gainpath-module13-a2',
  firestoreEmulatorHost: '127.0.0.1:18110'};
// Any attempted SDK access throws: negative cases must reject before touching Firestore.
const untouched = new Proxy({} as Firestore, {get() {throw Error('Unexpected Firestore access');}});
it('keeps the dedicated A2 emulator suite out of the existing broad core harness', () => {
  const {suites} = createRequire(resolve('package.json'))('./emulator/run-suites.cjs');
  expect(suites.core.tests).not.toContain('emulator/module13-a2.test.ts');
  expect(suites.core.tests).toContain('emulator/firestore-rules.test.ts');
});
it('is disabled without an explicit local review before any SDK access', async () => {
  const reader = createFirestoreExerciseInsightsReader({firestore: untouched, organizationId: 'gainpath'});
  await expect(reader.members('gainpath', undefined, 1)).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(reader.backups({organizationId: 'gainpath', memberId: 'member'}, undefined, 1)).rejects.toMatchObject({code: 'failed-precondition'});
});
it.each([undefined, 'firestore.googleapis.com:443', 'localhost:18110', '127.0.0.1:18080'])('rejects a missing or mismatched emulator host (%s)', async host => {
  if (host === undefined) delete process.env.FIRESTORE_EMULATOR_HOST; else process.env.FIRESTORE_EMULATOR_HOST = host;
  const reader = createFirestoreExerciseInsightsReader({firestore: untouched, organizationId: 'gainpath', localReview: review});
  await expect(reader.members('gainpath', undefined, 1)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('binds the injected Firestore project to the reviewed demo project', async () => {
  process.env.FIRESTORE_EMULATOR_HOST = review.firestoreEmulatorHost;
  const reader = createFirestoreExerciseInsightsReader({firestore: {projectId: 'gainpath-live'} as unknown as Firestore,
    organizationId: 'gainpath', localReview: review});
  await expect(reader.members('gainpath', undefined, 1)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('rejects an already constructed wrong-host SDK even when environment/project later match', async () => {
  delete process.env.FIRESTORE_EMULATOR_HOST;
  const db = new Firestore({projectId: review.projectId, host: '127.0.0.1:19999', ssl: false});
  // Offline probe: even a broken gate must never reach a real SDK query/credentials.
  vi.spyOn(db, 'collection').mockImplementation(() => {throw Error('Wrong transport was reached');});
  process.env.FIRESTORE_EMULATOR_HOST = review.firestoreEmulatorHost;
  const reader = createFirestoreExerciseInsightsReader({firestore: db, organizationId: 'gainpath', localReview: review});
  try {await expect(reader.members('gainpath', undefined, 1)).rejects.toMatchObject({code: 'failed-precondition'});}
  finally {await db.terminate();}
});
it('rejects organization/path/cursor injection and out-of-range limits before a collection read', async () => {
  process.env.FIRESTORE_EMULATOR_HOST = review.firestoreEmulatorHost;
  const reader = createFirestoreExerciseInsightsReader({firestore: {projectId: review.projectId,
    _settings: {servicePath: '127.0.0.1', port: 18110, ssl: false}} as unknown as Firestore,
    organizationId: 'gainpath', localReview: review});
  for (const after of ['', 'a/b', 'x'.repeat(129)]) await expect(reader.members('gainpath', after, 1)).rejects.toMatchObject({code: 'invalid-argument'});
  for (const limit of [0, -1, 252, 1.5, NaN, Infinity]) await expect(reader.members('gainpath', undefined, limit)).rejects.toMatchObject({code: 'invalid-argument'});
  for (const limit of [0, 26]) await expect(reader.backups({organizationId: 'gainpath', memberId: 'member'}, undefined, limit)).rejects.toMatchObject({code: 'invalid-argument'});
  await expect(reader.members('foreign', undefined, 1)).rejects.toMatchObject({code: 'permission-denied'});
  await expect(reader.backups({organizationId: 'gainpath', memberId: 'a/b'}, undefined, 1)).rejects.toMatchObject({code: 'invalid-argument'});
});
