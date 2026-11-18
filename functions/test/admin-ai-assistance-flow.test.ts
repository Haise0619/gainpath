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
  for(const type of ['exercise','routine','program'])it(`generates ${type} drafts from current catalog facts without catalog writes`,async()=>{
    const f=assistanceFixture(),before=[...f.d.keys()];
    f.deps.aiProvider=async request=>({providerSource:'mock_or_recorded',cacheHit:false,model:'fixture',latencyMillis:4,usage:{inputTokens:1,outputTokens:1,thinkingTokens:0,totalTokens:2},text:JSON.stringify({summary:'Catalog variety opportunities.',suggestions:[1,2,3].map(i=>({type,name:'New '+type+' '+i,description:'A draft for Admin review.',whyRecommended:'Expands the current catalog.',difficulty:'Beginner',category:'Accessory',muscleGroups:['Legs'],equipment:'Bodyweight',instructions:['Move carefully.'],durationMinutes:20,goal:'Muscle gain',exercises:type==='routine'?[{exerciseId:DEMO_EXERCISES.squat,sets:3,reps:8,restSeconds:60}]:[],routineIds:type==='program'?['routine']:[],evidenceKeys:['catalog_count']}))})});
    const result=await f.call('planner',{type,days:30,instructions:'',requestId:'planner'}) as any;
    expect(result.suggestions).toHaveLength(3);expect(result.grounding.enabled).toBe(false);expect([...f.d.keys()]).toEqual(before);
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
    const again=await f.call('outreach.generate',{days:30,memberId:member,requestId:'preview2'}) as any;expect(again.recommendations).toEqual([]);expect(f.calls()).toBe(1);
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
    await provider({task:'outreach',input:{features:{experience:'beginner'},candidates:[]}});
    expect(body.generationConfig.responseSchema.properties.recommendations).toBeDefined();expect(JSON.stringify(body)).not.toContain(member+'@');expect(body.tools).toBeUndefined();
  });
});
