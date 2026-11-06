import {expect,it} from 'vitest';
import {MemoryStore} from './memory-store';
import {module13CFixtureDocuments,createModule13CFixture,MODULE13_C_NOW} from './module13-c-integration.fixture';
import {createRecommendationQueueGeneration} from '../src/modules/recommendation/recommendation-queue-generation';
import {createCurrentRecommendationTargetResolver} from '../src/modules/recommendation/recommendation-target-resolver';
import type {RecommendationLead} from '../src/modules/recommendation/recommendation-queue-contracts';
async function fixture(kind:'trainer'|'content'){
  const store=new MemoryStore();Object.entries(module13CFixtureDocuments()).forEach(([p,d])=>store.documents.set(p,d));
  const f=await createModule13CFixture({store,clock:()=>MODULE13_C_NOW});
  await createRecommendationQueueGeneration({...f.deps,source:f.source})({...f.request,data:{...f.request.data,kind,commandId:'generate',continuation:null}});
  const lead=[...store.documents].find(([p,d])=>p.includes('/recommendationLeads/')&&d.kind===kind)![1] as unknown as RecommendationLead;
  return{store,f,lead,resolve:createCurrentRecommendationTargetResolver({revalidateEligibility:f.validateTarget})};
}
it('resolves current verified fixture Coach metadata without fabricating media',async()=>{
  const f=await fixture('trainer'),current=await f.store.transact(tx=>f.resolve(tx,f.lead));
  expect(current).toMatchObject({label:'Fictional Coach Amira',specialization:'Squat foundations',imageUrl:null,photoPath:null});expect(current!.target).toEqual(f.lead.target);
  f.store.documents.get('orgs/synthetic-org/coaches/fictional-coach')!.status='inactive';
  expect(await f.store.transact(tx=>f.resolve(tx,f.lead))).toBeNull();
});
it('resolves the exact current instructional tutorial and rejects changed or withdrawn targets',async()=>{
  const f=await fixture('content'),target=await f.store.transact(tx=>f.resolve(tx,f.lead));expect(target!.target).toEqual(f.lead.target);expect(target!.label).toContain('Fictional squat tutorial');expect(target!.imageUrl).toBeNull();
  const id=f.lead.target.kind==='content'?f.lead.target.destination.routineId:'';
  f.store.documents.get(`orgs/synthetic-org/content/${id}`)!.status='draft';expect(await f.store.transact(tx=>f.resolve(tx,f.lead))).toBeNull();
});
it('does not swallow source failures or resolve foreign organization targets',async()=>{
  const f=await fixture('content');await expect(f.store.transact(tx=>f.resolve(tx,{...f.lead,organizationId:'foreign'}))).rejects.toThrow();
  const resolve=createCurrentRecommendationTargetResolver({revalidateEligibility:async()=>{throw Error('private source error');}});
  await expect(f.store.transact(tx=>resolve(tx,f.lead))).rejects.toThrow('private source error');
});
