import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,collection,getDoc,getDocs,setDoc,updateDoc,deleteDoc} from 'firebase/firestore';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
let env:RulesTestEnvironment;
const root='orgs/facility-org';
const client=(uid:string,verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
beforeAll(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Isolated emulator required');
  env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{rules:readFileSync(process.env.FACILITY_RULES_FILE||'../firebase/firestore.rules','utf8')}});
});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),root),{schemaVersion:1,organizationId:'facility-org',displayName:'Existing facility',status:'active',createdAtMillis:1,updatedAtMillis:1,timezone:'protected',maintenance:false});
  for(const [uid,role]of [['admin','admin'],['member','member'],['coach','coach'],['staff','staff']]){
    await setDoc(doc(c.firestore(),`users/${uid}`),{organizationId:'facility-org'});
    await setDoc(doc(c.firestore(),`${root}/members/${uid}`),{organizationId:'facility-org',role,status:'active',branchIds:['main']});
  }
});});
afterAll(async()=>{await env?.cleanup();});
it('Admin saves and reloads only facility name while existing policies remain identical',async()=>{
  const ref=doc(client('admin'),root);await assertSucceeds(updateDoc(ref,{displayName:'Renamed facility',updatedAtMillis:2}));
  expect((await assertSucceeds(getDoc(ref))).data()).toMatchObject({displayName:'Renamed facility',timezone:'protected',maintenance:false,status:'active',createdAtMillis:1});
});
it('other roles, unverified and anonymous users cannot read or update facility metadata',async()=>{
  for(const db of [client('member'),client('coach'),client('staff'),client('admin',false),env.unauthenticatedContext().firestore()]){
    await assertFails(getDoc(doc(db,root)));await assertFails(updateDoc(doc(db,root),{displayName:'Blocked',updatedAtMillis:2}));
  }
});
it('foreign organization and canonical membership drift revoke access',async()=>{
  const db=client('admin');await assertFails(getDoc(doc(db,'orgs/foreign')));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/admin'),{organizationId:'foreign'}));
  await assertFails(getDoc(doc(db,root)));
  await env.withSecurityRulesDisabled(async c=>{await updateDoc(doc(c.firestore(),'users/admin'),{organizationId:'facility-org'});await updateDoc(doc(c.firestore(),`${root}/members/admin`),{role:'coach'});});
  await assertFails(updateDoc(doc(db,root),{displayName:'Blocked',updatedAtMillis:2}));
});
it('denies operational and identity changes, invalid names, list/create/delete',async()=>{
  const db=client('admin'),ref=doc(db,root);
  for(const patch of [{timezone:'other'},{maintenance:true},{status:'inactive'},{organizationId:'foreign'},{createdAtMillis:2},{unknown:true},
    {displayName:' '},{displayName:'line\nbreak'},{displayName:'x'.repeat(121)},{updatedAtMillis:'invalid'}]){
    await assertFails(updateDoc(ref,{displayName:'Allowed name',updatedAtMillis:2,...patch}));
  }
  await assertFails(getDocs(collection(db,'orgs')));await assertFails(setDoc(doc(db,'orgs/new'),{displayName:'New'}));await assertFails(deleteDoc(ref));
});
