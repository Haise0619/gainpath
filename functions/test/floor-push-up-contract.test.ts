import {it, expect} from 'vitest';
import {payload} from './workout-backup-fixture';
import {validateBackupPayload, digestOf} from '../src/modules/workouts/workout-backup-validation';
import {adminWorkoutReport, type WorkoutReportReader} from '../src/modules/analytics/admin-workout-reporting';
import {extractWorkoutEvidence} from '../src/modules/recommendation/workout-evidence';
import {MemoryStore} from './memory-store';
import {listWorkoutBackups, type BackupStore} from '../src/modules/workouts/workout-backup';
const id = 'standard-floor-push-up-side-v1';
function floor(score: number | null = 90) {
  return {...structuredClone(payload), exerciseId: id, accuracy: score ?? 0,
    poseMetrics: {...structuredClone(payload.poseMetrics), schemaVersion: 7,
      scoringVersion: id, formScorePercent: score,
      floorPushUp: {side: 'left', sourceVersion: 'floor-push-up-2d-crosscheck-v1',
        components: score === null ? null : {rangeOfMotion: 90, bodyAlignment: 90, movementControl: 90, armExtension: 90},
        issueCounts: {}}}};
}
const now = Date.UTC(2026, 9, 26, 6);
const backup = (p = floor(), key = 'session-s1') => ({id: key, data: {
  schemaVersion: 1, kind: 'session', id: p.sessionId, key,
  digest: digestOf(p), payloadJson: JSON.stringify(p), classification: 'provisional_member_backup', updatedAtMillis: now - 1}});
it('accepts schema seven as descriptive backup and preserves missing scores', () => {
  for (const score of [90, null]) {
    const p = floor(score);
    expect(validateBackupPayload('session', 's1', 'gainpath', 'member', p)).toEqual(p);
  }
});
it.each(['schema', 'identity', 'source', 'components', 'score', 'side', 'issues'])('rejects floor %s spoofing', mode => {
  const p = floor();
  if (mode === 'schema') p.poseMetrics.schemaVersion = 1;
  if (mode === 'identity') p.exerciseId = 'wall-push-up-side-v1';
  if (mode === 'source') p.poseMetrics.floorPushUp.sourceVersion = 'wall-push-up-side-v1';
  if (mode === 'components') p.poseMetrics.floorPushUp.components!.rangeOfMotion = 101;
  if (mode === 'score') p.poseMetrics.formScorePercent = 99;
  if (mode === 'side') p.poseMetrics.floorPushUp.side = 'front';
  if (mode === 'issues') Object.assign(p.poseMetrics.floorPushUp.issueCounts, {elbowFlare: 1});
  expect(() => validateBackupPayload('session', 's1', 'gainpath', 'member', p)).toThrow();
});
it('Module 12 keeps floor and wall score groups separate and remains read-only', async () => {
  const store = new MemoryStore();
  store.documents.set('users/admin', {organizationId: 'gainpath'});
  store.documents.set('orgs/gainpath', {status: 'active'});
  store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});
  store.documents.set('users/member', {organizationId: 'gainpath', role: 'member'});
  const wall = {...structuredClone(payload), sessionId: 'wall', exerciseId: 'wall-push-up-side-v1',
    poseMetrics: {...payload.poseMetrics, scoringVersion: 'wall-push-up-side-v1'}};
  const records = [backup(), {id: 'session-wall', data: {...backup().data, id: 'wall', key: 'session-wall', payloadJson: JSON.stringify(wall), digest: digestOf(wall)}}];
  const reader: WorkoutReportReader = {
    members: async after => after ? [] : [{id: 'member', data: {organizationId: 'gainpath', role: 'member', status: 'active'}}],
    backups: async (_uid, after) => records.filter(r => !after || r.id > after),
  };
  const before = JSON.stringify([...store.documents]);
  const result = await adminWorkoutReport(store, {uid: 'admin', token: {email_verified: true, auth_time: 100}},
    {schemaVersion: 1, organizationId: 'gainpath', startAtMillis: now - 3 * 86400000, endAtMillis: now}, reader, () => now);
  expect(result.totals).toMatchObject({sessions: 2, fullReps: 4});
  expect(result.forms.map(f => f.exerciseId).sort()).toEqual([id, 'wall-push-up-side-v1']);
  expect(result.classification).toBe('provisional_member_backup');
  expect(JSON.stringify([...store.documents])).toBe(before);
});
it('Module 13 explicitly withholds floor evidence compatibility', () => {
  const e = extractWorkoutEvidence({organizationId: 'gainpath', memberId: 'member'}, backup(), now);
  expect(e).toMatchObject({kind: 'session', compatibility: null, unsupportedReason: 'unsupported_exercise'});
});
it('old clients skip schema seven while negotiated clients restore it', async () => {
  const memory = new MemoryStore();
  memory.documents.set('users/member', {organizationId: 'gainpath'});
  memory.documents.set('orgs/gainpath', {status: 'active'});
  memory.documents.set('orgs/gainpath/members/member', {organizationId: 'gainpath', role: 'member', status: 'active', branchIds: []});
  const store: BackupStore = {transact: work => memory.transact(work), list: async () => [backup().data]};
  const query = {schemaVersion: 1, organizationId: 'gainpath', memberId: 'member', consented: true, after: null};
  const auth = {uid: 'member', token: {email_verified: true, auth_time: 100}};
  expect((await listWorkoutBackups(store, auth, {...query, maxPoseMetricsSchemaVersion: 6})).records).toEqual([]);
  expect((await listWorkoutBackups(store, auth, {...query, maxPoseMetricsSchemaVersion: 7})).records).toHaveLength(1);
});
