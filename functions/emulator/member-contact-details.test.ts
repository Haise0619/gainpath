import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,deleteDoc} from 'firebase/firestore';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
let env:RulesTestEnvironment;
const client=(uid='member',verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
const photo='orgs/o/memberProfilePhotos/member/0123456789abcdef0123456789abcdef';
beforeAll(async()=>{
 if(!process.env.FIRESTORE_EMULATOR_HOST||!process.env.MEMBER_CONTACT_RULES_FILE)throw Error('Exact candidate/local emulator required');
 env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{rules:readFileSync(process.env.MEMBER_CONTACT_RULES_FILE,'utf8')}});
});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{
 for(const [uid,role]of [['member','member'],['other','member'],['admin','admin'],['coach','coach'],['staff','staff']]){
  await setDoc(doc(c.firestore(),`users/${uid}`),{organizationId:'o',displayName:'Preserved',memberPhotoPath:uid==='member'?photo:'',notificationPreferences:{pushAlerts:false,emailAlerts:false,weeklyDigest:false},updatedAtMillis:1});
  await setDoc(doc(c.firestore(),`orgs/o/members/${uid}`),{organizationId:'o',role,status:'active'});
 }
});});
afterAll(async()=>env?.cleanup());
it('verified Member saves, reopens, replaces and clears only contact details',async()=>{
 const user=doc(client(),'users/member');
 for(const contactDetails of ['+60 12 345 6789','Alternative contact','']){
  await assertSucceeds(updateDoc(user,{contactDetails,updatedAtMillis:2}));
  expect((await getDoc(user)).data()).toMatchObject({contactDetails,displayName:'Preserved',memberPhotoPath:photo,organizationId:'o',notificationPreferences:{pushAlerts:false,emailAlerts:false,weeklyDigest:false}});
 }
});
it('foreign actors, other roles, unverified and anonymous cannot write Member contacts',async()=>{
 for(const db of [client('other'),client('admin'),client('coach'),client('staff'),client('member',false),env.unauthenticatedContext().firestore()]){
  await assertFails(updateDoc(doc(db,'users/member'),{contactDetails:'forbidden',updatedAtMillis:2}));
 }
 for(const uid of ['admin','coach','staff'])await assertFails(updateDoc(doc(client(uid),`users/${uid}`),{contactDetails:'forbidden',updatedAtMillis:2}));
 await assertFails(getDoc(doc(client('other'),'users/member')));
});
it('rejects invalid values, oversize and unrelated patches; permits the 200-character boundary',async()=>{
 const user=doc(client(),'users/member');
 for(const contactDetails of [null,{},true,'x'.repeat(201),'line\nbreak','bad\u0000value'])await assertFails(updateDoc(user,{contactDetails,updatedAtMillis:2}));
 await assertSucceeds(updateDoc(user,{contactDetails:'x'.repeat(200),updatedAtMillis:2}));
 for(const patch of [{organizationId:'other'},{role:'admin'},{displayName:'Changed'},{memberPhotoPath:''},{notificationPreferences:{emailAlerts:true}},{updatedAtMillis:'bad'}])await assertFails(updateDoc(user,{contactDetails:'valid',updatedAtMillis:2,...patch}));
 await assertFails(setDoc(doc(client(),'users/new'),{contactDetails:'new'}));await assertFails(deleteDoc(user));
});
it('inactive membership, wrong role and organization drift revoke contact writes',async()=>{
 for(const [document,patch]of [['users/member',{organizationId:'foreign'}],['orgs/o/members/member',{status:'suspended'}],['orgs/o/members/member',{organizationId:'foreign'}],['orgs/o/members/member',{role:'coach'}]]as const){
  await env.withSecurityRulesDisabled(async c=>{
   await updateDoc(doc(c.firestore(),'users/member'),{organizationId:'o'});
   await updateDoc(doc(c.firestore(),'orgs/o/members/member'),{organizationId:'o',status:'active',role:'member'});
   await updateDoc(doc(c.firestore(),document),patch);
  });
  await assertFails(updateDoc(doc(client(),'users/member'),{contactDetails:'new',updatedAtMillis:2}));
 }
});
