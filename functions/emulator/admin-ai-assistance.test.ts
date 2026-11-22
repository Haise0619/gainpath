import {beforeAll,afterAll,describe,it,expect} from 'vitest';
import {mkdirSync,writeFileSync} from 'node:fs';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {assistanceFixture,admin} from '../test/support/admin-ai-fixture';
import {createAdminAiService,firestoreAdminAiReader} from '../src/modules/recommendation/admin-ai-service';
import {createCanonicalRecommendationAdmin} from '../src/modules/recommendation/canonical-recommendation-admin';
import {createCanonicalRecommendationLifecycle} from '../src/modules/recommendation/canonical-recommendation-lifecycle';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {module9MemberCommand} from '../src/modules/coaching/module9-member-service';
import {createCanonicalNoticeProjector} from '../src/modules/recommendation/canonical-notice-projection';

const project='demo-gainpath-admin-ai';
if(process.env.GCLOUD_PROJECT!==project||!process.env.FIRESTORE_EMULATOR_HOST?.startsWith('127.0.0.1:')||!process.env.FIREBASE_AUTH_EMULATOR_HOST?.startsWith('127.0.0.1:'))throw new Error('Dedicated Auth and Firestore emulators required.');
const app=initializeApp({projectId:project},'admin-ai-test'),db=getFirestore(app),auth=getAuth(app),f=assistanceFixture();
const deps={...f.deps,store:new FirestoreStore(db),aiReader:firestoreAdminAiReader(db),readAuthIdentity:async(uid:string)=>{const u=await auth.getUser(uid);return{uid,email:u.email!,emailVerified:u.emailVerified,disabled:u.disabled,tokensValidAfterMillis:0};}};
beforeAll(async()=>{
  await auth.createUser({uid:'admin',email:'admin@example.com',emailVerified:true});await auth.createUser({uid:'learner',email:'learner@example.com',emailVerified:true});
  const batch=db.batch();for(const [path,data]of f.d)batch.set(db.doc(path),data);await batch.commit();
  const cooldowns=db.batch();for(const s of f.suggestions)cooldowns.set(db.doc('orgs/gainpath/canonicalRecommendationFatigue/'+digestOf({member:'learner',need:s.needKey})),{untilMillis:f.deps.clock!()+7*86400000,marker:'automatic-only'});await cooldowns.commit();
});
afterAll(async()=>{await deleteApp(app);});
describe('Admin AI assistance on actual emulator transactions',()=>{
  let preview:any;
  it('loads the real completed-summary ranking via the authenticated Admin command',async()=>{
    const handler=createCanonicalRecommendationAdmin(deps);
    const result=await handler({auth:admin,app:{appId:'emulator'},data:{schemaVersion:1,operation:'admin.ai.members',data:{schemaVersion:1,organizationId:'gainpath',days:30}}}) as any;
    expect(result.members).toHaveLength(1);expect(result.members[0].workouts).toBe(1);
    await expect(handler({auth:{...admin,uid:'learner'},app:{appId:'emulator'},data:{schemaVersion:1,operation:'admin.ai.members',data:{schemaVersion:1,organizationId:'gainpath',days:30}}})).rejects.toThrow();
  });
  it('stores a preview without prematurely creating recommendations',async()=>{
    preview=await createAdminAiService(deps).execute(admin,'gainpath','admin.ai.outreach.generate',{schemaVersion:1,organizationId:'gainpath',memberId:'learner',days:30,requestId:'emulator-preview'});
    expect(preview.recommendations).toHaveLength(3);expect((await db.collection('orgs/gainpath/canonicalRecommendations').get()).empty).toBe(true);
  });
  it('searches a dedicated TEST identity outside Top 10 without generation',async()=>{
    const uid='m13-e2e-search';await auth.createUser({uid,email:'search@example.test',emailVerified:true});
    const b=db.batch();
    b.set(db.doc('users/'+uid),{...f.d.get('users/learner'),email:'search@example.test'});
    b.set(db.doc('orgs/gainpath/members/'+uid),{...f.d.get('orgs/gainpath/members/learner'),userId:uid,displayName:'Module 13 TEST Search',isTest:true});
    b.set(db.doc('orgs/gainpath/recommendationConsent/'+uid),{...f.d.get('orgs/gainpath/recommendationConsent/learner'),memberId:uid});await b.commit();
    const handler=createCanonicalRecommendationAdmin(deps);
    const result=await handler({auth:admin,app:{appId:'emulator'},data:{schemaVersion:1,operation:'admin.ai.member.search',data:{schemaVersion:1,organizationId:'gainpath',query:'TEST Search'}}}) as any;
    expect(result.members).toEqual([expect.objectContaining({memberId:uid,isTest:true,canAnalyze:true})]);
    expect((await createAdminAiService(deps).execute(admin,'gainpath','admin.ai.members',{schemaVersion:1,organizationId:'gainpath',days:30}) as any).members.some((m:any)=>m.memberId===uid)).toBe(false);
  });
  it('persists a valid single-item preview when other independent output is invalid',async()=>{
    const previous=deps.aiProvider;
    try{
      deps.aiProvider=async()=>({providerSource:'mock_or_recorded',cacheHit:false,model:'fixture',latencyMillis:1,usage:{inputTokens:1,outputTokens:1,thinkingTokens:0,totalTokens:2},text:JSON.stringify({recommendations:[{candidateId:'C1',message:'Review your recent practice.'},{candidateId:'invalid',message:'Unknown target.'},{candidateId:'C2'}]})});
      const result=await createAdminAiService(deps).execute(admin,'gainpath','admin.ai.outreach.generate',{schemaVersion:1,organizationId:'gainpath',memberId:'learner',days:30,requestId:'emulator-partial'}) as any;
      expect(result.recommendations).toHaveLength(1);
      expect((await db.doc('orgs/gainpath/adminAiPreviews/'+result.previewId).get()).get('suggestions')).toHaveLength(1);
      expect((await db.collection('orgs/gainpath/notifications').get()).empty).toBe(true);
    }finally{deps.aiProvider=previous;}
  });
  it('Send and exact retry create three canonical records, Inbox notifications and receipts',async()=>{
    const service=createAdminAiService(deps),q={schemaVersion:1,organizationId:'gainpath',previewId:preview.previewId,selections:[0,1,2].map(index=>({index,message:'Review this beginner guidance.'}))};
    const result=await service.execute(admin,'gainpath','admin.ai.outreach.send',q) as any;
    expect(await service.execute(admin,'gainpath','admin.ai.outreach.send',q)).toEqual(result);
    for(const collection of ['canonicalRecommendations','notifications','canonicalRecommendationDeliveries'])expect((await db.collection('orgs/gainpath/'+collection).get()).size).toBe(3);
    const lifecycle=createCanonicalRecommendationLifecycle(deps);
    const records=[];
    for(const id of result.ids){
      const resolved=await lifecycle.member({uid:'learner',token:{email_verified:true}},'gainpath',id,'resolve',null,null),saved=await lifecycle.adminDetail(admin,'gainpath',id);
      expect(resolved).toMatchObject({state:'available',aiMethod:'gemini'});expect(saved).toMatchObject({suggestion:{source:{kind:'admin_outreach'}}});
      records.push({id,saved,resolved,receipt:(await db.doc('orgs/gainpath/canonicalRecommendationDeliveries/'+id).get()).data()});
    }
    const notifications=(await db.collection('orgs/gainpath/notifications').get()).docs.map(d=>({id:d.id,...d.data()}));
    mkdirSync('../build/module13-admin-ai',{recursive:true});writeFileSync('../build/module13-admin-ai/emulator-delivered.json',JSON.stringify({source:'local_emulator_with_fixture_inference',records,notifications},null,2));
  });
  it('existing Notification Center reads the delivered Outreach through the canonical projector',async()=>{
    const member={uid:'learner',token:{email_verified:true,email:'learner@example.com',auth_time:Math.floor(Date.now()/1000)}};
    const projectRecommendation=await createCanonicalNoticeProjector(deps,{auth:member,app:{appId:'emulator'},data:{schemaVersion:1,organizationId:'gainpath'}});
    const page=await module9MemberCommand(deps.store,member,{schemaVersion:1,organizationId:'gainpath',action:'inbox',includeRoutine:true},f.deps.clock,{projectRecommendation,list:async()=> (await db.collection('orgs/gainpath/notifications').where('recipientId','==','learner').get()).docs.map(d=>({id:d.id,data:d.data()}))}) as any;
    expect(page.records).toHaveLength(3);expect(page.records.every((r:any)=>r.recommendation.state==='available')).toBe(true);
  });
  it('revoked consent blocks another generation without any new records',async()=>{
    await db.doc('orgs/gainpath/recommendationConsent/learner').update({'purposes.externalAiInference.granted':false});
    await expect(createAdminAiService(deps).execute(admin,'gainpath','admin.ai.outreach.generate',{schemaVersion:1,organizationId:'gainpath',memberId:'learner',days:30,requestId:'revoked-preview'})).rejects.toThrow();
    expect((await db.collection('orgs/gainpath/notifications').get()).size).toBe(3);
  });
  it('manual delivery left every existing automatic cooldown unchanged',async()=>{
    for(const s of f.suggestions){const cooldown=await db.doc('orgs/gainpath/canonicalRecommendationFatigue/'+digestOf({member:'learner',need:s.needKey})).get();expect(cooldown.data()).toEqual({untilMillis:f.deps.clock!()+7*86400000,marker:'automatic-only'});}
  });
});
