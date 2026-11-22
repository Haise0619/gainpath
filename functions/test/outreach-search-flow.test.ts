import {it,expect} from 'vitest';
import {assistanceFixture} from './support/admin-ai-fixture';
const root='orgs/gainpath';
it('filters the active list and search by home branch, including the legacy fallback',async()=>{
  const f=assistanceFixture(),user=f.d.get('users/learner')!;
  f.d.set(root+'/branches/north',{displayName:'North Gym'});
  f.d.set(root+'/branches/south',{displayName:'South Gym'});
  user.primaryBranchId='north';
  expect(await f.call('members',{days:30,branchId:'north'})).toMatchObject({
    members:[expect.objectContaining({memberId:'learner'})],
    branches:expect.arrayContaining([{id:'north',name:'North Gym'}]),
  });
  expect(await f.call('member.search',{query:'learner',branchId:'south'})).toMatchObject({members:[]});
  expect(await f.call('member',{memberId:'learner',days:30})).toMatchObject({homeBranchName:'North Gym'});
  f.d.get('users/learner')!.homeBranchId='south';
  expect(await f.call('members',{days:30,branchId:'north'})).toMatchObject({members:[]});
  expect(await f.call('member.search',{query:'learner',branchId:'south'})).toMatchObject({
    members:[expect.objectContaining({memberId:'learner'})],
  });
  expect(f.calls()).toBe(0);
});
it('search finds an authorized TEST member outside Top 10 without inference or catalog writes',async()=>{
  const f=assistanceFixture(),m=f.d.get(root+'/members/learner')!;m.displayName='Module 13 TEST';m.isTest=true;
  expect((await f.call('members',{days:30}) as any).members).toHaveLength(0);
  const before=[...f.d.keys()];const r=await f.call('member.search',{query:'TEST'}) as any;
  expect(r.members).toEqual([expect.objectContaining({memberId:'learner',isTest:true,canAnalyze:true})]);
  expect(f.calls()).toBe(0);expect([...f.d.keys()]).toEqual(before);
  (f.d.get(root+'/recommendationConsent/learner')!.purposes as any).exerciseInsights.granted=false;
  expect((await f.call('member.search',{query:'learner@example.com'}) as any).members[0].canAnalyze).toBe(false);
  f.d.delete(root+'/members/admin');await expect(f.call('member.search',{query:'TEST'})).rejects.toThrow();
});
it('generates one tutorial with no routine/coach and no fabricated exact goal match',async()=>{
  const f=assistanceFixture();f.suggestions.splice(1);f.d.set(root+'/profiles/learner',{goals:['increaseFlexibility','generalFitness'],experience:'intermediate'});
  f.deps.aiProvider=async request=>({model:'fixture',providerSource:'mock_or_recorded',cacheHit:false,latencyMillis:5,usage:{inputTokens:1,outputTokens:1,thinkingTokens:0,totalTokens:2},text:JSON.stringify({recommendations:[{candidateId:(request.input.candidates as any[])[0].id,message:'Review your recent Squat practice for general training.'}]})});
  const r=await f.call('outreach.generate',{memberId:'learner',days:30,requestId:'single'}) as any;
  expect(r.recommendations).toHaveLength(1);expect(r.candidateCounts).toEqual({tutorial:1,routine:0,coach:0});expect(r.availabilityNotes).toHaveLength(2);
  expect([...f.d.keys()].filter(p=>p.includes('/notifications/'))).toHaveLength(0);
});
it('retains valid suggestions, reindexes previews and rechecks each target before Send',async()=>{
  const f=assistanceFixture(),resolve=f.deps.runtime.resolveTarget;
  f.deps.runtime.resolveTarget=async(...args)=>args[2].target.kind==='content'?null:resolve(...args);
  const p=await f.call('outreach.generate',{memberId:'learner',days:30,requestId:'partial-target'}) as any;
  expect(p.recommendations.map((r:any)=>r.index)).toEqual([0,1]);expect(p.recommendations[0].kind).toBe('routine');
  const saved=f.d.get(root+'/adminAiPreviews/'+p.previewId)!;
  expect((saved.suggestions as any[])[0].target.kind).toBe('routine');
});
it('no candidates or explicit abstention create no Preview, recommendations or notifications',async()=>{
  const f=assistanceFixture(),before=[...f.d.keys()];f.suggestions.splice(0);
  const r=await f.call('outreach.generate',{memberId:'learner',days:30,requestId:'none'}) as any;
  expect(r.previewId).toBe(null);expect(r.message).toContain('No eligible');expect(f.calls()).toBe(0);expect([...f.d.keys()]).toEqual(before);
  const g=assistanceFixture();g.deps.aiProvider=async()=>({model:'fixture',providerSource:'mock_or_recorded',cacheHit:false,latencyMillis:1,usage:{inputTokens:1,outputTokens:1,thinkingTokens:0,totalTokens:2},text:'{"recommendations":[]}'});
  expect((await g.call('outreach.generate',{memberId:'learner',days:30,requestId:'abstain'}) as any).previewId).toBe(null);
  expect([...g.d.keys()].some(p=>p.includes('/adminAiPreviews/'))).toBe(false);
});
