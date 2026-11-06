import {expect,it,vi} from 'vitest';
import {Firestore} from 'firebase-admin/firestore';
import {parseFypEnvelope,createFypDatasetBackend,assertFypAdminReadOperation} from '../src/modules/dataset/fyp-backend';
import {createModule13DemoDataAdapters} from '../src/modules/recommendation/demo-firestore-adapters';
it('accepts bounded business commands but never request-selected scope, roles or providers',()=>{
 expect(parseFypEnvelope({schemaVersion:1,operation:'member.history',data:{schemaVersion:1,organizationId:'gainpath'}}).operation).toBe('member.history');
 for(const value of [{schemaVersion:1,operation:'member.history',datasetId:'fyp-v1',data:{}},{schemaVersion:1,operation:'module/bookingPaymentCommand',data:{}},{schemaVersion:1,operation:'admin.queue.refresh',data:{demoMode:true}},{schemaVersion:1,operation:'admin.queue.refresh',data:{cohortId:'other'}},{schemaVersion:1,operation:'admin.queue.refresh',data:{role:'admin'}},{schemaVersion:1,operation:'admin.queue.refresh',data:{padding:'x'.repeat(17000)}}])expect(()=>parseFypEnvelope(value)).toThrow();
});
it('has no real-project or default SDK fallback',()=>{expect(()=>createFypDatasetBackend({db:{} as never,auth:{} as never})).toThrow('emulator');});
it('canonical Admin bridge allows existing reads only and cannot generate, Send, grant consent or write configuration',()=>{
 for(const op of ['admin.insights','admin.queue.list','admin.queue.detail','admin.queue.status','module/adminWorkoutReportingCommand'])expect(()=>assertFypAdminReadOperation(op)).not.toThrow();
 for(const op of ['admin.queue.refresh','admin.queue.decide','admin.configuration.save','member.consent.set','delivery.process','member.recommendation.command','module/bookingPaymentCommand','member.history'])expect(()=>assertFypAdminReadOperation(op)).toThrow();
});
it('refuses a scoped adapter without an authorized synthetic reader before any source/query access',async()=>{
 await expect(createModule13DemoDataAdapters({db:{} as never,queryRoot:'orgs/gainpath/cohorts/fyp-v1',manifest:{} as never,store:{transact:async()=>{throw Error('unexpected source read');}},deps:{} as never,readAuthIdentity:async()=>{throw Error('unexpected Auth read');},clock:Date.now})).rejects.toMatchObject({code:'failed-precondition'});
});
it('rejects an old token when the current Auth identity has lost its server binding claim, before data reads',async()=>{
 vi.stubEnv('GCLOUD_PROJECT','demo-gainpath-fyp');vi.stubEnv('GOOGLE_CLOUD_PROJECT','demo-gainpath-fyp');vi.stubEnv('FIRESTORE_EMULATOR_HOST','127.0.0.1:18231');vi.stubEnv('FIREBASE_AUTH_EMULATOR_HOST','127.0.0.1:19131');
 const db=new Firestore({projectId:'demo-gainpath-fyp',host:'127.0.0.1:18231',ssl:false}),read=vi.spyOn(db,'runTransaction').mockRejectedValue(Error('No data access allowed'));
 try{const backend=createFypDatasetBackend({db,auth:{getUser:async()=>({uid:'fictional',email:'fictional@example.invalid',emailVerified:true,disabled:false,metadata:{creationTime:new Date(1000).toUTCString()},customClaims:{}} as never)}});
 await expect(backend.session({app:{appId:'test'},auth:{uid:'fictional',token:{email:'fictional@example.invalid',email_verified:true,auth_time:100,fypAuthCreatedAtMillis:1000}},data:{schemaVersion:1}})).rejects.toMatchObject({code:'permission-denied'});expect(read).not.toHaveBeenCalled();
 }finally{vi.unstubAllEnvs();await db.terminate();}
});
