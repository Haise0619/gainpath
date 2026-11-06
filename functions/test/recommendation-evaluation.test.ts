import {expect,it} from 'vitest';
import {rankingQuality,evaluateRankingResult} from '../src/modules/recommendation/recommendation-evaluation';
import {prepareSyntheticScenario,SYNTHETIC_RECOMMENDATION_SCENARIOS} from './recommendation-evaluation.fixture';
import {rankRecommendationCandidates} from '../src/modules/recommendation/recommendation-engine';
it('computes known-answer precision and nDCG with actual k denominators',()=>{
  expect(rankingQuality(['a','b','c'],{a:3,b:0,c:1})).toMatchObject({precisionAt1:1,precisionAt3:2/3});
  expect(rankingQuality(['a','c','b'],{a:3,b:0,c:1}).nDcgAt3).toBe(1);
  expect(rankingQuality(['b','c','a'],{a:3,b:0,c:1}).nDcgAt3).toBeLessThan(1);
  expect(rankingQuality([],{})).toEqual({precisionAt1:null,precisionAt3:null,nDcgAt3:null});
  expect(rankingQuality(['a'],{a:3}).precisionAt3).toBeNull();
});
it('prepares reproducible same-set catalogs through real eligibility services',async()=>{
  for(const s of SYNTHETIC_RECOMMENDATION_SCENARIOS){
    const a=await prepareSyntheticScenario(s),b=await prepareSyntheticScenario(s);
    expect(a.candidates).toEqual(b.candidates);
    expect(a.candidates.every(c=>c.organizationId==='synthetic-org')).toBe(true);
    if(s.id==='no_candidates')expect(a.candidates).toHaveLength(0);
    if(s.id==='trainer_beginner')expect(a.candidates).toHaveLength(3);
    if(s.id==='content_foundations')expect(a.candidates).toHaveLength(3);
    const result=await rankRecommendationCandidates(s.need,a.candidates,{context:a.context});
    const metrics=evaluateRankingResult(result,a.labels);
    expect(metrics.candidateValidity).toBe(1);expect(metrics.inferenceMeasurement).toBe('not_measured');
  }
});
it('does not score unlabeled or ineligible candidates as relevant',()=>{
  expect(()=>rankingQuality(['invented'],{a:3})).toThrow();
  expect(()=>rankingQuality(['a','a'],{a:3})).toThrow();
});
