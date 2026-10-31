import {beforeEach, it, expect} from 'vitest';
import {MemoryStore} from './memory-store';
import {payload, routinePayload} from './workout-backup-fixture';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {adminWorkoutReport, type WorkoutReportReader} from '../src/modules/analytics/admin-workout-reporting';
const now = Date.UTC(2026, 9, 26, 6), start = Date.UTC(2026, 9, 24, 16), end = Date.UTC(2026, 9, 25, 16);
const auth = {uid: 'admin', token: {email_verified: true, auth_time: 100}};
const query = {schemaVersion: 1, organizationId: 'gainpath', startAtMillis: start, endAtMillis: end};
let store: MemoryStore, backups: {id: string; data: Record<string, unknown>}[], reads: number;
type RoutineFixture = Omit<typeof routinePayload, 'attempt'> & {attempt: Omit<typeof routinePayload.attempt, 'finishedAtMicros' | 'entries'> & {
  finishedAtMicros: number | null; entries: (Omit<typeof routinePayload.attempt.entries[number], 'sessionIds'> & {sessionIds: string[]})[]}};
const routineFixture = (): RoutineFixture => structuredClone(routinePayload);
const record = (kind: string, p: Record<string, unknown>) => {
  const id = String(kind === 'session' ? p.sessionId : p.id), key = kind + '-' + id;
  return {id: key, data: {schemaVersion: 1, kind, id, key, digest: digestOf(p), payloadJson: JSON.stringify(p), classification: 'provisional_member_backup', updatedAtMillis: now - 1}};
};
const reader: WorkoutReportReader = {
  members: async after => [{id: 'member', data: {organizationId: 'gainpath', role: 'member', status: 'active'}}].filter(r => !after || r.id > after),
  backups: async (_uid, after, limit) => {reads++; return backups.filter(r => !after || r.id > after).sort((a, b) => a.id.localeCompare(b.id)).slice(0, limit);},
};
const run = (r = reader, q = query) => adminWorkoutReport(store, auth, q, r, () => now);
beforeEach(() => {
  reads = 0; store = new MemoryStore(); backups = [];
  store.documents.set('users/admin', {organizationId: 'gainpath'});
  store.documents.set('orgs/gainpath', {status: 'active'});
  store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});
  store.documents.set('users/member', {organizationId: 'gainpath', role: 'member'});
});
it('includes schema-three selected-arm rows only as provisional unscored activity', async () => {
  for (const side of ['left', 'right']) {
    backups.push(record('session', {...payload, sessionId: 'row-' + side,
      exerciseId: 'single-arm-dumbbell-row-side-v1', accuracy: 0,
      poseMetrics: {...payload.poseMetrics, schemaVersion: 3, rowSide: side,
        scoringVersion: 'single-arm-row-side-v1', formScorePercent: null}}));
  }
  const before = JSON.stringify([...store.documents]);
  const result = await run();
  expect(result.classification).toBe('provisional_member_backup');
  expect(result.totals).toMatchObject({sessions: 2, fullReps: 4, trackedMicros: 16000000});
  expect(result.forms).toEqual([]);
  expect(result.exercises).toHaveLength(1);
  expect(JSON.stringify([...store.documents])).toBe(before);
});
it('reports custom-rest Program routine backups with existing evidence totals and labels', async () => {
  const routine = routineFixture();
  routine.finished = routine.attempt.finished = true;
  routine.attempt.finishedAtMicros = routine.updatedAtMicros;
  routine.attempt.entries[0].status = 'selfReportedCompleted';
  routine.attempt.entries[0].manualSets = 1;
  const programRoutine = {...routine, attempt: {...routine.attempt, routine: {...routine.attempt.routine,
    exercises: routine.attempt.routine.exercises.map(e => ({...e, restSeconds: 75}))}}};
  backups = [record('routine', programRoutine)];
  const result = await run();
  expect(result.classification).toBe('provisional_member_backup');
  expect(result.totals).toMatchObject({sessions: 0, fullReps: 0, trackedMicros: 0, completedRoutineDays: 1, manualSets: 1});
});
it('refuses invalid-rest Program backup sources instead of returning partial report totals', async () => {
  const routine = routineFixture();
  const invalid = {...routine, attempt: {...routine.attempt, routine: {...routine.attempt.routine,
    exercises: routine.attempt.routine.exercises.map(e => ({...e, restSeconds: 601}))}}};
  backups = [record('routine', invalid), record('session', payload)];
  await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
});
it('reports unscored front-view press reps without creating a form score or writing data',async()=>{
  backups=[record('session',{...payload,exerciseId:'dumbbell-shoulder-press-front-v1',accuracy:0,
    poseMetrics:{...payload.poseMetrics,schemaVersion:4,scoringVersion:'dumbbell-shoulder-press-front-v1',
      cameraView:'front',formScorePercent:null}})];
  const before=JSON.stringify([...store.documents]);const result=await run();
  expect(result.totals.sessions).toBe(1);expect(result.totals.fullReps).toBe(2);
  expect(result.forms).toEqual([]);expect(result.classification).toBe('provisional_member_backup');
  expect(JSON.stringify([...store.documents])).toBe(before);
});
it('aggregates only camera sessions once, keeps manual sets separate and returns no personal rows or writes', async () => {
  const routine = routineFixture();
  routine.attempt.entries[0] = {...routine.attempt.entries[0], status: 'completed', sessionIds: ['s1'], fullRepetitions: 200, trackedDurationMicros: 999999, manualSets: 1};
  routine.finished = true; routine.attempt.finished = true; routine.attempt.finishedAtMicros = routine.updatedAtMicros;
  backups = [record('routine', routine), record('session', payload)];
  const before = JSON.stringify([...store.documents]), r = await run();
  expect(r.totals).toMatchObject({sessions: 1, fullReps: 2, partialReps: 0, trackedMicros: 8000000, manualSets: 1, routineAttempts: 1, completedRoutineDays: 1});
  expect(r.coverage).toMatchObject({activeMembers: 1, membersWithBackups: 1, membersWithActivity: 1, backupRecords: 2});
  expect(JSON.stringify([...store.documents])).toBe(before);
  const json = JSON.stringify(r); expect(json).not.toContain('payloadJson'); expect(json).not.toContain('sessionIds'); expect(json).not.toContain('userId'); expect(json).not.toContain('Strength');
});
it('uses session end dates with Malaysia inclusive start/exclusive end, excluding future records', async () => {
  for (const [i, time] of [start - 1, start, end, now + 1].entries()) {
    const p = structuredClone(payload); p.sessionId = 's' + i;
    p.startedAt = new Date(time - 10000).toISOString(); p.endedAt = new Date(time).toISOString(); p.poseMetrics.consentedAt = p.startedAt;
    backups.push(record('session', p));
  }
  const r = await run(); expect(r.totals.sessions).toBe(1); expect(r.daily[0].date).toBe('2026-10-25');
  expect(r.coverage.membersWithBackups).toBe(1);
});
it('keeps completed, finished incomplete, in-progress and unknown completion dates distinct', async () => {
  for (let i = 0; i < 4; i++) {
    const p = routineFixture(); p.id = p.attempt.id = 'r' + i;
    if (i !== 2) {p.finished = p.attempt.finished = true;}
    if (i === 0 || i === 3) p.attempt.entries[0].status = 'selfReportedCompleted';
    if (i === 0 || i === 1) p.attempt.finishedAtMicros = p.updatedAtMicros;
    backups.push(record('routine', p));
  }
  expect((await run()).totals).toMatchObject({routineAttempts: 4, completedRoutineDays: 1, partialRoutineDays: 1, inProgressRoutineDays: 1, unknownCompletionDays: 1});
});
it('groups estimated scores by compatible exercise, rule, model, view and curl mode without a global average', async () => {
  for (let i = 0; i < 3; i++) {
    const p = structuredClone(payload); p.sessionId = 's' + i; p.poseMetrics.formScorePercent = i === 0 ? 80 : 90;
    if (i === 2) p.poseMetrics.detectorVersion = 'v2';
    backups.push(record('session', p));
  }
  const r = await run(); expect(r.forms).toHaveLength(2);
  expect(r.forms.find(f => f.detectorVersion === 'v1')).toMatchObject({scoredSessions: 2, scoreSum: 170});
  expect(r.forms[0].daily[0].date).toBe('2026-10-25');
  expect(r.totals).not.toHaveProperty('formScore');
});
it('does not read backups for foreign, inactive or non-Member canonical accounts', async () => {
  store.documents.set('users/member', {organizationId: 'other'});
  expect((await run()).coverage.activeMembers).toBe(0); expect(reads).toBe(0);
});
it('denies non-Admin access before reading backups and authority drift before returning totals', async () => {
  store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', role: 'member', status: 'active'});
  await expect(run()).rejects.toMatchObject({code: 'permission-denied'}); expect(reads).toBe(0);
  store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', role: 'admin', status: 'active'});
  await expect(run({...reader, backups: async () => {store.documents.set('users/admin', {organizationId: 'other'}); return [];}})).rejects.toMatchObject({code: 'permission-denied'});
});
it('fails closed on corrupt digest, foreign payload and duplicated document identities', async () => {
  backups = [record('session', payload)]; backups[0].data.digest = 'bad';
  await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
  backups = [record('session', {...payload, userId: 'other'})];
  await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
  const row = record('session', payload); backups = [row, row];
  await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
});
it('caps eligible Member scans without returning partial totals', async () => {
  const members = Array.from({length: 201}, (_, i) => ({id: 'm' + String(i).padStart(3, '0'), data: {organizationId: 'gainpath', role: 'member', status: 'active'}}));
  for (const m of members) store.documents.set('users/' + m.id, {organizationId: 'gainpath'});
  await expect(run({...reader, members: async after => members.filter(m => !after || m.id > after)})).rejects.toMatchObject({code: 'resource-exhausted'});
});
it('same session ID for two different Members is counted separately while each latest document is counted once', async () => {
  store.documents.set('users/second', {organizationId: 'gainpath'});
  const r = await run({...reader, members: async after => ['member', 'second'].filter(id => !after || id > after).map(id => ({id, data: {organizationId: 'gainpath', role: 'member', status: 'active'}})), backups: async (uid, after) => after ? [] : [record('session', {...payload, userId: uid})]});
  expect(r.totals.sessions).toBe(2); expect(r.exercises[0].sessions).toBe(2);
});
it('complete document-id pagination is bounded across every eligible Member', async () => {
  backups = Array.from({length: 2001}, (_, i) => record('session', {...payload, sessionId: 's' + String(i).padStart(4, '0')}));
  await expect(run()).rejects.toMatchObject({code: 'resource-exhausted'});
});
it('excessive stored JSON bytes never produce partial totals', async () => {
  backups = [record('session', payload)]; backups[0].data.payloadJson = ' '.repeat(16 * 1024 * 1024 + 1);
  await expect(run()).rejects.toMatchObject({code: 'resource-exhausted'});
});
it('arm modes and unknown form scores remain separate from scored session means', async () => {
  for (const [i, mode] of ['leftOnly', 'rightOnly'].entries()) {
    const p = structuredClone(payload); p.sessionId = 's' + i;
    Object.assign(p.poseMetrics, {schemaVersion: 2, curlArms: {mode, targetSets: 1, repetitionsPerArm: 2, completedSets: 1,
      left: {repetitions: 2, partialRepetitions: 0, formScorePercent: 90}, right: {repetitions: 0, partialRepetitions: 0, formScorePercent: null}}});
    backups.push(record('session', p));
  }
  const p = structuredClone(payload); p.sessionId = 's2'; Object.assign(p.poseMetrics, {formScorePercent: null}); backups.push(record('session', p));
  const r = await run(); expect(r.forms.map(f => f.armMode).sort()).toEqual(['leftOnly', 'rightOnly']); expect(r.totals.sessions).toBe(3);
});
it('impossible routine chronology fails closed instead of contributing attempts or manual sets', async () => {
  const startsTomorrow = routineFixture(); startsTomorrow.startedAtMicros = startsTomorrow.attempt.startedAtMicros = (now + 86400000) * 1000;
  startsTomorrow.attempt.entries[0].manualSets = 1;
  backups = [record('routine', startsTomorrow)];
  await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
  const finishesAfterUpdate = routineFixture(); finishesAfterUpdate.finished = finishesAfterUpdate.attempt.finished = true;
  finishesAfterUpdate.attempt.finishedAtMicros = finishesAfterUpdate.attempt.updatedAtMicros + 1000000;
  backups = [record('routine', finishesAfterUpdate)];
  await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
});
it('chronologically valid future device-clock routine records are excluded until their time is reached', async () => {
  const p = routineFixture(); p.startedAtMicros = p.attempt.startedAtMicros = (now + 1000) * 1000;
  p.updatedAtMicros = p.attempt.updatedAtMicros = (now + 2000) * 1000;
  backups = [record('routine', p)];
  const r = await run(); expect(r.coverage.membersWithBackups).toBe(1); expect(r.totals.routineAttempts).toBe(0);
});

it('reports schema-five lunges as provisional unscored activity without writes',async()=>{
  backups=['left','right'].map(side=>record('session',{...payload,sessionId:'lunge-'+side,exerciseId:'bodyweight-reverse-lunge-side-v1',accuracy:0,
    poseMetrics:{...payload.poseMetrics,schemaVersion:5,scoringVersion:'reverse-lunge-side-v1',cameraView:'side',lungeSide:side,formScorePercent:null}}));
  const before=JSON.stringify([...store.documents]);const result=await run();
  expect(result.totals.sessions).toBe(2);expect(result.totals.fullReps).toBe(4);
  expect(result.forms).toEqual([]);expect(result.classification).toBe('provisional_member_backup');
  expect(JSON.stringify([...store.documents])).toBe(before);
});
