import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,writeBatch} from 'firebase/firestore';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
let env:RulesTestEnvironment;
const client=(uid='member',verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
const photo='orgs/o/memberProfilePhotos/member/0123456789abcdef0123456789abcdef';
beforeAll(async()=>{
 if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Local emulator required');
 env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{rules:readFileSync(process.env.MEMBER_NAME_RULES_FILE ?? '../firebase/firestore.rules','utf8')}});
});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{
 for(const [uid,role]of [['member','member'],['other','member'],['admin','admin'],['coach','coach']]){
  await setDoc(doc(c.firestore(),`users/${uid}`),{organizationId:'o',displayName:'Original',contactDetails:'Preserved contact',memberPhotoPath:uid==='member'?photo:'',notificationPreferences:{pushAlerts:false,emailAlerts:false,weeklyDigest:false},updatedAtMillis:1});
  await setDoc(doc(c.firestore(),`orgs/o/members/${uid}`),{organizationId:'o',role,status:'active',displayName:'Original',goals:['strength'],updatedAtMillis:1});
 }
});});
afterAll(async()=>env?.cleanup());
function pair(db:ReturnType<typeof client>,name:unknown,userPatch:Record<string,unknown>={},memberPatch:Record<string,unknown>={}){
 const batch=writeBatch(db);batch.update(doc(db,'users/member'),{displayName:name,updatedAtMillis:2,...userPatch});batch.update(doc(db,'orgs/o/members/member'),{displayName:name,updatedAtMillis:2,...memberPatch});return batch.commit();
}
it('Member saves/reopens both identity names while preserving contacts, photo, choices and goals',async()=>{
 const db=client();
 for(const name of ['New Member','Replacement Name','x'.repeat(120)]){
  await assertSucceeds(pair(db,name));
  expect((await getDoc(doc(db,'users/member'))).data()).toMatchObject({displayName:name,contactDetails:'Preserved contact',memberPhotoPath:photo,notificationPreferences:{pushAlerts:false,emailAlerts:false,weeklyDigest:false}});
  expect((await getDoc(doc(db,'orgs/o/members/member'))).data()).toMatchObject({displayName:name,goals:['strength'],role:'member',status:'active'});
 }
});
it('rejects blank, whitespace, control characters, nonstrings and names longer than 120',async()=>{
 for(const name of ['', '   ','line\nbreak','bad\u0000value',true,{},'x'.repeat(121)])await assertFails(pair(client(),name));
});
it('denies half updates, mismatched names/timestamps and unrelated edits in a name transaction',async()=>{
 const db=client();
 await assertFails(updateDoc(doc(db,'users/member'),{displayName:'Half user',updatedAtMillis:2}));
 await assertFails(updateDoc(doc(db,'orgs/o/members/member'),{displayName:'Half member',updatedAtMillis:2}));
 await assertFails(pair(db,'New',{}, {displayName:'Different'}));await assertFails(pair(db,'New',{}, {updatedAtMillis:3}));
 for(const [userPatch,memberPatch]of [[{contactDetails:'Changed'},{}],[{memberPhotoPath:''},{}],[{}, {goals:['changed']}],[{organizationId:'other'},{}]] as const)await assertFails(pair(db,'New',userPatch,memberPatch));
});
it('foreign actors, unverified, inactive and canonical-org drift cannot change Member names',async()=>{
 for(const db of [client('other'),client('admin'),client('coach'),client('member',false),env.unauthenticatedContext().firestore()])await assertFails(pair(db,'Denied'));
 for(const [document,patch]of [['users/member',{organizationId:'foreign'}],['orgs/o/members/member',{status:'suspended'}],['orgs/o/members/member',{organizationId:'foreign'}]]as const){
  await env.withSecurityRulesDisabled(async c=>{
   await updateDoc(doc(c.firestore(),'users/member'),{organizationId:'o'});await updateDoc(doc(c.firestore(),'orgs/o/members/member'),{organizationId:'o',status:'active'});
   await updateDoc(doc(c.firestore(),document),patch);
  });await assertFails(pair(client(),'Denied'));
 }
});
it('preserves existing non-name Member writes and Admin/Coach own-name permissions',async()=>{
 const db=client();
 await assertSucceeds(updateDoc(doc(db,'users/member'),{contactDetails:'New contact',updatedAtMillis:2}));
 await assertSucceeds(updateDoc(doc(db,'users/member'),{memberPhotoPath:'',updatedAtMillis:3}));
 await assertSucceeds(updateDoc(doc(db,'orgs/o/members/member'),{goals:['generalFitness'],updatedAtMillis:4}));
 for(const uid of ['admin','coach'])await assertSucceeds(updateDoc(doc(client(uid),`users/${uid}`),{displayName:'Existing role contract',updatedAtMillis:2}));
 await assertSucceeds(updateDoc(doc(client('admin'),'users/admin'),{notificationPreferences:{pushAlerts:true,emailAlerts:false,weeklyDigest:false},updatedAtMillis:3}));
});
