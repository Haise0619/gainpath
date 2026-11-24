import {expect, it} from 'vitest';
import {videoWorkoutPoints} from '../src/modules/gamification/video-workout-points';
import {buildPointsHistory} from '../src/modules/gamification/points-history';
import {auth, DAY, now, org, path, seed} from './reward-journey-fixture';

function fixture() {
  const store = seed();
  const videoUrl = 'https://example.test/workout.mp4';
  const mediaValidation = {schemaVersion: 1, videoUrl, generation: '1', bucket: 'fixtures', objectPath: 'workout.mp4'};
  const entry = {entryId: 'plank-start', exerciseId: 'timed-plank',
    executionMode: 'videoGuidedTimed', sets: 2, durationSeconds: 10, restSeconds: 0, videoUrl, mediaValidation};
  store.documents.set(path('exerciseVideos', 'timed-plank'), {isActive: true, executionMode: 'videoGuidedTimed', videoUrl, mediaValidation});
  store.documents.set(path('content', 'routine'), {schemaVersion: 2, kind: 'routine_v2', status: 'published', exercises: [entry]});
  store.documents.set(path('content', 'other-routine'), {schemaVersion: 2, kind: 'routine_v2', status: 'published', exercises: [entry]});
  let time = now;
  const move = (ms: number) => time += ms;
  const send = (stage: 'begin' | 'finish', set: number, runId = 'run', routineId = 'routine') =>
    videoWorkoutPoints(store, auth, {schemaVersion: 1, organizationId: org, routineId,
      entryId: 'plank-start', runId, set, action: stage + 'VideoWorkoutSet'}, () => time);
  const balance = () => store.documents.get(path('rewardBalances', auth.uid))?.points;
  return {store, move, send, balance};
}

it('credits five points only after each published set has elapsed', async () => {
  const f = fixture();
  await expect(f.send('finish', 1)).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(f.send('begin', 2)).rejects.toMatchObject({code: 'failed-precondition'});
  expect((await f.send('begin', 1)).status).toBe('started');
  f.move(2000);
  expect(await f.send('finish', 1)).toMatchObject({status: 'too_early', waitMillis: 8000, points: 0});
  f.move(8000);
  expect((await f.send('finish', 1)).status).toBe('set_completed');
  expect(f.balance()).toBe(1000);
  await f.send('begin', 2);
  f.move(10000);
  const results = await Promise.all([f.send('finish', 2), f.send('finish', 2)]);
  expect(results.map(row => row.status).sort()).toEqual(['already_awarded', 'awarded']);
  expect(f.balance()).toBe(1005);
  const awards = [...f.store.documents].filter(([key]) => key.includes('/rewardAwards/'))
    .map(([key, data]) => ({id: key.split('/').at(-1)!, data}));
  expect(buildPointsHistory(org, auth.uid, 1005, now + 20000,
    {claims: [], awards, adjustments: [], redemptions: []}).entries).toMatchObject([{source: 'workout_reward', points: 5}]);
  expect((await f.send('begin', 1, 'second', 'other-routine')).status).toBe('already_awarded');
  f.move(DAY);
  expect((await f.send('begin', 1, 'run')).status).toBe('already_awarded');
  expect((await f.send('begin', 1, 'third')).status).toBe('started');
});

it('rejects removed publications and expired or superseded runs', async () => {
  const f = fixture();
  await f.send('begin', 1);
  await f.send('begin', 1, 'new-run', 'other-routine');
  f.move(10000);
  await expect(f.send('finish', 1)).rejects.toMatchObject({code: 'failed-precondition'});
  f.store.documents.get(path('content', 'other-routine'))!.status = 'draft';
  await expect(f.send('finish', 1, 'new-run', 'other-routine')).rejects.toMatchObject({code: 'failed-precondition'});
  expect(f.balance()).toBe(1000);
});
