import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {initializeTestEnvironment,assertFails,assertSucceeds,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc} from 'firebase/firestore';
import {ref,uploadBytes,getBytes,getMetadata,deleteObject,listAll} from 'firebase/storage';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
let env:RulesTestEnvironment;
const bucket='gs://demo-gainpath.appspot.com',id='0123456789abcdef0123456789abcdef';
let path='';
let fixtureId=0;
const png=new Uint8Array([137,80,78,71,13,10,26,10]);
const client=(uid='member',verified=true)=>env.authenticatedContext(uid,{email_verified:verified});
beforeAll(async()=>{
 if(!process.env.FIRESTORE_EMULATOR_HOST||!process.env.FIREBASE_STORAGE_EMULATOR_HOST)throw Error('Local emulators required');
 const dir=process.env.MEMBER_PHOTO_RULES_DIR ?? '../firebase';
 env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{rules:readFileSync(join(dir,'firestore.rules'),'utf8')},storage:{rules:readFileSync(join(dir,'storage.rules'),'utf8')}});
});
beforeEach(async()=>{path=`orgs/o/memberProfilePhotos/member/${(++fixtureId).toString(16).padStart(32,'0')}`;await env.clearFirestore();await env.clearStorage();await env.withSecurityRulesDisabled(async c=>{
 for(const [uid,role] of [['member','member'],['other','member'],['admin','admin'],['coach','coach'],['staff','staff']]){
  await setDoc(doc(c.firestore(),`users/${uid}`),{organizationId:'o',displayName:'Preserved',avatarPath:'existing-admin-contract',fitness:{weight:70},notificationPreferences:{emailAlerts:true}});
  await setDoc(doc(c.firestore(),`orgs/o/members/${uid}`),{organizationId:'o',role,status:'active',branchIds:['main']});
 }
});});
afterAll(async()=>env?.cleanup());
it('Member saves, reopens, replaces and clears a private reference while preserving identity',async()=>{
 const ctx=client(),user=doc(ctx.firestore(),'users/member');
 await assertSucceeds(uploadBytes(ref(ctx.storage(bucket),path),png,{contentType:'image/png'}));
 expect(new Uint8Array(await getBytes(ref(ctx.storage(bucket),path)))).toEqual(png);
 for(const value of [path,`orgs/o/memberProfilePhotos/member/${'a'.repeat(32)}`,'']){
  await assertSucceeds(updateDoc(user,{memberPhotoPath:value,updatedAtMillis:2}));
  expect((await getDoc(user)).data()).toMatchObject({memberPhotoPath:value,displayName:'Preserved',fitness:{weight:70},notificationPreferences:{emailAlerts:true}});
 }
});
it('foreign actors, other roles, unverified and anonymous cannot use Member photos',async()=>{
 await env.withSecurityRulesDisabled(async c=>{await uploadBytes(ref(c.storage(bucket),path),png,{contentType:'image/png'});});
 for(const ctx of [client('other'),client('admin'),client('coach'),client('staff'),client('member',false),env.unauthenticatedContext()]){
  await assertFails(getMetadata(ref(ctx.storage(bucket),path)));
  await assertFails(updateDoc(doc(ctx.firestore(),'users/member'),{memberPhotoPath:path,updatedAtMillis:2}));
 }
 for(const uid of ['admin','coach','staff']){
  await assertFails(uploadBytes(ref(client(uid).storage(bucket),`orgs/o/memberProfilePhotos/${uid}/${id}`),png,{contentType:'image/png'}));
  await assertFails(updateDoc(doc(client(uid).firestore(),`users/${uid}`),{memberPhotoPath:`orgs/o/memberProfilePhotos/${uid}/${id}`,updatedAtMillis:2}));
 }
});
it('only bounded owned paths and photo-only identity patches are allowed',async()=>{
 const ctx=client(),user=doc(ctx.firestore(),'users/member');
 for(const memberPhotoPath of [`orgs/o/memberProfilePhotos/other/${id}`,`orgs/foreign/memberProfilePhotos/member/${id}`,'https://example.com/photo?token=secret',{},null,`orgs/o/memberProfilePhotos/member/../${id}`]){
  await assertFails(updateDoc(user,{memberPhotoPath,updatedAtMillis:2}));
 }
 for(const patch of [{organizationId:'other'},{role:'admin'},{displayName:'Changed'},{fitness:{weight:1}},{updatedAtMillis:'bad'}]){
  await assertFails(updateDoc(user,{memberPhotoPath:path,updatedAtMillis:2,...patch}));
 }
 for(const foreign of [`orgs/o/memberProfilePhotos/other/${id}`,`orgs/other/memberProfilePhotos/member/${id}`])await assertFails(uploadBytes(ref(ctx.storage(bucket),foreign),png,{contentType:'image/png'}));
});
it('inactive, wrong role and canonical organization drift revoke reads, uploads and reference writes',async()=>{
 await uploadBytes(ref(client().storage(bucket),path),png,{contentType:'image/png'});
 for(const [document,patch] of [['users/member',{organizationId:'foreign'}],['orgs/o/members/member',{status:'suspended'}],['orgs/o/members/member',{organizationId:'foreign'}],['orgs/o/members/member',{role:'coach'}]] as const){
  await env.withSecurityRulesDisabled(async c=>{
   await updateDoc(doc(c.firestore(),'users/member'),{organizationId:'o'});
   await updateDoc(doc(c.firestore(),'orgs/o/members/member'),{organizationId:'o',status:'active',role:'member'});
   await updateDoc(doc(c.firestore(),document),patch);
  });
  await assertFails(getBytes(ref(client().storage(bucket),path)));
  await assertFails(updateDoc(doc(client().firestore(),'users/member'),{memberPhotoPath:path,updatedAtMillis:2}));
 }
});
it('rejects unsafe types and byte boundaries; retains immutable objects without list/delete',async()=>{
 const storage=client().storage(bucket);
 for(const [bytes,type] of [[new Uint8Array(0),'image/png'],[new Uint8Array(5*1024*1024+1),'image/png'],[png,'image/svg+xml'],[png,'application/octet-stream']]as const){
  await assertFails(uploadBytes(ref(storage,path),bytes,{contentType:type}));
 }
 await assertSucceeds(uploadBytes(ref(storage,path),new Uint8Array(5*1024*1024),{contentType:'image/jpeg'}));
 await assertFails(uploadBytes(ref(storage,path),png,{contentType:'image/png'}));
 await assertFails(deleteObject(ref(storage,path)));await assertFails(listAll(ref(storage,'orgs/o/memberProfilePhotos/member')));
});
it('preserves Admin photo and Equipment policy and denies unrelated Storage paths',async()=>{
 const admin=client('admin').storage(bucket),adminPath=`orgs/o/profilePhotos/admin/${id}`,equipment=`orgs/o/equipmentImages/admin/${id}`;
 await assertSucceeds(uploadBytes(ref(admin,adminPath),png,{contentType:'image/png'}));
 await assertSucceeds(getMetadata(ref(admin,adminPath)));await assertFails(getMetadata(ref(client().storage(bucket),adminPath)));
 await assertSucceeds(uploadBytes(ref(admin,equipment),png,{contentType:'image/png'}));await assertSucceeds(getMetadata(ref(client().storage(bucket),equipment)));
 for(const unrelated of ['tutorials/existing.mp4','orgs/o/content/photo.png','orgs/o/members/member/profile.png'])await assertFails(uploadBytes(ref(admin,unrelated),png,{contentType:'image/png'}));
});
