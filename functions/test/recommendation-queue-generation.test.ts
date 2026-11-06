import {expect,it} from 'vitest';
import {createRecommendationQueueGeneration,type QueueGenerationItem} from '../src/modules/recommendation/recommendation-queue-generation';
import {queueSecurityFixture} from './recommendation-queue-fixture';
import {prepareSyntheticScenario,SYNTHETIC_RECOMMENDATION_SCENARIOS} from './recommendation-evaluation.fixture';
import {readRecommendationMemberState} from '../src/modules/recommendation/recommendation-queue-security';

async function fixture(){
  const f=await queueSecurityFixture(['exerciseInsights','recommendationGeneration','recommendationDelivery','externalAiInference']);
  const p=await prepareSyntheticScenario(SYNTHETIC_RECOMMENDATION_SCENARIOS.find(s=>s.id==='content_foundations')!);
  const item:QueueGenerationItem={id:'fictional-need',memberId:'member',need:{exercise:'squat',objective:'technique_foundations',level:'beginner'} as const,exerciseId:'fixture-squat',memberLabel:'Demo Member',exerciseLabel:'Squat',category:'Lower Body',evidenceStatus:'sufficient_synthetic'};
  const source={fixtureSetId:'module13-c-v1' as const,sourceVersion:'synthetic-v1',configVersion:'synthetic-config-v1',validityMillis:3600000,items:[item],inference:'mock_or_recorded_synthetic' as const,
    recommend:async()=>({recommendation:p,sourceFingerprint:'a'.repeat(64),targetLabels:{}}),validate:async()=>true};
  const deps={...f.deps,source};const invoke=createRecommendationQueueGeneration(deps);
  const request={...f.request,data:{schemaVersion:1,organizationId:'synthetic-org',kind:'content',commandId:'refresh',continuation:null}};
  return{...f,deps,invoke,request,item};
}
it('persists B-derived minimal leads and run provenance, and replays identical Refresh',async()=>{
  const f=await fixture();const a=await f.invoke(f.request);const b=await f.invoke(f.request);
  expect(a).toEqual(b);expect(a.summary).toMatchObject({status:'complete',processed:1,generated:1,abstained:0});
  const leads=[...f.store.documents].filter(([p])=>p.includes('/recommendationLeads/'));expect(leads).toHaveLength(1);
  expect(leads[0][1]).toMatchObject({mode:'synthetic_local',status:'pending',memberLabel:'Demo Member',ranking:{origin:'deterministic_fallback'}});
  expect(JSON.stringify(leads)).not.toMatch(/rawStructuredResponse|tutorialSteps|usageMetadata|payloadJson/);
});
it('deduplicates the same input across new Refresh commands including a dismissed record',async()=>{
  const f=await fixture();await f.invoke(f.request);const path=[...f.store.documents.keys()].find(p=>p.includes('/recommendationLeads/'))!;
  f.store.documents.get(path)!.status='dismissed';f.store.documents.get(path)!.decision={actorId:'admin',atMillis:200000,commandId:'dismiss',reason:'Already reviewed',recipientRecommendationId:null};
  const r=await f.invoke({...f.request,data:{...f.request.data,commandId:'refresh-again'}});expect(r.summary.generated).toBe(0);expect([...f.store.documents.keys()].filter(p=>p.includes('/recommendationLeads/'))).toHaveLength(1);
});
it('blocks revoked consent before B/source processing and returns explicit abstention',async()=>{
  const f=await fixture();let calls=0;f.deps.source.recommend=async()=>{calls++;throw Error('should not run');};
  const c=f.store.documents.get('orgs/synthetic-org/recommendationConsent/member')!; (c.purposes as any).recommendationGeneration.granted=false;
  const r=await f.invoke(f.request);expect(r.summary.abstained).toBe(1);expect(calls).toBe(0);
  expect(r.summary.abstentionReasons.missing_consent).toBe(1);
});
it('revalidates consent after engine work and commits no lead on drift',async()=>{
  const f=await fixture(),generate=f.deps.source.recommend;
  f.deps.source.recommend=async()=>{const r=await generate();f.store.documents.get('orgs/synthetic-org/members/member')!.status='inactive';return r;};
  await expect(f.invoke(f.request)).rejects.toThrow();expect([...f.store.documents.keys()].filter(p=>p.includes('/recommendationLeads/'))).toEqual([]);
});
it('fails a page without partial leads if a later source fails, and permits bounded continuation',async()=>{
  const f=await fixture();f.deps.source.items=[f.item,{...f.item,id:'fictional-need-2'},{...f.item,id:'fictional-need-3'}];
  const first=await f.invoke(f.request);expect(first.summary.status).toBe('in_progress');expect(first.summary.nextCursor).toBeTruthy();
  const last=await f.invoke({...f.request,data:{...f.request.data,continuation:first.summary.nextCursor}});expect(last.summary.status).toBe('complete');expect(last.summary.processed).toBe(3);
});
it('rejects unscoped manifests, unknown request fields and cross-run cursors',async()=>{
  const f=await fixture();await expect(f.invoke({...f.request,data:{...f.request.data,privateHistory:[]}})).rejects.toThrow();
  await expect(f.invoke({...f.request,data:{...f.request.data,continuation:'foreign:2'}})).rejects.toThrow();
  const member=await f.store.transact(tx=>readRecommendationMemberState(tx,{organizationId:'synthetic-org',memberId:'member'},200000,f.deps.noticePolicies!,['recommendationGeneration']));expect(member.eligible).toBe(true);
});
it('generates baseline without External AI permission and passes a default-off inference choice',async()=>{
  const f=await fixture();const original=f.deps.source.recommend;let choice:unknown;
  const c=f.store.documents.get('orgs/synthetic-org/recommendationConsent/member')!;(c.purposes as any).externalAiInference.granted=false;(c.purposes as any).externalAiInference.revokedAtMillis=200000;
  f.deps.source.recommend=async(_i?:any,_k?:any,allowInference?:boolean)=>{choice=allowInference;return original();};
  const r=await f.invoke(f.request);expect(r.summary.generated).toBe(1);expect(choice).toBe(false);
});
it('does not return private unexpected fields from corrupted page receipts',async()=>{
  const f=await fixture();await f.invoke(f.request);const page=[...f.store.documents.entries()].find(([p])=>p.includes('/pages/'))!;(page[1].response as any).rawHistory=['private'];
  await expect(f.invoke(f.request)).rejects.toThrow();
});
it('commits zero page leads when a later engine source fails',async()=>{
  const f=await fixture();f.deps.source.items=[f.item,{...f.item,id:'fictional-second'}];const original=f.deps.source.recommend;let calls=0;
  f.deps.source.recommend=async()=>{if(++calls===2)throw Error('SECRET source details');return original();};
  await expect(f.invoke(f.request)).rejects.toMatchObject({message:'Recommendation settings are temporarily unavailable.'});expect([...f.store.documents.keys()].some(p=>p.includes('/recommendationLeads/'))).toBe(false);
});
it('renews stale/revoked/expired records with a revision check while preserving sent/dismissed suppression',async()=>{
  for(const status of ['stale','revoked','expired','pending']){
    const f=await fixture();await f.invoke(f.request);const path=[...f.store.documents.keys()].find(p=>p.includes('/recommendationLeads/'))!,old=f.store.documents.get(path)!;
    Object.assign(old,{status,memberFingerprint:'c'.repeat(64),revision:2});
    const r=await f.invoke({...f.request,data:{...f.request.data,commandId:`renew-${status}`}});expect(r.summary.generated).toBe(1);expect(f.store.documents.get(path)).toMatchObject({status:'pending',revision:3,decision:null});
    expect([...f.store.documents.keys()].filter(p=>p.includes('/recommendationRefreshAudits/'))).toHaveLength(1);
  }
});
it('distinguishes insufficient and unsupported evidence without calling candidate sources',async()=>{
  const f=await fixture();f.deps.source.items=[{...f.item,evidenceStatus:'insufficient'},{...f.item,id:'fictional-unsupported',evidenceStatus:'unsupported'}];
  const r=await f.invoke(f.request);expect(r.summary.abstentionReasons).toEqual({insufficient_evidence:1,unsupported_evidence:1,missing_consent:0,no_eligible_candidates:0,semantic_abstention:0});
});
it('retains model provenance even when valid inference abstains',async()=>{
  const f=await fixture(),original=f.deps.source.recommend;
  f.deps.source.recommend=async()=>{const r=await original();r.recommendation.ranking={...r.recommendation.ranking,status:'abstained',origin:'abstained',final:[],provenance:{...r.recommendation.ranking.provenance,model:'synthetic-abstention-model',fallbackReason:'semantic_abstention'}};return r;};
  const r=await f.invoke(f.request);expect(r.summary.abstentionReasons.semantic_abstention).toBe(1);expect(r.summary.model).toBe('synthetic-abstention-model');
});
