import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, limit, orderBy, documentId, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
let env: RulesTestEnvironment;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Isolated emulator required.');
  env = await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{
    rules:readFileSync(process.env.GAINPATH_EQUIPMENT_RULES_FILE || '../firebase/firestore.rules','utf8'),
  }});
});
afterAll(async()=>{await env?.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c=>{
    for(const [uid,role] of [['admin','admin'],['staff','staff'],['member','member'],['coach','coach']]) {
      await setDoc(doc(c.firestore(),`users/${uid}`),{organizationId:'o'});
      await setDoc(doc(c.firestore(),`orgs/o/members/${uid}`),{organizationId:'o',role,status:'active',branchIds:['main']});
    }
  });
});
const dbFor=(uid:string,verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
const path='orgs/o/gymEquipment/e';
const item=()=>({schemaVersion:1,name:'Fixture equipment',category:'Legs',muscleGroup:'Legs',
  description:'Emulator only',howToUse:['Adjust before use'],safetyTips:['Use appropriate supervision'],
  imageUrl:'',isActive:false,revision:1,createdBy:'admin',updatedBy:'admin',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
it('Admin create/edit/activate -> scoped Member browse -> deactivate, preserving identity and metadata',async()=>{
  const admin=dbFor('admin'), member=dbFor('member'),ref=doc(admin,path);
  await setDoc(ref,item());
  const before=(await getDoc(ref)).data()!;
  const browse=()=>getDocs(query(collection(member,'orgs/o/gymEquipment'),where('isActive','==',true),orderBy(documentId()),limit(21)));
  expect((await browse()).empty).toBe(true);
  await assertFails(getDoc(doc(member,path)));
  await updateDoc(ref,{name:'Edited fixture',isActive:true,revision:2,updatedAt:serverTimestamp()});
  expect((await browse()).docs.map(d=>d.id)).toEqual(['e']);
  expect((await getDoc(ref)).data()!.createdAt).toEqual(before.createdAt);
  await updateDoc(ref,{isActive:false,revision:3,updatedAt:serverTimestamp()});
  expect((await browse()).empty).toBe(true);
  await assertFails(deleteDoc(ref));
});
it('denies unauthorized roles, cross-organization and stale canonical assignments; keeps existing Staff author policy',async()=>{
  const admin=dbFor('admin');await setDoc(doc(admin,path),item());
  for(const uid of ['member','coach']) {
    await assertFails(setDoc(doc(dbFor(uid),'orgs/o/gymEquipment/new'),{...item(),createdBy:uid,updatedBy:uid}));
    await assertFails(getDocs(query(collection(dbFor(uid),'orgs/other/gymEquipment'),where('isActive','==',true),limit(20))));
  }
  await assertFails(getDoc(doc(dbFor('admin',false),path)));
  await updateDoc(doc(dbFor('staff'),path),{description:'Staff edit',revision:2,updatedAt:serverTimestamp(),updatedBy:'staff'});
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/admin'),{organizationId:'other'}));
  await assertFails(updateDoc(doc(admin,path),{name:'Forbidden',revision:3,updatedAt:serverTimestamp(),updatedBy:'admin'}));
  await assertFails(setDoc(doc(admin,'orgs/o/gymEquipment/after-reassignment'),item()));
});
it('rejects stale revisions, malformed fields and changes to creation metadata',async()=>{
  const admin=dbFor('admin'),ref=doc(admin,path);await setDoc(ref,item());
  for(const bad of [{revision:1},{createdBy:'staff'},{schemaVersion:2},{name:''},{imageUrl:'http://insecure.test/image.jpg'},
    {howToUse:[1]},{safetyTips:['x'.repeat(401)]},{extraField:true}]) {
    await assertFails(updateDoc(ref,{revision:2,updatedAt:serverTimestamp(),...bad}));
  }
  expect((await getDoc(ref)).data()!.revision).toBe(1);
});

it('tutorial reference is optional, scoped, replaceable and removable without changing equipment identity',async()=>{
 const ref=doc(dbFor('admin'),path); await setDoc(ref,item());
 const url='https://firebasestorage.googleapis.com/v0/b/demo-gainpath.appspot.com/o/orgs%2Fo%2FequipmentVideos%2Fadmin%2F'+'a'.repeat(32)+'.mp4?alt=media&token=fixture';
 await updateDoc(ref,{tutorialVideoUrl:url,revision:2,updatedAt:serverTimestamp()});
 expect((await getDoc(ref)).data()!.tutorialVideoUrl).toBe(url);
 for(const invalid of ['http://insecure/video.mp4',url.replace('%2Fo%2F','%2Fother%2F'),12]) await assertFails(updateDoc(ref,{tutorialVideoUrl:invalid,revision:3,updatedAt:serverTimestamp()}));
 await updateDoc(ref,{tutorialVideoUrl:'',revision:3,updatedAt:serverTimestamp()});
 expect((await getDoc(ref)).data()!.tutorialVideoUrl).toBe('');
});
