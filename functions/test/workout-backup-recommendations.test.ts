import {getFunction} from '@google-cloud/functions-framework/testing';
import { describe, expect, it } from 'vitest';
import type { Firestore } from 'firebase-admin/firestore';
import { MemoryStore } from './memory-store';
import { createCanonicalRecommendationLifecycle } from '../src/modules/recommendation/canonical-recommendation-lifecycle';
import { createWorkoutBackupRuntime } from '../src/modules/recommendation/workout-backup-recommendation-runtime';
import { demoWorkoutPayload, DEMO_EXERCISES, buildModule13DemoDataset } from '../src/modules/recommendation/demo-dataset';
import { digestOf } from '../src/modules/workouts/workout-backup-validation';
import { evaluateSavedWorkout, workoutEventPath } from '../src/modules/recommendation/workout-backup-recommendation-events';
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
  it('explicitly registers the production Firestore entrypoints with Functions Framework',()=>{
    expect(getFunction('module13WorkoutBackupCreated')).toBeTypeOf('function');
    expect(getFunction('module13WorkoutConsentChanged')).toBeTypeOf('function');
  });
  it('resolves authenticated Firestore snapshot paths when Eventarc omits wildcard params',()=>{
    const path='orgs/gainpath/members/test-member/workoutBackups/session-example';
    expect(workoutEventPath(path,{})).toEqual({organizationId:'gainpath',memberId:'test-member',key:'session-example'});
    expect(workoutEventPath(path,{memberId:'other'})).toBeNull();
    expect(workoutEventPath('orgs/gainpath/other/session-example',{})).toBeNull();
    expect(workoutEventPath(undefined,{})).toBeNull();
  });
  const grantAi=(f:ReturnType<typeof fixture>)=>{
    const consent=f.store.documents.get(consentPath)!;
    (consent.purposes as any).externalAiInference={...(consent.purposes as any).recommendationGeneration};
    consent.revision=4;
  };
  const validInference=(request:Parameters<WorkoutRankingProvider>[0])=>({
    providerSource:'mock_or_recorded' as const,cacheHit:false,model:'fixture-model',latencyMillis:2,
    usage:{inputTokens:90,outputTokens:30,thinkingTokens:7,totalTokens:127},
    text:JSON.stringify({rankedCandidateIds:request.candidates.map(candidate=>candidate.label)}),
  });
  const addRoutines=(f:ReturnType<typeof fixture>)=>{
    for(const [id,minutes] of [['short',15],['long',45]] as const)f.store.documents.set(root+'/content/'+id,{
      schemaVersion:2,kind:'routine_v2',status:'published',sourceBlueprintId:id,title:id+' foundations',
      difficulty:'Beginner',estimatedMinutes:minutes,
      exercises:[{entryId:id+'-squat',exerciseId:DEMO_EXERCISES.squat,name:'Squat',sets:2,reps:8,restSeconds:60,
        executionMode:'aiTracked',tutorialSteps:[{title:'Setup',description:'Stand comfortably.',imageUrl:''}]}],
    });
  };
  it('manual Outreach can suggest profile routines without workouts while automatic profile behavior is unchanged',async()=>{
    const f=fixture();addRoutines(f);f.store.documents.set(root+'/profiles/'+member,{goals:['buildMuscle'],experience:'beginner'});
    const auto=await f.store.transact(tx=>f.deps.runtime.backupSuggestions!(tx,org,member,'fitness-profile',now,0));
    const manual=await f.store.transact(tx=>f.deps.runtime.backupSuggestions!(tx,org,member,'fitness-profile',now,0,true));
    expect(auto).toEqual([]);expect(manual.filter(s=>s.target.kind==='routine')).toHaveLength(2);
    expect(manual.every(s=>!s.ai?.factors.includes('recent_activity'))).toBe(true);
    expect([...f.store.documents.keys()].some(p=>p.includes('/canonicalRecommendations/'))).toBe(false);
  });
  it('uses a permitted AI winner for actual Routine and Tutorial delivery and saves the method',async()=>{
    let calls=0;
    const provider:WorkoutRankingProvider=async request=>{
      calls++;
      return {providerSource:'mock_or_recorded',cacheHit:false,model:'test-model',latencyMillis:1,
        usage:{inputTokens:90,outputTokens:30,thinkingTokens:0,totalTokens:120},
        text:JSON.stringify({rankedCandidateIds:request.candidates.map(candidate=>candidate.label).reverse()})};
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

  it('rejects a coach when every otherwise eligible opening lasts only thirty minutes',async()=>{
    const f=fixture(async()=>true),seed=await buildModule13DemoDataset({nowMillis:now});
    for(const [path,data] of Object.entries(seed.documents)){
      if(path.startsWith(root+'/coaches/')||path.startsWith(root+'/coachProfiles/')||
        path.startsWith(root+'/coachAvailability/')||path.startsWith(root+'/branches/')||
        path.startsWith(root+'/settings/')||seed.coachIds.some(uid=>path==='users/'+uid||path===root+'/members/'+uid)){
        const copy=structuredClone(data) as any;
        if(path.startsWith(root+'/coachAvailability/')){
          if(copy.weeklyAvailability)for(const slot of copy.weeklyAvailability.schedule)slot.endMinute=slot.startMinute+30;
          if(copy.windows)for(const slot of copy.windows)slot.endAtMillis=slot.startAtMillis+30*60000;
        }
        f.store.documents.set(path,copy);
      }
    }
    f.store.documents.get(root+'/members/'+member)!.branchIds=['main'];
    f.store.documents.set(root+'/profiles/'+member,{goals:['generalFitness'],experience:'beginner'});
    const candidates=await f.store.transact(tx=>f.deps.runtime.backupSuggestions!(tx,org,member,'fitness-profile',now,0));
    expect(candidates).toEqual([]);
  });

  it('delivers one available goal-matched coach before any workout and deduplicates retries',async()=>{
    const f=fixture(async()=>true);
    const seed=await buildModule13DemoDataset({nowMillis:now});
    for(const [path,data] of Object.entries(seed.documents)){
      if(path.startsWith(root+'/coaches/')||path.startsWith(root+'/coachProfiles/')||
        path.startsWith(root+'/coachAvailability/')||path.startsWith(root+'/branches/')||
        path.startsWith(root+'/settings/')||seed.coachIds.some(uid=>path==='users/'+uid||path===root+'/members/'+uid)){
        f.store.documents.set(path,data);
      }
    }
    f.store.documents.get(root+'/members/'+member)!.branchIds=['main'];
    expect(await f.lifecycle.backup(org,member,'fitness-profile')).toEqual([]);
    f.store.documents.set(root+'/profiles/'+member,{goals:['generalFitness'],experience:'beginner',activity:'lightlyActive',heightCm:170,weightKg:71});
    const ids=await f.lifecycle.backup(org,member,'fitness-profile');
    expect(ids).toHaveLength(1);
    const result=await f.lifecycle.member(auth,org,ids[0],'resolve',null,null);
    expect(result).toMatchObject({kind:'trainer',exerciseLabel:'Fitness profile',aiMethod:'rule_fallback'});
    expect(result.summary).toContain('general fitness');
    expect(await f.lifecycle.backup(org,member,'fitness-profile')).toEqual([]);
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
      return {...validInference(request),text:JSON.stringify({rankedCandidateIds:request.candidates.map(candidate=>candidate.label).reverse()})};
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
    for (const record of records) {
      const saved = record.suggestion as {targetLabel:string; ai:{geminiFirstLabel:string;ruleFirstLabel:string;changedTopChoice:boolean;candidateCount:number}};
      expect(saved.ai.geminiFirstLabel).toBe(saved.targetLabel);
      expect(saved.ai.ruleFirstLabel).not.toBe(saved.targetLabel);
      expect(saved.ai.changedTopChoice).toBe(true);
      expect(saved.ai.candidateCount).toBeGreaterThan(1);
    }
    expect([...f.store.documents.keys()].filter(path=>path.startsWith(root+'/notifications/'))).toHaveLength(3);
    expect(await f.deliver(key)).toEqual([]);
    expect(await f.deliver(f.add('repeat-three-kind-practice',null))).toEqual([]);
    expect(calls).toBe(1);
    console.info(JSON.stringify({
      measurement:'three_kind_memory_store_with_mocked_gemini',calls,delivered:ids.length,
      durationMillis:performance.now()-started,realProviderCalls:0,
    }));
  });

  it('saves Gemini method and receipt for the single-type two-candidate Calf regression',async()=>{
    let calls=0;
    const f=fixture(undefined,async request=>{
      calls++;
      expect(request.context).toMatchObject({
        goal:'muscle_gain',experience:'beginner',frequency:'regular',reps:'moderate',
      });
      expect(request.candidates.map(row=>row.label)).toEqual(['T1','T2']);
      expect(request.candidates.every(row=>row.kind==='content')).toBe(true);
      return {...validInference(request),text:JSON.stringify({rankedCandidateIds:['T2','T1']})};
    });
    grantAi(f);
    f.store.documents.set(root+'/profiles/'+member,{goals:['buildMuscle'],experience:'beginner'});
    f.store.documents.set(root+'/exerciseVideos/'+DEMO_EXERCISES.calf,{
      exerciseName:'Standing calf raise',isActive:true,muscleCategory:'Calves',
    });
    for(const name of ['Beginner','Advanced']){
      const publication=f.store.documents.get(root+'/content/'+name)!;
      publication.exercises=(publication.exercises as any[]).map(entry=>({
        ...entry,exerciseId:DEMO_EXERCISES.calf,name:'Standing calf raise',
      }));
    }
    for(let i=0;i<5;i++)f.add('prior-calf-regression-'+i,null,{},now-10000-i*1000);
    const id='calf-output-regression',key='session-'+id;
    const payload=demoWorkoutPayload(member,id,DEMO_EXERCISES.calf,null,now-1000);
    f.store.documents.set(workoutPath+'/'+key,{schemaVersion:1,kind:'session',id,key,
      classification:'provisional_member_backup',digest:digestOf(payload),payloadJson:JSON.stringify(payload)});
    const ids=await f.deliver(key);
    expect(calls).toBe(1);
    expect(ids).toHaveLength(1);
    expect(f.store.documents.get(root+'/canonicalRecommendations/'+ids[0])).toMatchObject({
      status:'delivered',suggestion:{ai:{method:'gemini',candidateCount:2,changedTopChoice:true}},
    });
    expect(f.store.documents.has(root+'/canonicalRecommendationDeliveries/'+ids[0])).toBe(true);
    expect(await f.lifecycle.member(auth,org,ids[0],'resolve',null,null))
      .toMatchObject({state:'available',aiMethod:'gemini'});
  });

  it('persists a precise validation code with rule delivery for an invented candidate ID',async()=>{
    const f=fixture(undefined,async request=>({...validInference(request),
      text:JSON.stringify({rankedCandidateIds:['T404','T1']})}));
    grantAi(f);
    const ids=await f.deliver(f.add('invalid-provider-id',null));
    expect(ids).toHaveLength(1);
    expect(f.store.documents.get(root+'/canonicalRecommendations/'+ids[0])).toMatchObject({
      status:'delivered',suggestion:{ai:{method:'rule_fallback',
        fallbackReason:'invalid_provider_output',validationFailure:'invalid_candidate_id'}},
    });
    expect(f.store.documents.has(root+'/canonicalRecommendationDeliveries/'+ids[0])).toBe(true);
  });
  it('delivers a singleton using rules without an inference request',async()=>{
    let calls=0;
    const f=fixture(undefined,async request=>{calls++;return validInference(request);});
    grantAi(f);
    f.store.documents.delete(root+'/content/Advanced');
    const ids=await f.deliver(f.add('single-tutorial',null));
    expect(ids).toHaveLength(1);
    expect(calls).toBe(0);
    expect(f.store.documents.get(root+'/canonicalRecommendations/'+ids[0])).toMatchObject({
      status:'delivered',suggestion:{ai:{method:'rule_fallback',fallbackReason:'single_eligible_candidate'}},
    });
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
      expect(coaches).toHaveLength(0);

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
    expect((coaching!.suggestion as any).ai).toMatchObject({method:'rule_fallback',fallbackReason:'single_eligible_candidate'});
    expect((coaching!.suggestion as any).ai.model).toBeUndefined();
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
    const bookingTarget = detail.target as {coachId:string;observedStartAtMillis:number;observedEndAtMillis:number};
    expect(bookingTarget.observedEndAtMillis - bookingTarget.observedStartAtMillis).toBe(60 * 60000);
    const coachId=String(bookingTarget.coachId);
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
