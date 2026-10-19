import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp, deleteField, collection, query, limit, where, getDocs} from 'firebase/firestore';
import {ref, uploadBytes, getMetadata} from 'firebase/storage';
import {beforeAll, beforeEach, afterAll, it, expect} from 'vitest';

let env: RulesTestEnvironment;
const db=(uid='member', authTime=200, verified=true)=>env.authenticatedContext(uid,{email_verified:verified,auth_time:authTime}).firestore();
const profilePath='orgs/o/profiles/member',goalPath=profilePath+'/goals/goal_1';
const baseProfile={schemaVersion:1,gender:'unspecified',age:25,heightCm:165,weightKg:65,experience:'beginner',activity:'lightlyActive',goals:['generalFitness'],updatedAt:Timestamp.fromMillis(1)};
const goal=(patch:Record<string,unknown>={})=>({schemaVersion:1,category:'trainingFrequency',targetValue:4,unit:'sessions',evaluationPeriod:'calendarWeek',status:'active',revision:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),...patch});
beforeAll(async()=>{
  const dir=process.env.MODULE1_RULES_DIR ?? '../firebase';
  if(!process.env.FIRESTORE_EMULATOR_HOST||!process.env.FIREBASE_STORAGE_EMULATOR_HOST)throw Error('Local emulators required');
  env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{rules:readFileSync(join(dir,'firestore.rules'),'utf8')},storage:{rules:readFileSync(join(dir,'storage.rules'),'utf8')}});
});
beforeEach(async()=>{
  await env.clearFirestore(); await env.clearStorage();
  await env.withSecurityRulesDisabled(async c=>{
    await setDoc(doc(c.firestore(),'orgs/o'),{status:'active'});
    for(const [uid,role]of [['member','member'],['other','member'],['admin','admin'],['coach','coach']]){
      await setDoc(doc(c.firestore(),`users/${uid}`),{organizationId:'o',displayName:'Original',contactDetails:'Preserved',updatedAtMillis:1});
      await setDoc(doc(c.firestore(),`orgs/o/members/${uid}`),{organizationId:'o',role,status:'active',displayName:'Original',branchIds:['main']});
    }
    await setDoc(doc(c.firestore(),profilePath),baseProfile);
    await setDoc(doc(c.firestore(),'orgs/o/preferences/member'),{schemaVersion:1,pushNotifications:true,emailUpdates:false,voiceCoaching:true,updatedAt:Timestamp.fromMillis(1)});
  });
});
afterAll(async()=>env?.cleanup());
async function pair(client:ReturnType<typeof db>,data:Record<string,unknown>,path=goalPath){
 const batch=writeBatch(client);batch.set(doc(client,path),data);batch.set(doc(client,`${path}/revisions/${data.revision}`),data);return batch.commit();
}
async function seedGoal(){await pair(db(),goal());return (await getDoc(doc(db(),goalPath))).data()!;}
async function lifecycle(state='pendingDeletion'){
 await env.withSecurityRulesDisabled(async c=>{
  await updateDoc(doc(c.firestore(),'users/member'),{accountLifecycle:{schemaVersion:1,state,sessionNotBeforeSeconds:150,revision:1,requestedAtMillis:149000,revocationPending:false,sessionRevokedAtMillis:149000,reactivatedAtMillis:state==='active'?200000:null}});
  await updateDoc(doc(c.firestore(),'orgs/o/members/member'),{status:state==='active'?'active':'pendingDeletion'});
 });
}

it('legacy profile edits preserve age and unknown historical creation; explicit bracket upgrade deletes exact age',async()=>{
 await assertSucceeds(updateDoc(doc(db(),profilePath),{experience:'advanced',updatedAt:serverTimestamp()}));
 expect((await getDoc(doc(db(),profilePath))).data()).toMatchObject({age:25,experience:'advanced'});
 await assertSucceeds(updateDoc(doc(db(),profilePath),{schemaVersion:2,age:deleteField(),ageBracket:'adult',updatedAt:serverTimestamp()}));
 const saved=(await getDoc(doc(db(),profilePath))).data()!;
 expect(saved.age).toBeUndefined();expect(saved.createdAt).toBeUndefined();expect(saved.ageBracket).toBe('adult');
 await assertFails(updateDoc(doc(db(),profilePath),{schemaVersion:1,age:25,ageBracket:deleteField(),updatedAt:serverTimestamp()}));
});
it('new profiles require trusted immutable completion metadata and reject invented legacy history',async()=>{
 const {age: _legacyAge,...fields}=baseProfile;
 const p={...fields,schemaVersion:2,ageBracket:'adult',updatedAt:serverTimestamp(),createdAt:serverTimestamp(),profileCompletedAt:serverTimestamp()};
 await assertSucceeds(setDoc(doc(db('other'),'orgs/o/profiles/other'),p));
 for(const patch of [{createdAt:serverTimestamp()},{profileCompletedAt:serverTimestamp()}])await assertFails(updateDoc(doc(db(),profilePath),{...patch,updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(db('other'),'orgs/o/profiles/other'),{createdAt:Timestamp.fromMillis(4),updatedAt:serverTimestamp()}));
});
it('profile schema rejects invalid measurements, bracket, enums, dual ages and injected privileged fields',async()=>{
 for(const patch of [{heightCm:0},{heightCm:165.5},{heightCm:211},{weightKg:34},{weightKg:Infinity},{weightKg:NaN},{weightKg:160.1},{age:12},{gender:'other'},{experience:'expert'},{activity:'unknown'},{goals:[]},{goals:['generalFitness','generalFitness']},{role:'admin'},{schemaVersion:2,ageBracket:'adult'},{schemaVersion:2,age:deleteField(),ageBracket:'invalid'}]){
  await assertFails(updateDoc(doc(db(),profilePath),{...patch,updatedAt:serverTimestamp()}));
 }
});
it('private profile and goal access rejects wrong owner, org, role, unverified and signed-out callers',async()=>{
 for(const client of [db('other'),db('admin'),db('coach'),db('member',200,false),env.unauthenticatedContext().firestore()]){
  await assertFails(getDoc(doc(client,profilePath)));await assertFails(pair(client,goal()));
 }
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'users/member'),{organizationId:'foreign'}));
 await assertFails(getDoc(doc(db(),profilePath)));await assertFails(pair(db(),goal()));
});
it('numeric goals create, update and archive with stable IDs and immutable matching revisions',async()=>{
 const original=await seedGoal();
 await assertSucceeds(pair(db(),{...original,targetValue:5,revision:2,updatedAt:serverTimestamp()}));
 const changed=(await getDoc(doc(db(),goalPath))).data()!;
 await assertSucceeds(pair(db(),{...changed,status:'archived',revision:3,updatedAt:serverTimestamp()}));
 expect((await getDoc(doc(db(),goalPath+'/revisions/1'))).data()!.targetValue).toBe(4);
 expect((await getDoc(doc(db(),goalPath+'/revisions/2'))).data()!.targetValue).toBe(5);
 await assertFails(pair(db(),{...changed,targetValue:6,revision:4,updatedAt:serverTimestamp()}));
 await assertFails(deleteDoc(doc(db(),goalPath)));
});
it('requires atomic history, sequential revision, immutable category/unit/period/creation and genuine change',async()=>{
 await assertFails(setDoc(doc(db(),goalPath),goal()));
 const original=await seedGoal();
 for(const patch of [{revision:3,targetValue:6},{revision:2,targetValue:4},{revision:2,targetValue:5,createdAt:serverTimestamp()},{revision:2,category:'repetitions',unit:'repetitions',evaluationPeriod:'perSession',targetValue:10}])await assertFails(pair(db(),{...original,...patch,updatedAt:serverTimestamp()}));
 await assertFails(setDoc(doc(db(),goalPath+'/revisions/2'),{...original,revision:2}));
 await assertFails(updateDoc(doc(db(),goalPath+'/revisions/1'),{targetValue:5}));
 await assertFails(deleteDoc(doc(db(),goalPath+'/revisions/1')));
});
it('goal category numeric units and periods reject unsupported or imprecise values',async()=>{
 for(const patch of [{targetValue:0},{targetValue:15},{targetValue:3.5},{unit:'kg'},{evaluationPeriod:'deviceWeek'},{status:'completed'},{targetValue:NaN},{category:'repetitions',unit:'repetitions',evaluationPeriod:'perSession',targetValue:1001},{category:'bodyWeight',unit:'kg',evaluationPeriod:'latestMeasurement',targetValue:65.55}])await assertFails(pair(db(),goal(patch)));
 await assertSucceeds(pair(db(),goal({category:'bodyWeight',unit:'kg',evaluationPeriod:'latestMeasurement',targetValue:65.1})));
});
it('goal and revision queries require explicit bounded pages',async()=>{
 await seedGoal();const client=db();
 await assertSucceeds(getDocs(query(collection(client,profilePath+'/goals'),where('status','==','active'),limit(21))));
 await assertFails(getDocs(collection(client,profilePath+'/goals')));
 await assertFails(getDocs(query(collection(client,profilePath+'/goals'),limit(22))));
 await assertSucceeds(getDocs(query(collection(client,goalPath+'/revisions'),limit(21))));
 await assertFails(getDocs(collection(client,goalPath+'/revisions')));
});
it('pending deletion denies private state and old tokens; fresh login can resolve recovery identity only',async()=>{
 await seedGoal();await lifecycle();
 for(const client of [db('member',100),db('member',200)]){
  await assertFails(getDoc(doc(client,profilePath)));await assertFails(getDoc(doc(client,goalPath)));
  await assertFails(getDoc(doc(client,'orgs/o/preferences/member')));
  await assertFails(updateDoc(doc(client,'users/member'),{contactDetails:'Denied',updatedAtMillis:2}));
  await assertFails(updateDoc(doc(client,'users/member'),{avatarPath:'legacy-bypass',updatedAtMillis:2}));
  await assertFails(updateDoc(doc(client,'orgs/o/members/member'),{goals:['bypass'],updatedAtMillis:2}));
 }
 await assertFails(getDoc(doc(db('member',100),'users/member')));
 await assertFails(getDoc(doc(db('member',100),'orgs/o/members/member')));
 await assertSucceeds(getDoc(doc(db(),'users/member')));await assertSucceeds(getDoc(doc(db(),'orgs/o/members/member')));
 await assertFails(setDoc(doc(db(),'orgs/o/memberLifecycleCommands/member/requests/fake'),{revision:1}));
 await assertFails(updateDoc(doc(db(),'users/member'),{accountLifecycle:{state:'active'}}));
});
it('reactivation never restores old-token Module 1 access; malformed lifecycle fails closed',async()=>{
 await lifecycle('active');
 await assertFails(getDoc(doc(db('member',100),profilePath)));await assertSucceeds(getDoc(doc(db(),profilePath)));
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'users/member'),{accountLifecycle:{state:'active'}}));
 await assertFails(getDoc(doc(db(),profilePath)));
 for(const patch of [{sessionNotBeforeSeconds:-1},{revocationPending:true}]){
  await lifecycle('active');
  await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'users/member'),Object.fromEntries(Object.entries(patch).map(([key,value])=>['accountLifecycle.'+key,value]))));
  await assertFails(getDoc(doc(db(),profilePath)));
 }
});
it('a restored fresh session can still save name, contact, preferences, photo reference and numeric goals',async()=>{
 await lifecycle('active');const client=db();
 const names=writeBatch(client);
 names.update(doc(client,'users/member'),{displayName:'Restored Member',updatedAtMillis:2});
 names.update(doc(client,'orgs/o/members/member'),{displayName:'Restored Member',updatedAtMillis:2});
 await assertSucceeds(names.commit());
 await assertSucceeds(updateDoc(doc(client,'users/member'),{contactDetails:'Confirmed contact',updatedAtMillis:3}));
 await assertSucceeds(updateDoc(doc(client,'users/member'),{memberPhotoPath:'',updatedAtMillis:4}));
 await assertSucceeds(updateDoc(doc(client,'orgs/o/preferences/member'),{emailUpdates:true,updatedAt:serverTimestamp()}));
 await assertSucceeds(pair(client,goal()));
});
it('Storage denies pending and stale sessions while retaining existing immutable Member objects',async()=>{
 const path='orgs/o/memberProfilePhotos/member/'+ 'a'.repeat(32),bucket='gs://demo-gainpath.appspot.com';
 const ctx=(time:number)=>env.authenticatedContext('member',{email_verified:true,auth_time:time});
 await assertSucceeds(uploadBytes(ref(ctx(200).storage(bucket),path),new Uint8Array([1,2,3]),{contentType:'image/png'}));
 await lifecycle();await assertFails(getMetadata(ref(ctx(200).storage(bucket),path)));
 await lifecycle('active');await assertFails(getMetadata(ref(ctx(100).storage(bucket),path)));
 await assertSucceeds(getMetadata(ref(ctx(200).storage(bucket),path)));
});
it('Storage accepts restored sessions with epoch-sized whole timestamps and rejects fractional lifecycle facts',async()=>{
 const path='orgs/o/memberProfilePhotos/member/'+ 'b'.repeat(32),bucket='gs://demo-gainpath.appspot.com';
 const restored={schemaVersion:1,state:'active',revision:2,requestedAtMillis:1792233899954,sessionNotBeforeSeconds:1792233900,revocationPending:false,sessionRevokedAtMillis:1792233899999,reactivatedAtMillis:1792237900000};
 const storage=env.authenticatedContext('member',{email_verified:true,auth_time:1792238000}).storage(bucket);
 await env.withSecurityRulesDisabled(async c=>{await uploadBytes(ref(c.storage(bucket),path),new Uint8Array([1]),{contentType:'image/png'});await updateDoc(doc(c.firestore(),'users/member'),{accountLifecycle:restored});});
 await assertSucceeds(getMetadata(ref(storage,path)));
 for(const field of ['revision','requestedAtMillis','sessionNotBeforeSeconds','sessionRevokedAtMillis','reactivatedAtMillis']){
  await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'users/member'),{accountLifecycle:{...restored,[field]:restored[field as keyof typeof restored] as number + 0.5}}));
  await assertFails(getMetadata(ref(storage,path)));
 }
});
it('missing identity remains readable for authenticated provisioning recovery; other identities remain private',async()=>{
 await assertSucceeds(getDoc(doc(db('new'),'users/new')));
 await assertFails(getDoc(doc(db('new'),'users/member')));
});
