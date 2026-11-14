import { describe, expect, it } from 'vitest';
import type { Firestore } from 'firebase-admin/firestore';
import { MemoryStore } from './memory-store';
import { createCanonicalRecommendationLifecycle } from '../src/modules/recommendation/canonical-recommendation-lifecycle';
import { createWorkoutBackupRuntime } from '../src/modules/recommendation/workout-backup-recommendation-runtime';
import { demoWorkoutPayload, DEMO_EXERCISES } from '../src/modules/recommendation/demo-dataset';
import { digestOf } from '../src/modules/workouts/workout-backup-validation';
import { evaluateSavedWorkout } from '../src/modules/recommendation/workout-backup-recommendation-events';

const org = 'gainpath', member = 'learner', root = 'orgs/' + org;
const now = Date.parse('2026-11-14T00:00:00Z');
const workoutPath = root + '/members/' + member + '/workoutBackups';
const consentPath = root + '/recommendationConsent/' + member;
const auth = {uid: member, token: {email_verified: true}};

function fixture() {
  const store = new MemoryStore();
  const docs = store.documents;
  docs.set(root, {status: 'active'});
  docs.set('users/' + member, {organizationId: org, role: 'member'});
  docs.set(root + '/members/' + member, {organizationId: org, userId: member, role: 'member', status: 'active', branchIds: []});
  const policy = 'workout-backup-guidance-v1';
  const yes = {granted: true, revision: 1, grantedAtMillis: now - 1000, revokedAtMillis: null,
    noticePolicyId: policy, noticeVersion: 'workout-backup-v1', contentVersion: 'workout-backup-v1', historyStartAtMillis: 0};
  docs.set(consentPath, {schemaVersion: 2, policyVersion: 'module13-purpose-v2-local', organizationId: org, memberId: member,
    revision: 3, updatedAtMillis: now - 1000, purposes: {exerciseInsights: yes, recommendationGeneration: yes,
      recommendationDelivery: yes, externalAiInference: {granted: false, revision: 0, grantedAtMillis: null,
        revokedAtMillis: null, noticePolicyId: null, noticeVersion: null, contentVersion: null, historyStartAtMillis: null}}});
  const add = (id: string, score: number|null, options = {}, ended = now - 2000) => {
    const payload = demoWorkoutPayload(member, id, DEMO_EXERCISES.squat, score, ended, options);
    const key = 'session-' + id;
    docs.set(workoutPath + '/' + key, {schemaVersion: 1, classification: 'provisional_member_backup', kind: 'session', id, key,
      digest: digestOf(payload), payloadJson: JSON.stringify(payload)});
    return key;
  };
  const exerciseId = DEMO_EXERCISES.squat;
  docs.set(root + '/exerciseVideos/' + exerciseId, {exerciseName: 'Squat', isActive: true});
  for (const difficulty of ['Beginner', 'Advanced']) docs.set(root + '/content/' + difficulty, {kind: 'routine', status: 'published',
    exercises: [{exerciseId, name: difficulty + ' Squat', difficulty,
      tutorialSteps: [{title: 'Setup', description: 'Stand comfortably.', imageUrl: ''}]}]});
  const query = (prefix: string) => ({
    orderBy: () => query(prefix), where: () => query(prefix), limit: () => query(prefix),
    get: async () => ({docs: [...docs].filter(([path]) => path.startsWith(prefix + '/') &&
      !path.slice(prefix.length + 1).includes('/')).map(([path, data]) => ({id: path.split('/').at(-1), ref: {path}, data: () => data}))}),
  });
  const runtime = createWorkoutBackupRuntime({collection: query} as unknown as Firestore, async () => false);
  const deps = {store, runtime, clock: () => now, readAuthIdentity: async (uid: string) =>
    ({uid, email: 'learner@example.test', disabled: false, emailVerified: true, tokensValidAfterMillis: 0})};
  return {store, add, deps, deliver: (key: string) => evaluateSavedWorkout(deps, org, member, key),
    lifecycle: createCanonicalRecommendationLifecycle(deps)};
}

describe('automatic workout guidance', () => {
  it.each([
    ['dumbbell-shoulder-press-front-v1','dumbbell-shoulder-press-front-v1',4,'front',null],
    ['single-arm-dumbbell-row-side-v1','single-arm-row-side-v1',3,'side','rowSide'],
    ['bodyweight-reverse-lunge-side-v1','reverse-lunge-side-v1',5,'side','lungeSide'],
    ['standing-lateral-raise-front-v1','standing-lateral-raise-front-v1',6,'front',null],
  ])('supports general guidance for unscored %s', async (exercise, rule, schema, view, side) => {
    const f = fixture(), key = f.add('unscored',null);
    const record = f.store.documents.get(workoutPath+'/'+key)!;
    const payload = JSON.parse(String(record.payloadJson));
    payload.exerciseId = exercise;
    payload.poseMetrics = {...payload.poseMetrics,schemaVersion:schema,scoringVersion:rule,cameraView:view};
    if (side) payload.poseMetrics[side]='left';
    f.store.documents.set(workoutPath+'/'+key,{...record,payloadJson:JSON.stringify(payload),digest:digestOf(payload)});
    f.store.documents.set(root+'/exerciseVideos/'+exercise,{exerciseName:'Exercise practice',isActive:true});
    f.store.documents.set(root+'/content/guide',{kind:'routine',status:'published',exercises:[{
      exerciseId:exercise,name:'Exercise guide',tutorialSteps:[{title:'Setup',description:'Follow the guide.',imageUrl:''}],
    }]});
    const [id] = await f.deliver(key);
    expect(id).toBeTruthy();
    expect(await f.lifecycle.member(auth,org,id,'get',null,null)).toMatchObject({
      state:'available',objective:'technique_foundations',targetLabel:'Exercise guide',
    });
  });
  it('delivers unscored guidance with atomic receipt and suppresses replay and repeat workouts', async () => {
    const f = fixture();
    const key = f.add('first', null);
    const [first, replay] = await Promise.all([f.deliver(key), f.deliver(key)]);
    expect(first.concat(replay)).toHaveLength(1);
    const id = first.concat(replay)[0];
    expect(await f.deliver(f.add('second', 10))).toEqual([]);
    expect([...f.store.documents.keys()].filter(p => p.startsWith(root + '/notifications/'))).toHaveLength(1);
    expect(f.store.documents.has(root + '/canonicalRecommendationDeliveries/' + id)).toBe(true);
    const result = await f.lifecycle.member(auth, org, id, 'get', null, null);
    expect(result).toMatchObject({state: 'available', objective: 'technique_foundations', targetLabel: 'Beginner Squat', mode: 'workout_backup'});
    await expect(f.lifecycle.member({...auth, uid: 'other'}, org, id, 'get', null, null)).rejects.toThrow();
    expect((await f.lifecycle.member(auth, org, id, 'dismiss', 1, 'dismiss-test')).state).toBe('dismissed');
  });
  it('uses only recent compatible covered scores for progression', async () => {
    const f = fixture();
    f.add('poor-coverage', 5, {coverage: .2});
    f.add('wrong-version', 5, {incompatible: true});
    f.add('past', 90);
    const [id] = await f.deliver(f.add('current', 92));
    expect(await f.lifecycle.member(auth, org, id, 'get', null, null)).toMatchObject({
      objective: 'progression', targetLabel: 'Advanced Squat',
    });
    f.store.documents.delete(consentPath);
    expect((await f.lifecycle.member(auth, org, id, 'get', null, null)).state).toBe('withdrawn');
  });
  it('abstains for missing consent, forged digest, or stale workout', async () => {
    const f = fixture();
    expect(await f.deliver(f.add('old', 20, {}, now - 31 * 86400000))).toEqual([]);
    const key = f.add('changed', 20);
    f.store.documents.get(workoutPath + '/' + key)!.digest = 'incorrect';
    expect(await f.deliver(key)).toEqual([]);
    f.store.documents.delete(consentPath);
    expect(await f.deliver(f.add('no-consent', 20))).toEqual([]);
  });
  it('regrant can replace withdrawn retained guidance after cooldown without replay duplicates', async () => {
    const f = fixture();
    const key = f.add('retained', null);
    const [first] = await f.deliver(key);
    const later = now + 8 * 86400000;
    const consent = structuredClone(f.store.documents.get(consentPath)!);
    const purposes = consent.purposes as Record<string, Record<string, unknown>>;
    purposes.recommendationGeneration = {...purposes.recommendationGeneration,
      revision: 2, grantedAtMillis: later, revokedAtMillis: null};
    f.store.documents.set(consentPath, {...consent, purposes, revision: 4, updatedAtMillis: later});
    f.deps.clock = () => later;
    expect((await f.lifecycle.member(auth,org,first,'get',null,null)).state).toBe('withdrawn');
    const [replacement] = await f.deliver(key);
    expect(replacement).toBeTruthy();
    expect(replacement).not.toBe(first);
    expect(await f.deliver(key)).toEqual([]);
  });
});
