import {expect,it} from 'vitest';
import {deliveryFixture} from './recommendation-delivery.fixture';
import {createRecommendationReadServices} from '../src/modules/recommendation/recommendation-read-services';
it('reads current owned consent and default configuration without writing records',async()=>{
 const f=await deliveryFixture(), reads=createRecommendationReadServices(f.deps), before=f.store.documents.size;
 expect((await reads.consent({...f.memberRequest,data:{schemaVersion:2,organizationId:f.org}}))?.revision).toBe(3);
 expect(await reads.configuration({...f.request,data:{schemaVersion:1,organizationId:f.org}})).toMatchObject({revision:0,policies:[]});
 expect(f.store.documents.size).toBe(before);
});
it('denies wrong role, foreign organization, extra Member identity and missing App Check',async()=>{
 const f=await deliveryFixture(), reads=createRecommendationReadServices(f.deps);
 await expect(reads.configuration({...f.memberRequest,data:{schemaVersion:1,organizationId:f.org}})).rejects.toMatchObject({code:'permission-denied'});
 await expect(reads.consent({...f.memberRequest,data:{schemaVersion:2,organizationId:'foreign'}})).rejects.toMatchObject({code:'permission-denied'});
 await expect(reads.consent({...f.memberRequest,data:{schemaVersion:2,organizationId:f.org,memberId:'admin'}})).rejects.toMatchObject({code:'invalid-argument'});
 await expect(reads.consent({...f.memberRequest,app:undefined,data:{schemaVersion:2,organizationId:f.org}})).rejects.toMatchObject({code:'unauthenticated'});
});
it('returns server-confirmed missing consent and rejects corrupt or legacy consent rather than defaulting it off',async()=>{
 const f=await deliveryFixture(), reads=createRecommendationReadServices(f.deps),request={...f.memberRequest,data:{schemaVersion:2,organizationId:f.org}};
 f.store.documents.delete(`orgs/${f.org}/recommendationConsent/member`);expect(await reads.consent(request)).toBeNull();
 f.store.documents.set(`orgs/${f.org}/recommendationConsent/member`,{schemaVersion:1});await expect(reads.consent(request)).rejects.toMatchObject({code:'invalid-argument'});
});
it('loads one bounded Admin lead and refuses stale current sources',async()=>{
 const f=await deliveryFixture(),reads=createRecommendationReadServices({...f.deps,validateTarget:async()=> 'stale' as const});
 await expect(reads.lead({...f.request,data:{schemaVersion:1,organizationId:f.org,leadId:f.lead.leadId}})).rejects.toMatchObject({code:'failed-precondition'});
});
it('does not expose raw run bookkeeping and refuses malformed refresh summaries',async()=>{
 const f=await deliveryFixture(),reads=createRecommendationReadServices(f.deps);
 f.store.documents.set(`orgs/${f.org}/recommendationRuns/bad`,{schemaVersion:1,actorId:'admin',inputFingerprint:'private',summary:{runId:'bad'}});
 await expect(reads.status({...f.request,data:{schemaVersion:1,organizationId:f.org,runId:'bad'}})).rejects.toMatchObject({code:'failed-precondition'});
});
it('rechecks time after fresh identity work instead of returning a newly expired lead',async()=>{
 const f=await deliveryFixture();let now=200000;const original=f.deps.readAuthIdentity;
 const reads=createRecommendationReadServices({...f.deps,clock:()=>now,readAuthIdentity:async uid=>{if(uid==='member')now=500000;return original(uid);}});
 await expect(reads.lead({...f.request,data:{schemaVersion:1,organizationId:f.org,leadId:f.lead.leadId}})).rejects.toMatchObject({code:'failed-precondition'});
});
