import {expect,it} from 'vitest';
import {parseRecommendationLead} from '../src/modules/recommendation/recommendation-queue-contracts';
it('rejects legacy/private/unknown lead fields and unversioned data',()=>{
  for(const raw of [{},{schemaVersion:1,rawHistory:[]},{schemaVersion:2}])expect(()=>parseRecommendationLead(raw,'synthetic-org')).toThrow();
});
