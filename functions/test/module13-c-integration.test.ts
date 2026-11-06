import {expect,it} from 'vitest';
import {MemoryStore} from './memory-store';
import {createModule13CFixture,module13CFixtureDocuments} from './module13-c-integration.fixture';

it('uses persisted real-shaped sources and B eligibility; source fingerprints ignore ranking order and run identity',async()=>{
  const store=new MemoryStore();for(const [p,d] of Object.entries(module13CFixtureDocuments()))store.documents.set(p,d);
  const fixture=await createModule13CFixture({store});
  for(const kind of ['trainer','content'] as const){
    const item=fixture.source.items[0],engine=await fixture.source.recommend(item,kind,true);
    expect(engine.recommendation.ranking.final.length).toBeGreaterThan(0);
    expect(await store.transact(tx=>fixture.source.validate(tx,item,kind,engine.sourceFingerprint))).toBe(true);
    expect((await fixture.source.recommend(item,kind,false)).sourceFingerprint).toBe(engine.sourceFingerprint);
  }
  const previous=await fixture.source.recommend(fixture.source.items[0],'content',true);
  store.documents.get('orgs/synthetic-org/content/fictional-routine-a')!.status='draft';
  expect(await store.transact(tx=>fixture.source.validate(tx,fixture.source.items[0],'content',previous.sourceFingerprint))).toBe(false);
  const engine=await fixture.source.recommend(fixture.source.items[0],'content',true);
  expect(engine.recommendation.eligibility?.candidates).toHaveLength(1);
});
