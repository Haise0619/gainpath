import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,collection,getDoc,getDocs,setDoc,updateDoc,deleteDoc,serverTimestamp,query,orderBy,documentId,limit} from 'firebase/firestore';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
let env:RulesTestEnvironment;
const root='orgs/reward-org',path=`${root}/rewardCatalog/draft`;
const client=(uid:string,verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
const fields=()=>({schemaVersion:1,title:'Draft towel',description:'Draft metadata',category:'Merchandise',imageUrl:'',
  status:'draft',revision:1,createdAt:serverTimestamp(),createdBy:'admin',updatedAt:serverTimestamp(),updatedBy:'admin'});
beforeAll(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Isolated emulator required');
  env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{rules:readFileSync(process.env.REWARD_RULES_FILE||'../firebase/firestore.rules','utf8')}});
});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{
  for(const [uid,role]of [['admin','admin'],['member','member'],['coach','coach'],['staff','staff']]){
    await setDoc(doc(c.firestore(),`users/${uid}`),{organizationId:'reward-org'});
    await setDoc(doc(c.firestore(),`${root}/members/${uid}`),{organizationId:'reward-org',role,status:'active',branchIds:['main']});
  }
});});
afterAll(async()=>{await env?.cleanup();});
it('Admin creates, edits, archives and reloads metadata via existing cursor query',async()=>{
  const db=client('admin'),ref=doc(db,path);await assertSucceeds(setDoc(ref,fields()));
  await assertSucceeds(updateDoc(ref,{description:'Edited draft',revision:2,updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref,{status:'archived',revision:3,updatedAt:serverTimestamp()}));
  const page=await assertSucceeds(getDocs(query(collection(db,`${root}/rewardCatalog`),orderBy(documentId()),limit(25))));
  expect(page.docs[0].data()).toMatchObject({status:'archived',revision:3,description:'Edited draft'});
});
it('Member, Coach, Staff, anonymous and unverified users cannot read or author metadata',async()=>{
  await setDoc(doc(client('admin'),path),fields());
  for(const db of [client('member'),client('coach'),client('staff'),client('admin',false),env.unauthenticatedContext().firestore()]){
    await assertFails(getDoc(doc(db,path)));await assertFails(getDocs(collection(db,`${root}/rewardCatalog`)));
    await assertFails(setDoc(doc(db,`${root}/rewardCatalog/other`),fields()));
  }
});
it('canonical organization/status changes revoke access and other organizations are denied',async()=>{
  const db=client('admin');await setDoc(doc(db,path),fields());
  await assertFails(setDoc(doc(db,'orgs/foreign/rewardCatalog/draft'),fields()));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/admin'),{organizationId:'foreign'}));
  await assertFails(getDoc(doc(db,path)));
  await env.withSecurityRulesDisabled(async c=>{await updateDoc(doc(c.firestore(),'users/admin'),{organizationId:'reward-org'});await updateDoc(doc(c.firestore(),`${root}/members/admin`),{status:'suspended'});});
  await assertFails(updateDoc(doc(db,path),{revision:2,updatedAt:serverTimestamp()}));
});
it('rejects publication, points, stock, redemption, invalid fields, immutable changes and stale revisions',async()=>{
  const db=client('admin'),ref=doc(db,path);await setDoc(ref,fields());
  for(const patch of [{status:'published'},{points:100},{stock:10},{redemptionLimitPerMember:1},{title:' '},{title:'x'.repeat(121)},{description:'x'.repeat(2001)},{category:'Unknown'},{imageUrl:'http://example.test/a.png'},{createdBy:'other'},{updatedBy:'other'},{createdAt:serverTimestamp()},{revision:1}]){
    await assertFails(updateDoc(ref,{revision:2,updatedAt:serverTimestamp(),...patch}));
  }
  await assertFails(deleteDoc(ref));
  await assertFails(setDoc(doc(db,`${root}/rewardCatalog/archived-first`),{...fields(),status:'archived'}));
});
