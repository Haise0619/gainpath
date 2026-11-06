import {expect,it} from 'vitest';
import {HELD_OUT_SCENARIOS,prepareHeldOutScenario} from './recommendation-independent-evaluation.fixture';
import {SYNTHETIC_RECOMMENDATION_SCENARIOS} from './recommendation-evaluation.fixture';
it('holds new unlabeled scenarios out of B development scenarios and runs actual source eligibility',async()=>{
  expect(HELD_OUT_SCENARIOS).toHaveLength(22);
  expect(HELD_OUT_SCENARIOS.some(s=>SYNTHETIC_RECOMMENDATION_SCENARIOS.some(b=>b.id===s.id))).toBe(false);
  const counts:Record<string,number>={};
  for(const s of HELD_OUT_SCENARIOS){
    const a=await prepareHeldOutScenario(s),b=await prepareHeldOutScenario(s);
    expect(a).toEqual(b);expect(Object.hasOwn(a,'labels')).toBe(false);
    expect(a.candidates).toHaveLength(s.control==='empty'?0:s.control==='single'?1:3);
    expect(a.candidates.every(c=>c.organizationId==='synthetic-org')).toBe(true);
    expect(a.ranking.provenance.validationStatus).toBe('not_called');
    counts[s.kind]=(counts[s.kind]??0)+1;
  }
  expect(counts).toEqual({trainer:11,content:11});
});
