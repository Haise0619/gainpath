import {afterEach,expect,it,vi} from 'vitest';
import {Firestore} from 'firebase-admin/firestore';
import {createRecommendationCallableFacade,mintRecommendationEmulatorCapability,validateRecommendationEmulatorRequest,RECOMMENDATION_CALLABLE_OPERATIONS} from '../src/modules/recommendation/recommendation-callable-readiness';
afterEach(()=>vi.unstubAllEnvs());
const request={app:{appId:'explicit-trusted-unit'},auth:{uid:'admin',token:{email_verified:true,email:'admin@example.invalid',auth_time:10}},data:{schemaVersion:1,organizationId:'synthetic-org'}};
it('production default refuses every operation without touching a source or accepting request flags',async()=>{
 let calls=0;const facade=createRecommendationCallableFacade({handlers:Object.fromEntries(RECOMMENDATION_CALLABLE_OPERATIONS.map(k=>[k,async()=>{calls++;return{};}])) as any});
 for(const operation of RECOMMENDATION_CALLABLE_OPERATIONS)await expect(facade(operation,{...request,data:{...request.data,mode:'synthetic_local',fixtureSetId:'module13-c-v1',enabled:true}})).rejects.toMatchObject({code:'failed-precondition'});
 expect(calls).toBe(0);
});
it('rejects a production SDK even when the environment claims a demo project',()=>{
 vi.stubEnv('FIRESTORE_EMULATOR_HOST','127.0.0.1:18115');vi.stubEnv('GCLOUD_PROJECT','demo-gainpath-module13-e');vi.stubEnv('GOOGLE_CLOUD_PROJECT','demo-gainpath-module13-e');
 expect(()=>mintRecommendationEmulatorCapability(new Firestore({projectId:'production-project',servicePath:'127.0.0.1',port:18115,ssl:false}))).toThrow();
 expect(()=>mintRecommendationEmulatorCapability({projectId:'demo-gainpath-module13-e',_settings:{servicePath:'127.0.0.1',port:18115,ssl:false}} as any)).toThrow();
});
it('binds a nonserializable capability to the installed SDK endpoint and rechecks it on every call',async()=>{
 vi.stubEnv('FIRESTORE_EMULATOR_HOST','127.0.0.1:18115');vi.stubEnv('GCLOUD_PROJECT','demo-gainpath-module13-e');vi.stubEnv('GOOGLE_CLOUD_PROJECT','demo-gainpath-module13-e');
 const db=new Firestore({projectId:'demo-gainpath-module13-e',servicePath:'127.0.0.1',port:18115,ssl:false});const capability=mintRecommendationEmulatorCapability(db);let calls=0;
 const handlers={'admin.configuration.get':async()=>{calls++;return {schemaVersion:1};}} as any;
 expect(()=>validateRecommendationEmulatorRequest(capability,'admin.configuration.get',request)).not.toThrow();
 await expect(createRecommendationCallableFacade({handlers,capability:JSON.parse(JSON.stringify(capability))})('admin.configuration.get',request)).rejects.toMatchObject({code:'failed-precondition'});
 vi.stubEnv('FIRESTORE_EMULATOR_HOST','127.0.0.1:1');await expect(createRecommendationCallableFacade({handlers,capability})('admin.configuration.get',request)).rejects.toMatchObject({code:'failed-precondition'});expect(calls).toBe(0);
});
it('refuses oversized, unknown-mode, missing-attestation and wrong-scope payloads before handlers',async()=>{
 vi.stubEnv('FIRESTORE_EMULATOR_HOST','127.0.0.1:18115');vi.stubEnv('GCLOUD_PROJECT','demo-gainpath-module13-e');vi.stubEnv('GOOGLE_CLOUD_PROJECT','demo-gainpath-module13-e');
 const capability=mintRecommendationEmulatorCapability(new Firestore({projectId:'demo-gainpath-module13-e',servicePath:'127.0.0.1',port:18115,ssl:false}));let calls=0;
 const facade=createRecommendationCallableFacade({capability,handlers:{'admin.configuration.get':async()=>{calls++;return{};}} as any});
 for(const data of [{...request.data,mode:'synthetic_local'},{...request.data,organizationId:'foreign'},{...request.data,padding:'x'.repeat(17000)}])expect(()=>validateRecommendationEmulatorRequest(capability,'admin.configuration.get',{...request,data})).toThrow();
 expect(()=>validateRecommendationEmulatorRequest(capability,'admin.configuration.get',{...request,app:undefined})).toThrow();expect(calls).toBe(0);
});
it('never relays unexpected adapter failures or malformed output resource details',async()=>{
 vi.stubEnv('FIRESTORE_EMULATOR_HOST','127.0.0.1:18115');vi.stubEnv('GCLOUD_PROJECT','demo-gainpath-module13-e');vi.stubEnv('GOOGLE_CLOUD_PROJECT','demo-gainpath-module13-e');
 const capability=mintRecommendationEmulatorCapability(new Firestore({projectId:'demo-gainpath-module13-e',servicePath:'127.0.0.1',port:18115,ssl:false}));
 const facade=createRecommendationCallableFacade({capability,handlers:{'admin.configuration.get':async()=>{throw Error('secret resource path');}} as any});
 await expect(facade('admin.configuration.get',request)).rejects.toMatchObject({code:'failed-precondition'});
 await expect(facade('admin.configuration.get',request)).rejects.not.toThrow('secret resource');
});
it('cannot pair a real emulator capability with an unrelated production source handler',async()=>{
 vi.stubEnv('FIRESTORE_EMULATOR_HOST','127.0.0.1:18115');vi.stubEnv('GCLOUD_PROJECT','demo-gainpath-module13-e');vi.stubEnv('GOOGLE_CLOUD_PROJECT','demo-gainpath-module13-e');
 const capability=mintRecommendationEmulatorCapability(new Firestore({projectId:'demo-gainpath-module13-e',servicePath:'127.0.0.1',port:18115,ssl:false}));let productionReads=0;
 const facade=createRecommendationCallableFacade({capability,handlers:{'admin.configuration.get':async()=>{productionReads++;return{};}} as any});
 await expect(facade('admin.configuration.get',request)).rejects.toMatchObject({code:'failed-precondition'});expect(productionReads).toBe(0);
});
