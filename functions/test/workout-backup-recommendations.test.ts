import { describe, expect, it } from 'vitest';
import type { Firestore } from 'firebase-admin/firestore';
import { MemoryStore } from './memory-store';
import { createCanonicalRecommendationLifecycle } from '../src/modules/recommendation/canonical-recommendation-lifecycle';
import { createWorkoutBackupRuntime } from '../src/modules/recommendation/workout-backup-recommendation-runtime';
import { demoWorkoutPayload, DEMO_EXERCISES, buildModule13DemoDataset } from '../src/modules/recommendation/demo-dataset';
import { digestOf } from '../src/modules/workouts/workout-backup-validation';
import { evaluateSavedWorkout } from '../src/modules/recommendation/workout-backup-recommendation-events';
import {canonicalRecommendationPage} from '../src/modules/recommendation/canonical-recommendation-page';
import {createCanonicalRecommendationBackend} from '../src/modules/recommendation/canonical-recommendation-backend';
import type {DocumentStore} from '../src/platform/firestore/store';
import {createCanonicalRecommendationAdmin} from '../src/modules/recommendation/canonical-recommendation-admin';

const org = 'gainpath', member = 'learner', root = 'orgs/' + org;
const now = Date.parse('2026-11-14T00:00:00Z');
const workoutPath = root + '/members/' + member + '/workoutBackups';
const consentPath = root + '/recommendationConsent/' + member;
const auth = {uid: member, token: {email_verified: true}};

function fixture(coachIsVerified: (uid:string)=>Promise<boolean> = async()=>false) {
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
  const runtime = createWorkoutBackupRuntime({collection: query} as unknown as Firestore, coachIsVerified);
  const deps = {store, runtime, clock: () => now, readAuthIdentity: async (uid: string) =>
    ({uid, email: 'learner@example.test', disabled: false, emailVerified: true, tokensValidAfterMillis: 0})};
  return {store, add, deps, deliver: (key: string) => evaluateSavedWorkout(deps, org, member, key),
    lifecycle: createCanonicalRecommendationLifecycle(deps)};
}

describe('bounded recommendation pages and merged history API', () => {
  it('Admin detail performs one current projection rather than repeating the entire lookup',async()=>{
    const f=fixture(),[id]=await f.deliver(f.add('detail',null));
    f.store.documents.set('users/admin',{organizationId:org,role:'admin'});
    f.store.documents.set(root+'/members/admin',{organizationId:org,userId:'admin',role:'admin',status:'active',branchIds:[]});
    let lookups=0;
    const store:DocumentStore={transact:work=>f.store.transact(tx=>work({...tx,get:async p=>{
      if(p===root+'/canonicalRecommendations/'+id)lookups++;
      return tx.get(p);
    }}))};
    const result=await createCanonicalRecommendationAdmin({...f.deps,store})({app:{appId:'test-app'},
      auth:{uid:'admin',token:{email_verified:true,auth_time:Math.floor(now/1000),email:'learner@example.test'}},
      data:{schemaVersion:1,operation:'admin.queue.detail',data:{schemaVersion:1,organizationId:org,id}}});
    expect(result).toMatchObject({id,status:'delivered'});expect(lookups).toBe(1);
  });
  it('reuses privacy reads in one transaction and preserves current redaction', async () => {
    const f=fixture(),[id]=await f.deliver(f.add('page',null));
    const runtime={...f.deps.runtime,listIds:async()=>[id]};
    let transactions=0;const reads=new Map<string,number>();
    const store:DocumentStore={transact:work=>{
      transactions++;
      return f.store.transact(tx=>work({...tx,get:async path=>{
        reads.set(path,(reads.get(path)??0)+1);return tx.get(path);
      }}));
    }};
    const page=await canonicalRecommendationPage({...f.deps,runtime,store},auth,org,null,false);
    expect(page.records).toHaveLength(1);expect(transactions).toBe(1);
    expect(Math.max(...reads.values())).toBe(1);
    expect(page.records[0]).toEqual(await f.lifecycle.member(auth,org,id,'get',null,null));
    f.store.documents.delete(consentPath);
    const withdrawn=await canonicalRecommendationPage({...f.deps,runtime},auth,org,null,false,true);
    expect(withdrawn.records[0]).toMatchObject({state:'withdrawn',target:null,exerciseLabel:null});
    await expect(canonicalRecommendationPage({...f.deps,runtime},{...auth,uid:'foreign'},org,null,false,true)).rejects.toThrow();
  });

  it('dispatches replay only after Member authorization and rejects a supplied owner', async () => {
    const f=fixture();let calls=0;
    const backend=createCanonicalRecommendationBackend({...f.deps,replayHistory:async (o,u,after)=>{
      calls++;expect([o,u,after]).toEqual([org,member,null]);return{schemaVersion:1,checked:0,delivered:0,nextAfterId:null};
    }});
    const request={app:{appId:'test-app'},auth:{uid:member,token:{email_verified:true,iat:Math.floor(now/1000),auth_time:Math.floor(now/1000),email:'learner@example.test'}},
      data:{schemaVersion:1,operation:'member.history.replay',data:{schemaVersion:1,organizationId:org,afterId:null}}};
    expect(await backend(request)).toMatchObject({checked:0});expect(calls).toBe(1);
    await expect(backend({...request,data:{...request.data,data:{...request.data.data,memberId:'foreign'}}})).rejects.toThrow();
    expect(calls).toBe(1);
  });
});

describe('automatic workout guidance', () => {
  it('offers an available verified goal-matched Coach after repeated practice and revalidates credentials',async()=>{
    const f=fixture(async()=>true),seed=await buildModule13DemoDataset({nowMillis:now});
    for(const [path,data] of Object.entries(seed.documents)) {
      if(path.startsWith(root+'/coaches/')||path.startsWith(root+'/coachProfiles/')||
        path.startsWith(root+'/coachAvailability/')||path.startsWith(root+'/branches/')||
        path.startsWith(root+'/settings/')||seed.coachIds.some(uid=>path==='users/'+uid||path===root+'/members/'+uid)) {
        f.store.documents.set(path,data);
      }
    }
    f.store.documents.get(root+'/members/'+member)!.branchIds=['main'];
    f.store.documents.set(root+'/profiles/'+member,{goals:['generalFitness'],experience:'beginner'});
    const first=await f.deliver(f.add('first-practice',null,{},now-4000));
    expect(first).toHaveLength(1);
    const [id]=await f.deliver(f.add('repeat-practice',null));
    expect(id).toBeTruthy();
    const detail=await f.lifecycle.member(auth,org,id,'resolve',null,null);
    expect(detail).toMatchObject({kind:'trainer',state:'available',specialization:'Beginner strength'});
    const coachId=String((detail.target as {coachId:string}).coachId);
    f.store.documents.get(root+'/coachProfiles/'+coachId+'/certificationState/current')!.certificationVerified=false;
    expect(await f.lifecycle.member(auth,org,id,'resolve',null,null)).toMatchObject({state:'unavailable',target:null});
  });
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
