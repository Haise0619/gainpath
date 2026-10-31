import {beforeEach, expect, it} from 'vitest';
import {MemoryStore} from './memory-store';
import {actor, command, payload, routinePayload} from './workout-backup-fixture';
import {backupWorkout, listWorkoutBackups, type BackupStore} from '../src/modules/workouts/workout-backup';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';

const rowId = 'single-arm-dumbbell-row-side-v1';
const query = {schemaVersion: 1, organizationId: 'gainpath', memberId: 'member', consented: true, after: null};
const row = (id: string) => ({...structuredClone(payload), sessionId: id, exerciseId: rowId, accuracy: 0,
  poseMetrics: {...structuredClone(payload.poseMetrics), schemaVersion: 3, rowSide: 'left',
    scoringVersion: 'single-arm-row-side-v1', formScorePercent: null}});
let memory: MemoryStore, store: BackupStore;
function put(kind: 'session' | 'routine', p: Record<string, unknown>) {
  const id = String(kind === 'session' ? p.sessionId : p.id), key = kind + '-' + id;
  const record = {schemaVersion: 1, kind, id, key, digest: digestOf(p), payloadJson: JSON.stringify(p),
    classification: 'provisional_member_backup', updatedAtMillis: 1};
  memory.documents.set(`orgs/gainpath/members/member/workoutBackups/${key}`, record);
  return record;
}
beforeEach(() => {
  memory = new MemoryStore();
  memory.documents.set('users/member', {organizationId: 'gainpath'});
  memory.documents.set('orgs/gainpath', {status: 'active'});
  memory.documents.set('orgs/gainpath/members/member', {organizationId: 'gainpath', role: 'member', status: 'active', branchIds: []});
  store = {transact: work => memory.transact(work), list: async (prefix, after, limit, kind) => [...memory.documents.entries()]
    .filter(([path]) => path.startsWith(prefix + '/' + kind + '-') && !path.slice(prefix.length + 1).includes('/') &&
      (!after || path.split('/').at(-1)! > after))
    .sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).slice(0, limit).map(([, value]) => value)};
});
it('omitted negotiation preserves old records and filters row sessions', async () => {
  put('session', {...payload, sessionId: 'a'}); put('session', row('b')); put('session', {...payload, sessionId: 'c'});
  const result = await listWorkoutBackups(store, actor, query);
  expect(result.records.map(r => r.id)).toEqual(['a', 'c']);
  expect(result.records[0].payload).toEqual({...payload, sessionId: 'a'});
  expect(result.nextCursor).toBe('session-c');
});
it('all-row pages stay empty for old clients but advance to compatible records', async () => {
  for (const id of ['a', 'b', 'c', 'd']) put('session', row(id));
  put('session', {...payload, sessionId: 'e'});
  const first = await listWorkoutBackups(store, actor, query);
  expect(first.records).toEqual([]); expect(first.nextCursor).toBe('session-c');
  const second = await listWorkoutBackups(store, actor, {...query, after: first.nextCursor});
  expect(second.records.map(r => r.id)).toEqual(['e']); expect(second.nextCursor).toBe('routines');
  const last = await listWorkoutBackups(store, actor, {...query, after: second.nextCursor});
  expect(last.records).toEqual([]); expect(last.nextCursor).toBeNull();
});
it('schema-three clients receive row records and the unchanged three-document page cursor', async () => {
  for (const id of ['a', 'b', 'c', 'd']) put('session', row(id));
  const first = await listWorkoutBackups(store, actor, {...query, maxPoseMetricsSchemaVersion: 3});
  expect(first.records.map(r => r.id)).toEqual(['a', 'b', 'c']); expect(first.nextCursor).toBe('session-c');
  expect(first.records[0].payload.poseMetrics).toMatchObject({schemaVersion: 3, rowSide: 'left'});
});
it('keeps row-dependent routine snapshots from schema-two clients', async () => {
  const max = 2;
  const source = structuredClone(routinePayload);
  const routine = {...source, sessions: {'0': ['a']}, attempt: {...source.attempt,
    entries: [{...source.attempt.entries[0], sessionIds: ['a']}]}};
  routine.attempt.routine.exercises[0].exerciseId = rowId;
  put('session', row('a')); put('routine', routine);
  const first = await listWorkoutBackups(store, actor, {...query, maxPoseMetricsSchemaVersion: max});
  expect(first.records).toEqual([]); expect(first.nextCursor).toBe('routines');
  const next = await listWorkoutBackups(store, actor, {...query, after: 'routines', maxPoseMetricsSchemaVersion: max});
  expect(next.records).toEqual([]); expect(next.nextCursor).toBeNull();
  const current = await listWorkoutBackups(store, actor, {...query, after: 'routines', maxPoseMetricsSchemaVersion: 3});
  expect(current.records).toHaveLength(1); expect(current.records[0].payload).toEqual(routine);
});
it('old routine snapshots stay available without negotiation', async () => {
  put('routine', routinePayload);
  const result = await listWorkoutBackups(store, actor, {...query, after: 'routines'});
  expect(result.records[0].payload).toEqual(routinePayload);
});
it('schema-two curl sessions remain available to existing clients', async () => {
  const p = structuredClone(payload);
  Object.assign(p.poseMetrics, {schemaVersion: 2, curlArms: {mode: 'leftOnly', targetSets: 1, repetitionsPerArm: 2,
    completedSets: 1, left: {repetitions: 2, partialRepetitions: 0, formScorePercent: 90},
    right: {repetitions: 0, partialRepetitions: 0, formScorePercent: null}}});
  put('session', p);
  expect((await listWorkoutBackups(store, actor, query)).records).toHaveLength(1);
  expect((await listWorkoutBackups(store, actor, {...query, maxPoseMetricsSchemaVersion: 2})).records).toHaveLength(1);
});
it.each([0, 1, 7, -1, 1.5, '3', null, true])('rejects unsupported negotiated maximum %j', async max => {
  await expect(listWorkoutBackups(store, actor, {...query, maxPoseMetricsSchemaVersion: max})).rejects.toHaveProperty('name', 'InputValidationError');
});
it.each(['digest', 'side', 'future'])('validates hidden row records before filtering (%s)', async corruption => {
  const p = row('b');
  if (corruption === 'side') p.poseMetrics.rowSide = 'both';
  if (corruption === 'future') p.poseMetrics.schemaVersion = 4;
  put('session', {...payload, sessionId: 'a'});
  const saved = put('session', p); if (corruption === 'digest') saved.digest = 'bad';
  await expect(listWorkoutBackups(store, actor, query)).rejects.toBeDefined();
});
it('negotiation remains list-only and cannot alter the strict save envelope', async () => {
  await expect(backupWorkout(store, actor, {...command, maxPoseMetricsSchemaVersion: 3})).rejects.toHaveProperty('name', 'InputValidationError');
});
const press = (id:string) => ({...structuredClone(payload),sessionId:id,
  exerciseId:'dumbbell-shoulder-press-front-v1',accuracy:0,
  poseMetrics:{...structuredClone(payload.poseMetrics),schemaVersion:4,
    scoringVersion:'dumbbell-shoulder-press-front-v1',cameraView:'front',formScorePercent:null}});
it.each([2,3,4])('filters shoulder press sessions for negotiated schema %s',async max=>{
  put('session',press('a'));put('session',row('b'));put('session',{...payload,sessionId:'c'});
  const r=await listWorkoutBackups(store,actor,{...query,maxPoseMetricsSchemaVersion:max});
  expect(r.records.map(v=>v.id)).toEqual(max===4?['a','b','c']:max===3?['b','c']:['c']);
  expect(r.nextCursor).toBe('session-c');
});
it.each([2,3,4])('filters press-dependent Routine checkpoint for schema %s',async max=>{
  const p=structuredClone(routinePayload);p.attempt.routine.exercises[0].exerciseId='dumbbell-shoulder-press-front-v1';
  put('routine',p);
  const r=await listWorkoutBackups(store,actor,{...query,after:'routines',maxPoseMetricsSchemaVersion:max});
  expect(r.records).toHaveLength(max===4?1:0);expect(r.nextCursor).toBeNull();
});

const lunge = (id:string) => ({...structuredClone(payload), sessionId:id, exerciseId:'bodyweight-reverse-lunge-side-v1', accuracy:0,
  poseMetrics:{...structuredClone(payload.poseMetrics),schemaVersion:5,scoringVersion:'reverse-lunge-side-v1',lungeSide:'left',formScorePercent:null}});
it.each([2,3,4,5])('filters lunge session preserving scanned cursor for max %s',async max=>{
  put('session',lunge('a'));put('session',press('b'));put('session',row('c'));
  const r=await listWorkoutBackups(store,actor,{...query,maxPoseMetricsSchemaVersion:max});
  expect(r.records.map(v=>v.id)).toEqual(max===5?['a','b','c']:max===4?['b','c']:max===3?['c']:[]);
  expect(r.nextCursor).toBe('session-c');
});
it.each([2,3,4,5])('filters lunge-dependent Routine checkpoint for max %s',async max=>{
  const p=structuredClone(routinePayload);p.attempt.routine.exercises[0].exerciseId='bodyweight-reverse-lunge-side-v1';
  put('routine',p);
  const r=await listWorkoutBackups(store,actor,{...query,after:'routines',maxPoseMetricsSchemaVersion:max});
  expect(r.records).toHaveLength(max===5?1:0);expect(r.nextCursor).toBeNull();
});
it('validates hidden lunge side before filtering for omitted legacy negotiation',async()=>{
  const p=lunge('a');p.poseMetrics.lungeSide='both';put('session',p);
  await expect(listWorkoutBackups(store,actor,query)).rejects.toBeDefined();
});

const lateral = (id:string) => ({...structuredClone(payload),sessionId:id,exerciseId:'standing-lateral-raise-front-v1',accuracy:0,
  poseMetrics:{...structuredClone(payload.poseMetrics),schemaVersion:6,scoringVersion:'standing-lateral-raise-front-v1',cameraView:'front',formScorePercent:null}});
it.each([2,3,4,5,6])('filters lateral raise sessions preserving scanned cursor for max %s',async max=>{
  put('session',lateral('a'));put('session',lunge('b'));put('session',press('c'));
  const r=await listWorkoutBackups(store,actor,{...query,maxPoseMetricsSchemaVersion:max});
  expect(r.records.map(v=>v.id)).toEqual(max===6?['a','b','c']:max===5?['b','c']:max===4?['c']:[]);
  expect(r.nextCursor).toBe('session-c');
});
it.each([undefined,2,3,4,5,6])('filters lateral-dependent Routine checkpoint for max %s',async max=>{
  const p=structuredClone(routinePayload);p.attempt.routine.exercises[0].exerciseId='standing-lateral-raise-front-v1';put('routine',p);
  const r=await listWorkoutBackups(store,actor,{...query,after:'routines',...(max===undefined?{}:{maxPoseMetricsSchemaVersion:max})});
  expect(r.records).toHaveLength(max===6?1:0);expect(r.nextCursor).toBeNull();
});
it.each(['digest','score','schema','identity'])('validates hidden lateral raise records before filtering (%s)',async corruption=>{
  const p=lateral('a');if(corruption==='score')Object.assign(p.poseMetrics,{formScorePercent:10});
  if(corruption==='schema')p.poseMetrics.schemaVersion=1;if(corruption==='identity')p.exerciseId='squat';
  const saved=put('session',p);if(corruption==='digest')saved.digest='bad';
  await expect(listWorkoutBackups(store,actor,query)).rejects.toBeDefined();
});
it('validates hidden lateral-dependent Routine snapshots before filtering',async()=>{
  const p=structuredClone(routinePayload);p.attempt.routine.exercises[0].exerciseId='standing-lateral-raise-front-v1';
  p.attempt.routine.exercises[0].sets=-1;put('routine',p);
  await expect(listWorkoutBackups(store,actor,{...query,after:'routines'})).rejects.toBeDefined();
});
it('omitted negotiation filters lateral raises while preserving legacy records',async()=>{
  put('session',lateral('a'));put('session',{...payload,sessionId:'b'});
  const r=await listWorkoutBackups(store,actor,query);expect(r.records.map(v=>v.id)).toEqual(['b']);expect(r.nextCursor).toBe('routines');
});
