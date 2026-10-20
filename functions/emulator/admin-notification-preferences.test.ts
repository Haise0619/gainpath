import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,deleteDoc} from 'firebase/firestore';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
let env:RulesTestEnvironment;
const choices={pushAlerts:true,emailAlerts:false,weeklyDigest:false};
const client=(uid:string,verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
beforeAll(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Isolated emulator required');
  env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{rules:readFileSync(process.env.ADMIN_PREFERENCES_RULES_FILE||'../firebase/firestore.rules','utf8')}});
});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{
  for(const [uid,role]of [['admin','admin'],['other','admin'],['member','member'],['coach','coach'],['staff','staff']]){
    await setDoc(doc(c.firestore(),`users/${uid}`),{organizationId:'o',displayName:'Existing name',avatarPath:'private-path',updatedAtMillis:1});
    await setDoc(doc(c.firestore(),`orgs/o/members/${uid}`),{organizationId:'o',role,status:'active'});
  }
});});
afterAll(async()=>{await env?.cleanup();});
it('verified Admin saves/reloads own choices and can turn all off, preserving other fields',async()=>{
  const ref=doc(client('admin'),'users/admin');
  await assertSucceeds(updateDoc(ref,{notificationPreferences:choices,updatedAtMillis:2}));
  expect((await getDoc(ref)).data()).toMatchObject({notificationPreferences:choices,displayName:'Existing name',avatarPath:'private-path',organizationId:'o'});
  const off={pushAlerts:false,emailAlerts:false,weeklyDigest:false};
  await assertSucceeds(updateDoc(ref,{notificationPreferences:off,updatedAtMillis:3}));
  expect((await getDoc(ref)).data()?.notificationPreferences).toEqual(off);
});
it('other roles, unverified, anonymous and another Admin cannot write choices',async()=>{
  for(const uid of ['member','coach','staff'])await assertFails(updateDoc(doc(client(uid),`users/${uid}`),{notificationPreferences:choices,updatedAtMillis:2}));
  for(const db of [client('admin',false),client('other'),env.unauthenticatedContext().firestore()])await assertFails(updateDoc(doc(db,'users/admin'),{notificationPreferences:choices,updatedAtMillis:2}));
  await assertFails(getDoc(doc(client('other'),'users/admin')));
});
it('inactive membership and organization drift revoke preference writes',async()=>{
  const ref=doc(client('admin'),'users/admin');
  for(const patch of [{status:'suspended'},{status:'active',organizationId:'foreign'}]){
    await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'orgs/o/members/admin'),patch));
    await assertFails(updateDoc(ref,{notificationPreferences:choices,updatedAtMillis:2}));
  }
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/admin'),{organizationId:'foreign'}));
  await assertFails(updateDoc(ref,{notificationPreferences:choices,updatedAtMillis:2}));
});
it('rejects malformed choices and unrelated changes, without opening create/delete',async()=>{
  const db=client('admin'),ref=doc(db,'users/admin');
  for(const notificationPreferences of [true,{}, {...choices,pushAlerts:'yes'}, {...choices,token:'forbidden'}])await assertFails(updateDoc(ref,{notificationPreferences,updatedAtMillis:2}));
  for(const patch of [{role:'admin'},{organizationId:'foreign'},{displayName:'Other'},{avatarPath:'Other'},{unknown:true},{updatedAtMillis:'bad'}])await assertFails(updateDoc(ref,{notificationPreferences:choices,updatedAtMillis:2,...patch}));
  await assertFails(setDoc(doc(db,'users/new'),{notificationPreferences:choices}));
  await assertFails(deleteDoc(ref));
});
