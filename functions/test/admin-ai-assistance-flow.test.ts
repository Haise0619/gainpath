import {describe,it,expect} from 'vitest';
import {MemoryStore} from './memory-store';
import {createAdminAiService,type AdminAiDependencies} from '../src/modules/recommendation/admin-ai-service';
import {createCanonicalRecommendationLifecycle,type CanonicalSuggestion,type ReviewedCanonicalRuntime} from '../src/modules/recommendation/canonical-recommendation-lifecycle';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {demoWorkoutPayload,DEMO_EXERCISES} from '../src/modules/recommendation/demo-dataset';
import {createAdminAiProvider} from '../src/modules/recommendation/admin-ai-assistance';
import {assistanceFixture,now,admin} from './support/admin-ai-fixture';
const root='orgs/gainpath',member='learner';
describe('Admin-initiated outreach uses the existing canonical Inbox',()=>{
  it('sends the complete catalog beyond 24 entries, saved aliases and honest coverage to Planner',async()=>{
    const f=assistanceFixture();
    for(let i=0;i<29;i++)f.d.set(root+'/exerciseVideos/movement-'+i,{isActive:true,exerciseName:'Movement '+i,aliases:['Alias '+i],difficulty:'Beginner',category:'Accessory',muscleGroup:'Core',equipment:'Bodyweight'});
    f.d.set(root+'/gymEquipment/dumbbell',{isActive:true,name:'Dumbbells'});
    let input:any;f.deps.aiProvider=async request=>{input=request.input;throw Error('Fixture captured; no real request');};
    await expect(f.call('planner',{type:'exercise',days:30,instructions:'',requestId:'full-catalog'})).rejects.toThrow('Fixture captured');
    expect(input.catalog.exercises).toHaveLength(30);expect(input.catalog.exercises.find((e:any)=>e.id==='movement-28').aliases).toEqual(['Alias 28']);
    expect(input.equipmentAvailability).toEqual(['Dumbbells']);expect(input.coverage.difficulties.Beginner).toBe(30);
    expect(input.evidence.difficulty_Advanced).toBe('Advanced: 0 active exercises.');
  });
  for(const type of ['exercise','routine','program'])it(`generates ${type} drafts from current catalog facts without catalog writes`,async()=>{
    const f=assistanceFixture(),before=[...f.d.keys()];
    f.d.set(root+'/exerciseVideos/bridge',{isActive:true,exerciseName:'Glute Bridge',category:'Accessory',difficulty:'Beginner',equipment:'Bodyweight',editRevision:1});
    let providerInput:any;
    f.deps.aiProvider=async request=>{providerInput=request.input;return{providerSource:'mock_or_recorded',cacheHit:false,model:'fixture',latencyMillis:4,usage:{inputTokens:1,outputTokens:1,thinkingTokens:0,totalTokens:2},text:JSON.stringify({summary:'Catalog variety opportunities.',suggestions:[1,2,3].map(i=>({type,name:(type==='exercise'?['Dead Bug','Heel Slide','Bird Dog'][i-1]:'New '+type+' '+i),description:'A draft for Admin review.',contentGap:'Expands current coverage.',whyRecommended:'Adds another training option.',difficulty:'Beginner',evidenceKeys:['catalog_count'],...(type==='exercise'?{canonicalName:['Dead Bug','Heel Slide','Bird Dog'][i-1],aliases:[],variantOfExerciseId:'',variantDifference:'',category:'Accessory',primaryMuscleGroup:'Core',equipment:'Bodyweight',instructions:['Start on the floor.','Move carefully.']}:type==='routine'?{muscleGroups:['Legs'],equipment:'Bodyweight',durationMinutes:12,goal:'Muscle gain',exercises:[{exerciseId:DEMO_EXERCISES.squat,sets:3,reps:8,restSeconds:60},{exerciseId:'bridge',sets:3,reps:10,restSeconds:60}]}:{weeks:4,goal:'Muscle gain',trainingDays:[{weekday:1,routineId:'routine',routineDay:1,category:'Lower Body'},{weekday:4,routineId:'routine',routineDay:1,category:'Lower Body'}]})}))})};};
    before.push(root+'/exerciseVideos/bridge');
    const result=await f.call('planner',{type,days:30,instructions:'',requestId:'planner'}) as any;
    expect(providerInput.catalog.exercises).toHaveLength(2);expect(result.suggestions).toHaveLength(3);expect(result.grounding.enabled).toBe(false);expect([...f.d.keys()]).toEqual(before);
  });
  it('does not call AI for an empty catalog or when Admin authority is missing',async()=>{
    const f=assistanceFixture();f.d.delete(root+'/exerciseVideos/'+DEMO_EXERCISES.squat);
    await expect(f.call('planner',{type:'exercise',days:30,instructions:'',requestId:'planner'})).rejects.toThrow();expect(f.calls()).toBe(0);
    f.d.delete(root+'/members/admin');await expect(f.call('members',{days:30})).rejects.toThrow();
  });
  it('activity captured before the consent history boundary does not enter rankings',async()=>{
    const f=assistanceFixture(),consent=f.d.get(root+'/recommendationConsent/'+member)!;
    (consent.purposes as any).exerciseInsights.historyStartAtMillis=now-500;
    const result=await f.call('members',{days:30}) as any;expect(result.members).toEqual([]);
  });
  it('planner excludes contributions when external inference permission is absent',async()=>{
    const f=assistanceFixture(),consent=f.d.get(root+'/recommendationConsent/'+member)!;
    (consent.purposes as any).externalAiInference={...(consent.purposes as any).externalAiInference,granted:false};
    let input:any;
    f.deps.aiProvider=async request=>{input=request.input;throw new Error('fixture stops before inference');};
    await expect(f.call('planner',{type:'exercise',days:30,instructions:'',requestId:'planner'})).rejects.toThrow();
    expect(input.goalCounts).toEqual({});expect(input.exerciseUsage).toEqual({});expect(input.evidence.activity_scope).toContain('0 consenting');
  });
  it('Last 7 Days scopes both generation and Send candidate context',async()=>{
    const f=assistanceFixture(),boundaries:number[]=[];
    f.deps.runtime.backupSuggestions=async(_tx,_org,_member,_key,_now,boundary)=>{boundaries.push(boundary);return f.suggestions;};
    const p=await f.call('outreach.generate',{days:7,memberId:member,requestId:'seven-days'}) as any;
    await f.call('outreach.send',{previewId:p.previewId,selections:[{index:0,message:'Review this beginner guidance.'}]});
    expect(boundaries.length).toBeGreaterThanOrEqual(2);expect(boundaries.every(b=>b>=now-7*86400000)).toBe(true);
  });
  it('changed member features invalidate a previously generated preview',async()=>{
    const f=assistanceFixture(),p=await f.call('outreach.generate',{days:30,memberId:member,requestId:'preview1'}) as any;
    f.suggestions[0].ai!.context={experience:'advanced'};
    await expect(f.call('outreach.send',{previewId:p.previewId,selections:[{index:0,message:'Try this.'}]})).rejects.toThrow('context');
  });
  it('ranks actual completed summaries, excludes test members, and reads actual profile',async()=>{
    const f=assistanceFixture();f.d.set(root+'/members/m13-e2e-test',{organizationId:'gainpath',role:'member',status:'active',branchIds:[],displayName:'Module 13 TEST'});
    const top=await f.call('members',{days:30}) as any;
    expect(top.members).toHaveLength(1);expect(top.members[0]).toMatchObject({memberId:member,workouts:1});
    expect(await f.call('member',{days:30,memberId:member})).toMatchObject({goals:['buildMuscle'],experience:'beginner',workouts:1});expect(f.calls()).toBe(0);
  });
  it('previews three valid kinds, edits and sends atomically; retries never duplicate',async()=>{
    const f=assistanceFixture(),p=await f.call('outreach.generate',{days:30,memberId:member,requestId:'preview1'}) as any;
    expect(p.recommendations).toHaveLength(3);expect(f.calls()).toBe(1);
    const send={previewId:p.previewId,selections:p.recommendations.map((r:any)=>({index:r.index,message:r.message}))};
    const first=await f.call('outreach.send',send) as any;expect(first.ids).toHaveLength(3);
    expect(await f.call('outreach.send',send)).toEqual(first);
    expect([...f.d.keys()].filter(p=>p.startsWith(root+'/notifications/'))).toHaveLength(3);
    expect([...f.d.keys()].filter(p=>p.startsWith(root+'/canonicalRecommendationDeliveries/'))).toHaveLength(3);
    const lifecycle=createCanonicalRecommendationLifecycle(f.deps);
    for(const id of first.ids){
      const detail=await lifecycle.member({uid:member,token:{email_verified:true}},'gainpath',id,'resolve',null,null);
      expect(detail).toMatchObject({state:'available',aiMethod:'gemini'});
      const adminDetail=await lifecycle.adminDetail(admin,'gainpath',id) as any;
      expect(adminDetail.suggestion.source.kind).toBe('admin_outreach');expect(adminDetail.suggestion.outreach.sentBy).toBe('admin');
    }
    const again=await f.call('outreach.generate',{days:30,memberId:member,requestId:'preview2'}) as any;expect(again.recommendations).toHaveLength(3);expect(f.calls()).toBe(2);
  });
  it('manual generation and Send ignore automatic cooldown without changing its records',async()=>{
    const f=assistanceFixture();
    for(const s of f.suggestions)f.d.set(root+'/canonicalRecommendationFatigue/'+digestOf({member,need:s.needKey}),{untilMillis:now+7*86400000,marker:'preserve-automatic'});
    const before=[...f.d].filter(([p])=>p.includes('/canonicalRecommendationFatigue/'));
    const p=await f.call('outreach.generate',{days:30,memberId:member,requestId:'manual-despite-auto'}) as any;
    expect(p.recommendations).toHaveLength(3);
    const sent=await f.call('outreach.send',{previewId:p.previewId,selections:[{index:0,message:'Review this beginner guidance.'}]}) as any;
    expect(sent.ids).toHaveLength(1);expect([...f.d].filter(([p])=>p.includes('/canonicalRecommendationFatigue/'))).toEqual(before);
    const automatic=await createCanonicalRecommendationLifecycle(f.deps).backup('gainpath',member,'session-after-manual');expect(automatic).toEqual([]);
  });
  it('manual Send and Member dismissal do not create an automatic cooldown',async()=>{
    const f=assistanceFixture(),p=await f.call('outreach.generate',{days:30,memberId:member,requestId:'manual1'}) as any;
    const result=await f.call('outreach.send',{previewId:p.previewId,selections:[{index:0,message:'Review this beginner guidance.'}]}) as any;
    const lifecycle=createCanonicalRecommendationLifecycle(f.deps);
    await lifecycle.member({uid:member,token:{email_verified:true}},'gainpath',result.ids[0],'dismiss',1,'dismiss-manual');
    expect([...f.d.keys()].filter(p=>p.includes('/canonicalRecommendationFatigue/'))).toEqual([]);
    const automatic=await lifecycle.backup('gainpath',member,'session-after-manual');expect(automatic).toHaveLength(3);
  });
  it('revocation prevents generation and also blocks a previously generated Send',async()=>{
    const f=assistanceFixture(),p=await f.call('outreach.generate',{days:30,memberId:member,requestId:'preview1'}) as any;
    const consent=f.d.get(root+'/recommendationConsent/'+member)!;(consent.purposes as any).externalAiInference={...(consent.purposes as any).externalAiInference,granted:false};
    await expect(f.call('outreach.generate',{days:30,memberId:member,requestId:'preview2'})).rejects.toThrow();
    await expect(f.call('outreach.send',{previewId:p.previewId,selections:[{index:0,message:'Try this.'}]})).rejects.toThrow();
    expect(f.calls()).toBe(1);expect([...f.d.keys()].some(p=>p.startsWith(root+'/notifications/'))).toBe(false);
  });
  it('changed targets cannot be sent',async()=>{
    const f=assistanceFixture(),p=await f.call('outreach.generate',{days:30,memberId:member,requestId:'preview1'}) as any;
    f.suggestions.splice(0,1);
    await expect(f.call('outreach.send',{previewId:p.previewId,selections:[{index:0,message:'Try this.'}]})).rejects.toThrow();
  });
  it('another Admin cannot steal a preview and expired previews are unavailable',async()=>{
    const f=assistanceFixture(),p=await f.call('outreach.generate',{days:30,memberId:member,requestId:'preview1'}) as any;
    const raw=f.d.get(root+'/adminAiPreviews/'+p.previewId)!;raw.actorId='other';
    await expect(f.call('outreach.send',{previewId:p.previewId,selections:[{index:0,message:'Try this.'}]})).rejects.toThrow();raw.actorId='admin';raw.expiresAtMillis=now-1;
    await expect(f.call('outreach.send',{previewId:p.previewId,selections:[{index:0,message:'Try this.'}]})).rejects.toThrow();
  });
  it('Gemini transport uses the existing bounded schema adapter without exposing identity',async()=>{
    let body:any;const provider=createAdminAiProvider({apiKey:'fixture',fetcher:async(_url,init)=>{body=JSON.parse(String(init?.body));return new Response(JSON.stringify({candidates:[{finishReason:'STOP',content:{parts:[{text:'{"recommendations":[]}'}]}}]}));}});
    await provider({task:'outreach',input:{features:{experience:'beginner'},candidates:[{id:'C1',kind:'content',factors:[]}]}});
    expect(body.generationConfig.responseSchema.properties.recommendations).toBeDefined();expect(JSON.stringify(body)).not.toContain(member+'@');expect(body.tools).toBeUndefined();expect(body.systemInstruction.parts[0].text).toContain('"enum":["C1"]');expect(body.generationConfig.responseSchema.properties.recommendations.items.required).toEqual(['candidateId','message']);
  });
});
