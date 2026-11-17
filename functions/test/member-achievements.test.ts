import { beforeEach, expect, it } from 'vitest';
import { appCheckInCommand } from '../src/modules/gamification/app-check-in-service';
import { memberAchievements, type AchievementStore } from '../src/modules/gamification/member-achievements';
import { backupWorkout } from '../src/modules/workouts/workout-backup';
import { MemoryStore } from './memory-store';
import { actor, command, completedStandaloneBackup, payload, routinePayload, timedBackupFixture } from './workout-backup-fixture';

const root = 'orgs/gainpath';
const at = (day: number) => Date.UTC(2026, 9, day, 8);
const input = { schemaVersion: 1, organizationId: 'gainpath', action: 'achievements' };
let memory: MemoryStore;
let store: AchievementStore;
const get = () => memberAchievements(store, actor, input, () => at(31));
const claim = (day: number) => appCheckInCommand(store, actor, { ...input, action: 'claim' }, () => at(day));

beforeEach(() => {
  memory = new MemoryStore();
  memory.documents.set('users/member', { organizationId: 'gainpath' });
  memory.documents.set(root, { status: 'active' });
  memory.documents.set(root + '/members/member', { organizationId: 'gainpath', role: 'member', status: 'active', branchIds: [] });
  store = {
    transact: work => memory.transact(work),
    page: async (path, after, limit) => [...memory.documents]
      .filter(([key]) => key.startsWith(path + '/') && !key.slice(path.length + 1).includes('/'))
      .map(([key, data]) => ({ id: key.slice(path.length + 1), data }))
      .sort((a, b) => a.id.localeCompare(b.id))
      .filter(row => after === null || row.id > after)
      .slice(0, limit),
  };
});

it('adds a historical day-14 milestone while keeping the legacy claim at 50 points and three badges', async () => {
  for (let day = 1; day <= 14; day++) {
    const { snapshot } = await claim(day);
    expect(snapshot.badges).toHaveLength(3);
    expect(snapshot.balance).toBe(day * 50);
  }
  const result = await get();
  expect(result.currentStreak).toBe(0);
  expect(result.badges.slice(0, 4).map(b => b.unlockedAtMillis)).toEqual([at(1), at(3), at(7), at(14)]);
  expect((await get()).badges).toEqual(result.badges);
});

it('deduplicates backed-up sessions and credits separate measured reps and complete sessions', async () => {
  const backup = { ...store, list: async () => [] };
  for (let index = 0; index < 5; index++) {
    const id = 's' + index;
    const input = completedStandaloneBackup(id, 20, 5);
    await backupWorkout(backup, actor, input);
    await backupWorkout(backup, actor, input);
  }
  const result = await get();
  expect(result.badges.slice(4).map(b => b.progress)).toEqual([1, 5, 100, 0]);
  expect(result.badges.slice(4, 7).every(b => b.unlockedAtMillis !== null)).toBe(true);
  expect((await get()).badges).toEqual(result.badges);
});

it('counts a completed routine once, excludes its session from workout count and rejects incomplete or fictional evidence', async () => {
  const backup = { ...store, list: async () => [] };
  await backupWorkout(backup, actor, command);
  const base = { ...command, kind: 'routine', id: 'r1', payload: routinePayload };
  const initial = await backupWorkout(backup, actor, base);
  const sessionPath = root + '/members/member/workoutBackups/session-s1';
  memory.documents.set(sessionPath.replace('s1', 'fixture'), {
    ...memory.documents.get(sessionPath), id: 'fixture', key: 'session-fixture', payloadJson: JSON.stringify({
      ...payload, sessionId: 'fixture', repetitions: 100, provenance: 'recordedFixture',
    }),
  });
  expect((await get()).badges.slice(4).map(b => b.progress)).toEqual([0, 0, 2, 0]);
  const end = Date.parse(payload.endedAt) * 1000;
  const finished = {
    ...routinePayload, finished: true, updatedAtMicros: end, sessions: { 0: ['s1'] },
    attempt: {
      ...routinePayload.attempt, finished: true, updatedAtMicros: end, finishedAtMicros: end,
      entries: [{ ...routinePayload.attempt.entries[0], status: 'completed', sessionIds: ['s1'], fullRepetitions: 2 }],
    },
  };
  await backupWorkout(backup, actor, { ...base, baseDigest: initial.digest, payload: finished });
  expect((await get()).badges.slice(4).map(b => b.progress)).toEqual([1, 1, 2, 1]);
});

it('requires canonical account scope and verified membership', async () => {
  await expect(memberAchievements(store, actor, { ...input, organizationId: 'other' })).rejects.toMatchObject({code: 'permission-denied'});
  await expect(memberAchievements(store, actor, { ...input, memberId: 'other' })).rejects.toThrow();
  await expect(memberAchievements(store, { ...actor, uid: 'other' }, input)).rejects.toMatchObject({code: 'permission-denied'});
});

it('qualifies an explicitly completed manual routine without awarding any AI repetitions', async () => {
  const end = routinePayload.updatedAtMicros;
  const base = { ...command, kind: 'routine', id: 'r1' };
  const completed = {
    ...routinePayload, finished: true, manualSets: {0: 1},
    attempt: { ...routinePayload.attempt, finished: true, finishedAtMicros: end, entries: [
      { ...routinePayload.attempt.entries[0], status: 'selfReportedCompleted', manualSets: 1 },
    ] },
  };
  const backup = { ...store, list: async () => [] };
  const {digest} = await backupWorkout(backup, actor, {
    ...base, payload: { ...completed, skipped: [0] },
  });
  expect((await get()).badges.slice(4).map(badge => badge.progress)).toEqual([0, 0, 0, 0]);
  await backupWorkout(backup, actor, { ...base, payload: completed, baseDigest: digest });
  expect((await get()).badges.slice(4).map(badge => badge.progress)).toEqual([1, 1, 0, 1]);
});

it('keeps successful achievements permanent across later synchronization and skips scans after all workout targets', async () => {
  const backup = { ...store, list: async () => [] };
  for (let i = 0; i < 4; i++) {
    const id = 'standalone-' + i;
    await backupWorkout(backup, actor, completedStandaloneBackup(id, 25));
  }
  await backupWorkout(backup, actor, command);
  const end = Date.parse(payload.endedAt) * 1000;
  const finished = {
    ...routinePayload, finished: true, updatedAtMicros: end, sessions: { 0: ['s1'] },
    attempt: {
      ...routinePayload.attempt, finished: true, updatedAtMicros: end, finishedAtMicros: end,
      entries: [{ ...routinePayload.attempt.entries[0], status: 'completed', sessionIds: ['s1'], fullRepetitions: 2 }],
    },
  };
  await backupWorkout(backup, actor, { ...command, kind: 'routine', id: 'r1', payload: finished });
  const first = await get();
  expect(first.badges.slice(4).every(b => b.unlockedAtMillis !== null)).toBe(true);
  const noScan = { ...store, page: async () => { throw new Error('History should not be scanned'); } };
  expect(await memberAchievements(noScan, actor, input, () => at(31))).toEqual(first);
});

it('finds valid history past the first thousand backup heads', async () => {
  const path = root + '/members/member/workoutBackups/';
  for (let i = 0; i < 1001; i++) {
    const id = 'routine-' + i.toString().padStart(4, '0');
    memory.documents.set(path + id, { classification: 'fictional_synthetic' });
  }
  await backupWorkout({ ...store, list: async () => [] }, actor, completedStandaloneBackup('s1', 2));
  expect((await get()).badges.slice(4).map(badge => badge.progress)).toEqual([1, 1, 2, 0]);
});

it('credits measured reps but not a complete workout when standalone target completion is missing', async () => {
  await backupWorkout({ ...store, list: async () => [] }, actor, {
    ...command, payload: { ...payload, poseMetrics: { ...payload.poseMetrics, publishedRoutineId: null } },
  });
  expect((await get()).badges.slice(4).map(badge => badge.progress)).toEqual([0, 0, 2, 0]);
});

it('counts a completed video timer only once and never as AI measured repetitions', async () => {
  const backup = { ...store, list: async () => [] };
  await backupWorkout(backup, actor, {
    ...command, schemaVersion: 2, kind: 'routine', id: 'r1', payload: timedBackupFixture(),
  });
  const replay = timedBackupFixture();
  replay.id = replay.attempt.id = 'r2';
  await backupWorkout(backup, actor, {
    ...command, schemaVersion: 2, kind: 'routine', id: 'r2', payload: replay,
  });
  expect((await get()).badges.slice(4).map(badge => badge.progress)).toEqual([1, 1, 0, 1]);
});

it('isolates ordinary members and canonical FYP accounts sharing the default organization', async () => {
  const member = { ...actor, uid: 'fyp-member' };
  memory.documents.set('users/fyp-member', { organizationId: 'gainpath', datasetSource: 'fictionalFyp' });
  memory.documents.set(root + '/members/fyp-member', {
    organizationId: 'gainpath', userId: 'fyp-member', role: 'member', status: 'active', branchIds: [],
  });
  const own = completedStandaloneBackup('s1', 5);
  await backupWorkout({ ...store, list: async () => [] }, member, {
    ...own, memberId: member.uid, payload: { ...own.payload, userId: member.uid },
  });
  expect((await get()).badges.slice(4).map(badge => badge.progress)).toEqual([0, 0, 0, 0]);
  const result = await memberAchievements(store, member, input, () => at(31));
  expect(result.badges.slice(4).map(badge => badge.progress)).toEqual([1, 1, 5, 0]);
});
