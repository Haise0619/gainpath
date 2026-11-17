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
import type {WorkoutRankingProvider} from '../src/modules/recommendation/workout-recommendation-ranking';

const org = 'gainpath', member = 'learner', root = 'orgs/' + org;
const now = Date.parse('2026-11-14T00:00:00Z');
const workoutPath = root + '/members/' + member + '/workoutBackups';
const consentPath = root + '/recommendationConsent/' + member;
const auth = {uid: member, token: {email_verified: true}};

function fixture(coachIsVerified: (uid:string)=>Promise<boolean> = async()=>false, provider?:WorkoutRankingProvider) {
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
  const runtime = createWorkoutBackupRuntime({collection: query} as unknown as Firestore, coachIsVerified, undefined, {provider});
  const deps = {store, runtime, clock: () => now, readAuthIdentity: async (uid: string) =>
    ({uid, email: 'learner@example.test', disabled: false, emailVerified: true, tokensValidAfterMillis: 0})};
  return {store, add, deps, deliver: (key: string) => evaluateSavedWorkout(deps, org, member, key),
    lifecycle: createCanonicalRecommendationLifecycle(deps)};
}

describe('AI personalized canonical delivery',()=>{
  const grantAi=(f:ReturnType<typeof fixture>)=>{
    const consent=f.store.documents.get(consentPath)!;
    (consent.purposes as any).externalAiInference={...(consent.purposes as any).recommendationGeneration};
    consent.revision=4;
  };
  const validInference=(request:Parameters<WorkoutRankingProvider>[0])=>({
    providerSource:'mock_or_recorded' as const,cacheHit:false,model:'fixture-model',latencyMillis:2,
    usage:{inputTokens:90,outputTokens:30,thinkingTokens:7,totalTokens:127},
    text:JSON.stringify({recommendations:['content','routine','trainer'].flatMap(kind=>{
      const candidates=request.candidates.filter(candidate=>candidate.kind===kind);
      if(!candidates.length)return [];
      return [{recommendationType:kind,selectedCandidateId:candidates[0].label,
        ranking:candidates.map(candidate=>candidate.label),relevantWorkoutFactors:candidates[0].factors.slice(0,1)}];
    })}),
  });
  const addRoutines=(f:ReturnType<typeof fixture>)=>{
    for(const [id,minutes] of [['short',15],['long',45]] as const)f.store.documents.set(root+'/content/'+id,{
      schemaVersion:2,kind:'routine_v2',status:'published',sourceBlueprintId:id,title:id+' foundations',
      difficulty:'Beginner',estimatedMinutes:minutes,
      exercises:[{entryId:id+'-squat',exerciseId:DEMO_EXERCISES.squat,name:'Squat',sets:2,reps:8,restSeconds:60,
        executionMode:'aiTracked',tutorialSteps:[{title:'Setup',description:'Stand comfortably.',imageUrl:''}]}],
    });
  };
  it('uses a permitted AI winner for actual Routine and Tutorial delivery and saves the method',async()=>{
    let calls=0;
    const provider:WorkoutRankingProvider=async request=>{
      calls++;
      return {providerSource:'mock_or_recorded',cacheHit:false,model:'test-model',latencyMillis:1,
        usage:{inputTokens:90,outputTokens:30,thinkingTokens:0,totalTokens:120},
        text:JSON.stringify({recommendations:['content','routine'].map(kind=>{
          const rows=request.candidates.filter(c=>c.kind===kind);
          const labels=rows.map(c=>c.label).reverse();
          return {recommendationType:kind,selectedCandidateId:labels[0],ranking:labels,
            relevantWorkoutFactors:['exercise_match']};
        })})};
    };
    const f=fixture(undefined,provider);addRoutines(f);
    const consent=f.store.documents.get(consentPath)!;
    (consent.purposes as any).externalAiInference={...(consent.purposes as any).recommendationGeneration};
    consent.revision=4;
    const ids=await f.deliver(f.add('ai-routine',null));
    expect(ids).toHaveLength(2);
    expect(calls).toBe(1);
    const records=ids.map(id=>f.store.documents.get(root+'/canonicalRecommendations/'+id)!);
    expect(records.every(r=>(r.suggestion as any).ai.method==='gemini')).toBe(true);
    const routine=records.find(r=>(r.suggestion as any).target.kind==='routine')!;
    const detail=await f.lifecycle.member(auth,org,String(routine.id),'resolve',null,null);
    expect(detail).toMatchObject({kind:'routine',aiMethod:'gemini',state:'available',exerciseCount:1});
    expect([...f.store.documents.keys()].filter(p=>p.startsWith(root+'/notifications/'))).toHaveLength(2);
    expect(await f.deliver('session-ai-routine')).toEqual([]);
    expect(calls).toBe(1);
  });
  it('keeps three-kind target validation and permission boundaries with rule fallback',async()=>{
    let calls=0;
    const f=fixture(undefined,async()=>{calls++;throw Error('provider offline');});addRoutines(f);
    const ids=await f.deliver(f.add('rules-routine',null));
    expect(ids).toHaveLength(2);expect(calls).toBe(0);
    const routineId=ids.find(id=>(f.store.documents.get(root+'/canonicalRecommendations/'+id)!.suggestion as any).target.kind==='routine')!;
    expect(await f.lifecycle.member(auth,org,routineId,'resolve',null,null)).toMatchObject({kind:'routine',state:'available',aiMethod:'rule_fallback'});
    f.store.documents.get(root+'/content/short')!.status='draft';
    expect(await f.lifecycle.member(auth,org,routineId,'resolve',null,null)).toMatchObject({state:'unavailable',target:null});
  });

  it('runs provider calls outside transactions and persists their source, cache and full usage',async()=>{
    let inTransaction=false,calls=0;
    const f=fixture(undefined,async request=>{
      calls++;expect(inTransaction).toBe(false);return validInference(request);
    });
    grantAi(f);addRoutines(f);
    const store:DocumentStore={transact:work=>f.store.transact(async tx=>{
      inTransaction=true;
      try{return await work(tx);}finally{inTransaction=false;}
    })};
    const ids=await evaluateSavedWorkout({...f.deps,store},org,member,f.add('outside-transaction',null));
    expect(calls).toBe(1);expect(ids).toHaveLength(2);
    for(const id of ids)expect(f.store.documents.get(root+'/canonicalRecommendations/'+id)).toMatchObject({
      suggestion:{ai:{method:'gemini',providerSource:'mock_or_recorded',cacheHit:false,thinkingTokens:7,totalTokens:127}},
    });
  });

  it('ranks actual Tutorials, Routines and verified Coaches once and atomically delivers all three to Inbox',async()=>{
    let calls=0;
    const f=fixture(async()=>true,async request=>{
      calls++;
      expect(request.context).toMatchObject({
        goal:'general_fitness',experience:'beginner',frequency:'occasional',duration:'short',
      });
      expect(request.context.form).toBeUndefined();
      expect(new Set(request.candidates.map(candidate=>candidate.kind))).toEqual(new Set(['content','routine','trainer']));
      const coach=request.candidates.find(candidate=>candidate.kind==='trainer')!;
      expect(coach.factors).toContain('goal_match');
      expect(coach.factors).toContain('coach_specialization');
      expect(coach.factors).not.toContain('exercise_match');
      expect(coach.factors).not.toContain('form_practice');
      return {...validInference(request),text:JSON.stringify({recommendations:['content','routine','trainer'].map(kind=>{
        const candidates=request.candidates.filter(candidate=>candidate.kind===kind).reverse();
        return {recommendationType:kind,selectedCandidateId:candidates[0].label,
          ranking:candidates.map(candidate=>candidate.label),relevantWorkoutFactors:candidates[0].factors.slice(0,1)};
      })})};
    });
    const seed=await buildModule13DemoDataset({nowMillis:now});
    for(const [path,data] of Object.entries(seed.documents)){
      if(path.startsWith(root+'/coaches/')||path.startsWith(root+'/coachProfiles/')||
        path.startsWith(root+'/coachAvailability/')||path.startsWith(root+'/branches/')||
        path.startsWith(root+'/settings/')||seed.coachIds.some(uid=>path==='users/'+uid||path===root+'/members/'+uid)){
        f.store.documents.set(path,data);
      }
    }
    f.store.documents.get(root+'/members/'+member)!.branchIds=['main'];
    f.store.documents.set(root+'/profiles/'+member,{
      goals:['generalFitness'],experience:'beginner',preferredWorkoutDuration:15,
    });
    grantAi(f);addRoutines(f);
    f.add('prior-three-kind-practice',null,{},now-4000);
    const key=f.add('current-three-kind-practice',null);
    const started=performance.now();
    const ids=await f.deliver(key);
    expect(ids).toHaveLength(3);expect(calls).toBe(1);
    const records=ids.map(id=>f.store.documents.get(root+'/canonicalRecommendations/'+id)!);
    expect(new Set(records.map(record=>(record.suggestion as any).target.kind))).toEqual(new Set(['content','routine','trainer']));
    for(const id of ids){
      expect(f.store.documents.has(root+'/canonicalRecommendationDeliveries/'+id)).toBe(true);
      expect(f.store.documents.get(root+'/canonicalRecommendations/'+id)).toMatchObject({
        status:'delivered',suggestion:{ai:{method:'gemini',providerSource:'mock_or_recorded'}},
      });
      expect(await f.lifecycle.member(auth,org,id,'resolve',null,null)).toMatchObject({state:'available',aiMethod:'gemini'});
    }
    expect(records.filter(record=>(record.suggestion as any).ai.changedOrder)).toHaveLength(3);
    expect([...f.store.documents.keys()].filter(path=>path.startsWith(root+'/notifications/'))).toHaveLength(3);
    expect(await f.deliver(key)).toEqual([]);
    expect(await f.deliver(f.add('repeat-three-kind-practice',null))).toEqual([]);
    expect(calls).toBe(1);
    console.info(JSON.stringify({
      measurement:'three_kind_memory_store_with_mocked_gemini',calls,delivered:ids.length,
      durationMillis:performance.now()-started,realProviderCalls:0,
    }));
  });

  it('uses rule delivery when a consented provider fails',async()=>{
    let calls=0;
    const f=fixture(undefined,async()=>{calls++;throw Error('private service failure');});
    grantAi(f);addRoutines(f);
    const ids=await f.deliver(f.add('consented-failure',null));
    expect(ids).toHaveLength(2);expect(calls).toBe(1);
    for(const id of ids)expect(f.store.documents.get(root+'/canonicalRecommendations/'+id)).toMatchObject({
      suggestion:{ai:{method:'rule_fallback',fallbackReason:'provider_unavailable'}},status:'delivered',
    });
    expect([...f.store.documents.keys()].filter(path=>path.startsWith(root+'/notifications/'))).toHaveLength(2);
    expect(JSON.stringify([...f.store.documents])).not.toContain('private service failure');
  });

  it('grounds Coach AI factors in the goal named in the minimized context for a multi-goal Member',async()=>{
    let calls=0;
    const f=fixture(async()=>true,async request=>{
      calls++;
      expect(request.context.goal).toBe('weight_management');
      const coaches=request.candidates.filter(candidate=>candidate.kind==='trainer');
      expect(coaches).toHaveLength(1);
      expect(coaches[0].factors).not.toContain('goal_match');
      expect(coaches[0].factors).not.toContain('coach_specialization');
      return validInference(request);
    });
    const seed=await buildModule13DemoDataset({nowMillis:now});
    for(const [path,data] of Object.entries(seed.documents)){
      if(path.startsWith(root+'/coaches/')||path.startsWith(root+'/coachProfiles/')||
        path.startsWith(root+'/coachAvailability/')||path.startsWith(root+'/branches/')||
        path.startsWith(root+'/settings/')||seed.coachIds.some(uid=>path==='users/'+uid||path===root+'/members/'+uid)){
        f.store.documents.set(path,data);
      }
    }
    for(const [index,coachId] of seed.coachIds.entries()){
      const coach=f.store.documents.get(root+'/coaches/'+coachId);
      if(coach)Object.assign(coach,index===0?
        {status:'published',specialty:'Strength training',specializationTags:['strength']}:{status:'draft'});
    }
    f.store.documents.get(root+'/members/'+member)!.branchIds=['main'];
    f.store.documents.set(root+'/profiles/'+member,{goals:['loseWeight','buildMuscle'],experience:'beginner'});
    grantAi(f);
    f.add('prior-multigoal-practice',null,{},now-4000);
    const ids=await f.deliver(f.add('current-multigoal-practice',null));
    expect(calls).toBe(1);
    const coaching=ids.map(id=>f.store.documents.get(root+'/canonicalRecommendations/'+id)!)
      .find(record=>(record.suggestion as any).target.kind==='trainer');
    expect(coaching).toBeDefined();
    expect((coaching!.suggestion as any).summary).not.toMatch(/specializes in weight management/);
  });

  it('stops delivery if external AI consent is revoked while inference is pending',async()=>{
    const f=fixture(undefined,async request=>{
      const consent=f.store.documents.get(consentPath)!;
      const purpose=(consent.purposes as any).externalAiInference;
      Object.assign(purpose,{granted:false,revision:2,revokedAtMillis:now});
      Object.assign(consent,{revision:5,updatedAtMillis:now});
      return validInference(request);
    });
    grantAi(f);addRoutines(f);
    expect(await f.deliver(f.add('midcall-revoke',null))).toEqual([]);
    expect([...f.store.documents.keys()].filter(path=>path.startsWith(root+'/notifications/'))).toHaveLength(0);
  });

  it('falls back to a current target when a selected publication is removed during inference',async()=>{
    const f=fixture(undefined,async request=>{
      f.store.documents.delete(root+'/content/Beginner');
      return validInference(request);
    });
    grantAi(f);
    const ids=await f.deliver(f.add('midcall-deletion',null));
    expect(ids).toHaveLength(1);
    expect(f.store.documents.get(root+'/canonicalRecommendations/'+ids[0])).toMatchObject({
      suggestion:{targetLabel:'Advanced Squat',ai:{method:'rule_fallback'}},status:'delivered',
    });
  });

  it('discards stale profile claims when goals, duration and experience change during inference',async()=>{
    const f=fixture(undefined,async request=>{
      f.store.documents.set(root+'/profiles/'+member,{
        goals:['buildMuscle'],experience:'advanced',preferredWorkoutDuration:45,
      });
      return validInference(request);
    });
    f.store.documents.set(root+'/profiles/'+member,{
      goals:['generalFitness'],experience:'beginner',preferredWorkoutDuration:15,
    });
    grantAi(f);
    const ids=await f.deliver(f.add('midcall-profile-change',null));
    expect(ids).toHaveLength(1);
    expect(f.store.documents.get(root+'/canonicalRecommendations/'+ids[0])).toMatchObject({
      suggestion:{targetLabel:'Advanced Squat',ai:{
        method:'rule_fallback',fitnessGoals:['buildMuscle'],
        context:{goal:'muscle_gain',experience:'advanced',duration:'long'},
      }},
    });
  });

  it.each([
    ['legacy routine',1,'routine',false,'aiTracked',false,true],
    ['current routine',2,'routine_v2',false,'aiTracked',false,true],
    ['retired AI execution',2,'routine_v2',true,'aiTracked',false,false],
    ['retired manual execution',2,'routine_v2',true,'legacyManual',false,true],
    ['missing timed media',2,'routine_v2',false,'videoGuidedTimed',false,false],
    ['valid timed media',2,'routine_v2',false,'videoGuidedTimed',true,true],
  ] as const)('validates executable published destinations for %s',async(_name,schemaVersion,kind,retired,mode,video,expected)=>{
    const f=fixture();addRoutines(f);f.store.documents.delete(root+'/content/long');
    const routine=f.store.documents.get(root+'/content/short')!;
    Object.assign(routine,{schemaVersion,kind});
    if(retired || mode==='videoGuidedTimed'){
      const exerciseId=retired?'wall-push-up-side-v1':'fictional-timed-exercise';
      f.store.documents.set(root+'/exerciseVideos/'+exerciseId,{
        isActive:true,executionMode:retired?'aiTracked':'videoGuidedTimed',
      });
      (routine.exercises as any[]).push({
        entryId:'second',exerciseId,name:'Additional movement',sets:1,restSeconds:30,executionMode:mode,
        ...(mode==='videoGuidedTimed'?{durationSeconds:30}:{reps:8}),
        ...(video?{videoUrl:'https://media.example.test/movement.mp4'}:{}),
      });
    }
    const ids=await f.deliver(f.add('execution-'+schemaVersion+'-'+mode+'-'+video,null));
    const routines=ids.map(id=>f.store.documents.get(root+'/canonicalRecommendations/'+id)!)
      .filter(record=>(record.suggestion as any).target.kind==='routine');
    expect(routines).toHaveLength(Number(expected));
    if(expected)expect(await f.lifecycle.member(auth,org,String(routines[0].id),'resolve',null,null))
      .toMatchObject({kind:'routine',state:'available',target:{routineId:'short'}});
  });
});

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
  it('automatically delivers published routine_v2 tutorials and revalidates withdrawal',async()=>{
    const f=fixture();
    for(const difficulty of ['Beginner','Advanced']){
      const publication=f.store.documents.get(root+'/content/'+difficulty)!;
      f.store.documents.set(root+'/content/'+difficulty,{...publication,schemaVersion:2,kind:'routine_v2'});
    }
    const key=f.add('v2-workout',null),[id]=await f.deliver(key);
    expect(id).toBeTruthy();
    expect(await f.lifecycle.member(auth,org,id,'resolve',null,null)).toMatchObject({
      kind:'content',state:'available',targetLabel:'Beginner Squat',
      target:{destination:{routineId:'Beginner',exerciseId:DEMO_EXERCISES.squat,exerciseIndex:0,dayNumber:1}},
    });
    expect(await f.deliver(key)).toEqual([]);
    f.store.documents.get(root+'/content/Beginner')!.status='draft';
    expect(await f.lifecycle.member(auth,org,id,'resolve',null,null)).toMatchObject({state:'unavailable',target:null});
  });
  it.each([{schemaVersion:1},{schemaVersion:99},{status:'draft'},{archived:true},{isActive:false}])(
    'excludes malformed or withdrawn v2 tutorials %j',async flags=>{
      const f=fixture();
      for(const difficulty of ['Beginner','Advanced']){
        const publication=f.store.documents.get(root+'/content/'+difficulty)!;
        f.store.documents.set(root+'/content/'+difficulty,{...publication,schemaVersion:2,kind:'routine_v2',...flags});
      }
      expect(await f.deliver(f.add('invalid-v2',null))).toEqual([]);
    });
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
