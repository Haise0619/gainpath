import { beforeEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { backupWorkout, listWorkoutBackups, type BackupStore } from '../src/modules/workouts/workout-backup';
import {actor,payload,command} from './workout-backup-fixture';
it.each([0, 75, 600])('backs up optional Program exercise restSeconds %s without changing evidence classification', async restSeconds => {
 const {routinePayload} = await import('./workout-backup-fixture');
 const next = {...routinePayload, attempt: {...routinePayload.attempt, routine: {...routinePayload.attempt.routine,
  exercises: routinePayload.attempt.routine.exercises.map(e => ({...e, restSeconds}))}}};
 const result = await backupWorkout(store, actor, {...command, kind: 'routine', id: 'r1', payload: next});
 expect(result).toMatchObject({status: 'backed_up'});
 const head = memory.documents.get('orgs/gainpath/members/member/workoutBackups/routine-r1')!;
 expect(head.classification).toBe('provisional_member_backup');
 expect(JSON.parse(String(head.payloadJson)).attempt.routine.exercises[0].restSeconds).toBe(restSeconds);
 expect([...memory.documents.keys()].some(p => p.includes('/rewardAwards/') || p.includes('/verifiedRoutineAttempts/'))).toBe(false);
});
it.each([-1, 601, 1.5, '75', null])('rejects invalid Program restSeconds %s without writing a backup', async restSeconds => {
 const {routinePayload} = await import('./workout-backup-fixture');
 const next = {...routinePayload, attempt: {...routinePayload.attempt, routine: {...routinePayload.attempt.routine,
  exercises: routinePayload.attempt.routine.exercises.map(e => ({...e, restSeconds}))}}};
 await expect(backupWorkout(store, actor, {...command, kind: 'routine', id: 'r1', payload: next})).rejects.toHaveProperty('name', 'InputValidationError');
 expect([...memory.documents.keys()].some(p => p.includes('/workoutBackups/'))).toBe(false);
});
it('backs up optional routine difficulty without promoting provisional evidence',async()=>{
 const {routinePayload}=await import('./workout-backup-fixture');
 const next={...routinePayload,attempt:{...routinePayload.attempt,routine:{...routinePayload.attempt.routine,difficulty:'Advanced'}}};
 await expect(backupWorkout(store,actor,{...command,kind:'routine',id:'r1',payload:next})).resolves.toMatchObject({status:'backed_up'});
 expect([...memory.documents.keys()].some(p=>p.includes('/rewardAwards/')||p.includes('/verifiedRoutineAttempts/'))).toBe(false);
 await expect(backupWorkout(store,actor,{...command,kind:'routine',id:'r2',payload:{...next,id:'r2',attempt:{...next.attempt,id:'r2',routine:{...next.attempt.routine,difficulty:'Expert'}}}})).rejects.toBeDefined();
});
let memory: MemoryStore, store: BackupStore;
beforeEach(() => { memory = new MemoryStore(); memory.documents.set('users/member', { organizationId: 'gainpath' }); memory.documents.set('orgs/gainpath', { status: 'active' }); memory.documents.set('orgs/gainpath/members/member', { organizationId: 'gainpath', role: 'member', status: 'active', branchIds: [] }); store = { transact: work => memory.transact(work), list: async (prefix, after, limit, kind) => [...memory.documents.entries()].filter(([p]) => p.startsWith(prefix + '/'+kind+'-') && !p.slice(prefix.length + 1).includes('/') && (!after || p.split('/').at(-1)! > after)).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).slice(0, limit).map(([, v]) => v) }; });
it('backs up idempotently without creating accepted workouts or rewards', async () => { const a = await backupWorkout(store, actor, command); expect(a.status).toBe('backed_up'); expect(await backupWorkout(store, actor, command)).toEqual(a); expect([...memory.documents.keys()].filter(p => p.includes('/workoutBackups/'))).toHaveLength(2); expect([...memory.documents.keys()].some(p => /workoutSessions|reward|Consent/.test(p))).toBe(false); });
it('conflicting immutable session preserves existing backup', async () => { const a = await backupWorkout(store, actor, command); await expect(backupWorkout(store, actor, { ...command, baseDigest: a.digest, payload: { ...payload, repetitions: 3 } })).rejects.toMatchObject({ code: 'already-exists' }); expect((await listWorkoutBackups(store, actor, { schemaVersion: 1, organizationId: 'gainpath', memberId: 'member', consented: true, after: null })).records[0].digest).toBe(a.digest); });
it.each([undefined, { uid: 'other', token: actor.token }, { uid: 'member', token: { email_verified: false, auth_time: 100 } }])('rejects unverified or wrong account', async (auth) => { await expect(backupWorkout(store, auth, command)).rejects.toBeDefined(); });
it.each([{ consented: false }, { memberId: 'other' }, { organizationId: 'other' }, { id: '../escape' }, { payload: { ...payload, rawFrames: [] } }, { payload: { ...payload, poseMetrics: { ...payload.poseMetrics, landmarks: [] } } }, { payload: { ...payload, acceptedAt: 1 } }, { payload: { ...payload, userId: 'other' } }])('rejects invalid owner/payload %j', async (change) => { await expect(backupWorkout(store, actor, { ...command, ...change })).rejects.toBeDefined(); });
it('fails closed on inactive organization, deactivation and stale sessions', async () => { for (const change of [{ path: 'orgs/gainpath', value: { status: 'inactive' } }, { path: 'users/member', value: { organizationId: 'gainpath', accountLifecycle: { state: 'active', sessionNotBeforeSeconds: 101, revocationPending: false } } }]) {
    const prev = memory.documents.get(change.path)!;
    memory.documents.set(change.path, change.value);
    await expect(backupWorkout(store, actor, command)).rejects.toMatchObject({ code: 'permission-denied' });
    memory.documents.set(change.path, prev);
} });
it('list is bounded and only returns current owner backups', async () => { await backupWorkout(store, actor, command); const page = await listWorkoutBackups(store, actor, { schemaVersion: 1, organizationId: 'gainpath', memberId: 'member', consented: true, after: null }); expect(page.records).toHaveLength(1); expect(page.nextCursor).toBe('routines'); expect(page.records[0].payload).toEqual(payload); });
it('routine revisions use base digest CAS and retain both archive copies',async()=>{
 const {routinePayload}=await import('./workout-backup-fixture');
 const input={...command,kind:'routine',id:'r1',payload:routinePayload};
 const first=await backupWorkout(store,actor,input);
 const revised={...routinePayload,updatedAtMicros:routinePayload.updatedAtMicros+1,reviewed:[0]};
 await expect(backupWorkout(store,actor,{...input,payload:revised})).rejects.toMatchObject({code:'already-exists'});
 const second=await backupWorkout(store,actor,{...input,baseDigest:first.digest,payload:revised});expect(second.digest).not.toBe(first.digest);
 expect([...memory.documents.keys()].filter(p=>p.includes('/routine-r1/revisions/'))).toHaveLength(2);
 await expect(backupWorkout(store,actor,{...input,baseDigest:first.digest,payload:{...revised,selectedIndex:0,updatedAtMicros:revised.updatedAtMicros+1}})).rejects.toMatchObject({code:'already-exists'});
});
it('rejects accepted-score flags and raw media nested inside routine snapshots',async()=>{
 const {routinePayload}=await import('./workout-backup-fixture');
 for(const attempt of [{...routinePayload.attempt,accepted:true},{...routinePayload.attempt,routine:{...routinePayload.attempt.routine,video:'data'} }])await expect(backupWorkout(store,actor,{...command,kind:'routine',id:'r1',payload:{...routinePayload,attempt}})).rejects.toBeDefined();
});
it('uses a cross-runtime numeric digest representation without losing precision',async()=>{
 const {canonical,digestOf}=await import('../src/modules/workouts/workout-backup-validation');
 expect(canonical({small:0.000001,zero:-0,integer:90})).toBe('{"integer":n4056800000000000,"small":n3eb0c6f7a0b5ed8d,"zero":n0000000000000000}');
 expect(digestOf({small:0.000001,zero:-0,integer:90})).toBe('429d8008002cd9d4cfef0cf6bfd58828fd43d35034c83fc24748257d93d1907f');
});
