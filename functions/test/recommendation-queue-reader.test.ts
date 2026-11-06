import {expect,it} from 'vitest';
import {createRecommendationQueueList} from '../src/modules/recommendation/recommendation-queue-reader';
import {queueSecurityFixture} from './recommendation-queue-fixture';
import {queueLeadFromEngine} from '../src/modules/recommendation/recommendation-queue-generation';
import {prepareSyntheticScenario,SYNTHETIC_RECOMMENDATION_SCENARIOS} from './recommendation-evaluation.fixture';
async function fixture(){
  const f=await queueSecurityFixture(),p=await prepareSyntheticScenario(SYNTHETIC_RECOMMENDATION_SCENARIOS[5]);
  const lead=queueLeadFromEngine({id:'fictional-1',memberId:'member',need:SYNTHETIC_RECOMMENDATION_SCENARIOS[5].need,exerciseId:'fixture-squat',memberLabel:'Demo Member',exerciseLabel:'Squat',category:'Lower Body',evidenceStatus:'sufficient_synthetic'},'content',{recommendation:p,sourceFingerprint:'a'.repeat(64),targetLabels:{}},{fixtureSetId:'module13-c-v1',sourceVersion:'fixture-v1',configVersion:'fixture-v1',validityMillis:3600000} as any,'b'.repeat(64),'run',190000)!;
  const rows=[{id:'lead-a',data:{...lead,leadId:'lead-a'}},{id:'lead-b',data:{...lead,leadId:'lead-b',status:'expired'}}];
  const reader={readLeads:async(_org:string,after:string|null,limit:number)=>rows.filter(r=>after===null||r.id>after).slice(0,limit)};
  const invoke=createRecommendationQueueList({...f.deps,reader});const request={...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',kind:'content',status:'all',startAtMillis:100000,endAtMillis:200000,exerciseId:null,category:null,specialization:null,afterLeadId:null,limit:1}};
  return{...f,rows,reader,invoke,request};
}
it('returns ordered filtered pages, truthful pre-status counts and bounded facets',async()=>{
  const f=await fixture(),a=await f.invoke(f.request);expect(a.leads.map(l=>l.leadId)).toEqual(['lead-a']);expect(a.nextAfterLeadId).toBe('lead-a');expect(a.summary).toEqual({pending:1,processed:0,unavailable:1});expect(a.facets.categories).toEqual(['Lower Body']);
  const b=await f.invoke({...f.request,data:{...f.request.data,afterLeadId:a.nextAfterLeadId}});expect(b.leads.map(l=>l.leadId)).toEqual(['lead-b']);expect(b.nextAfterLeadId).toBeNull();
  expect((await f.invoke({...f.request,data:{...f.request.data,status:'pending'}})).leads).toHaveLength(1);
  expect((await f.invoke({...f.request,data:{...f.request.data,category:'Other'}})).leads).toEqual([]);
});
it.each([{limit:26},{limit:0},{endAtMillis:200001},{startAtMillis:200000},{startAtMillis:-1},{extra:'private'},{kind:['content']}])('rejects invalid bounds and unknown fields %j',async patch=>{
  const f=await fixture();await expect(f.invoke({...f.request,data:{...f.request.data,...patch}})).rejects.toThrow();
});
it('rejects excessive, foreign or private source data without partial results',async()=>{
  const f=await fixture();(f.rows[0].data as any).rawHistory=[];await expect(f.invoke(f.request)).rejects.toThrow();
  delete (f.rows[0].data as any).rawHistory;(f.rows[0].data as any).organizationId='foreign';await expect(f.invoke(f.request)).rejects.toThrow();
});
it('revalidates canonical Admin after a source query and sanitizes failures',async()=>{
  const f=await fixture();const invoke=createRecommendationQueueList({...f.deps,reader:{readLeads:async()=>{f.store.documents.get('users/admin')!.organizationId='foreign';return f.rows;}}});
  await expect(invoke(f.request)).rejects.toMatchObject({code:'permission-denied'});
});
it.each(['exerciseInsights','recommendationGeneration'])('refuses retained list details and facets after %s revocation during the source read',async purpose=>{
 const f=await fixture();const invoke=createRecommendationQueueList({...f.deps,reader:{readLeads:async()=>{
  const c=f.store.documents.get('orgs/synthetic-org/recommendationConsent/member')!;(c.purposes as any)[purpose].granted=false;return f.rows;
 }}});await expect(invoke(f.request)).rejects.toMatchObject({code:'permission-denied'});
});
it('refuses disabled Member identities before releasing retained list evidence',async()=>{
 const f=await fixture();const invoke=createRecommendationQueueList({...f.deps,reader:f.reader,readAuthIdentity:async uid=>({...await f.deps.readAuthIdentity(uid),disabled:uid==='member'})});
 await expect(invoke(f.request)).rejects.toMatchObject({code:'permission-denied'});
});
it.each(['consent','inactive'])('rechecks %s drift during final Admin identity refresh before releasing any evidence',async drift=>{
 const f=await fixture();let adminReads=0;const invoke=createRecommendationQueueList({...f.deps,reader:f.reader,readAuthIdentity:async uid=>{
  if(uid==='admin'&&++adminReads===2){if(drift==='consent')((f.store.documents.get('orgs/synthetic-org/recommendationConsent/member')!.purposes as any).exerciseInsights).granted=false;else f.store.documents.get('orgs/synthetic-org/members/member')!.status='inactive';}
  return f.deps.readAuthIdentity(uid);
 }});await expect(invoke(f.request)).rejects.toMatchObject({code:'permission-denied'});
});
