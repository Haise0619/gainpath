import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, it, expect } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes, getMetadata, deleteObject, listAll } from 'firebase/storage';
let env: RulesTestEnvironment;
const bucket='gs://demo-gainpath.appspot.com';
const id='0123456789abcdef0123456789abcdef';
let photo = '';
let fixtureId = 0;
const png=new Uint8Array([137,80,78,71,13,10,26,10]);
beforeAll(async()=>{
  if(!process.env.FIREBASE_STORAGE_EMULATOR_HOST)throw Error('Local emulators required');
  env=await initializeTestEnvironment({projectId:'demo-gainpath',
    firestore:{rules:readFileSync('../firebase/firestore.rules','utf8')},
    storage:{rules:readFileSync(process.env.GAINPATH_PROFILE_STORAGE_RULES_FILE||'../firebase/storage.rules','utf8')}});
});
afterAll(async()=>env?.cleanup());
beforeEach(async()=>{
  photo = `orgs/o/profilePhotos/admin/${(++fixtureId).toString(16).padStart(32,'0')}`;
  await env.clearFirestore();await env.clearStorage();
  await env.withSecurityRulesDisabled(async c=>{
    for(const [uid,role]of[['admin','admin'],['other','admin'],['member','member'],['coach','coach']]){
      await c.firestore().doc(`users/${uid}`).set({organizationId:'o'});
      await c.firestore().doc(`orgs/o/members/${uid}`).set({organizationId:'o',role,status:'active',branchIds:['main']});
    }
  });
});
const storage=(uid='admin',verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).storage(bucket);
it('verified owner uploads and reads bytes; other Admin, Member, Coach and anonymous reads are denied',async()=>{
  await assertSucceeds(uploadBytes(ref(storage(),photo),png,{contentType:'image/png'}));
  expect(new Uint8Array(await getBytes(ref(storage(),photo)))).toEqual(png);
  for(const uid of ['other','member','coach'])await assertFails(getMetadata(ref(storage(uid),photo)));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(bucket),photo)));
});
it('denies foreign owner/org, unverified, non-Admin, empty/oversize and unsupported uploads',async()=>{
  await assertFails(uploadBytes(ref(storage('admin',false),photo),png,{contentType:'image/png'}));
  for(const uid of ['member','coach'])await assertFails(uploadBytes(ref(storage(uid),`orgs/o/profilePhotos/${uid}/${id}`),png,{contentType:'image/png'}));
  for(const path of [`orgs/o/profilePhotos/other/${id}`,`orgs/other/profilePhotos/admin/${id}`])await assertFails(uploadBytes(ref(storage(),path),png,{contentType:'image/png'}));
  for(const [bytes,type]of [[new Uint8Array(0),'image/png'],[new Uint8Array(5*1024*1024+1),'image/png'],[png,'image/svg+xml']]as const){
    await assertFails(uploadBytes(ref(storage(),photo),bytes,{contentType:type}));
  }
});
it('retains immutable objects; overwrite, deletion and enumeration are denied',async()=>{
  await uploadBytes(ref(storage(),photo),png,{contentType:'image/png'});
  await assertFails(uploadBytes(ref(storage(),photo),png,{contentType:'image/png'}));
  await assertFails(deleteObject(ref(storage(),photo)));
  await assertFails(listAll(ref(storage(),'orgs/o/profilePhotos/admin')));
});
it('canonical org, membership status and membership org drift revoke photo access',async()=>{
  await uploadBytes(ref(storage(),photo),png,{contentType:'image/png'});
  for(const [document,patch]of [['users/admin',{organizationId:'other'}],['orgs/o/members/admin',{status:'suspended'}],['orgs/o/members/admin',{organizationId:'other'}]]as const){
    await env.withSecurityRulesDisabled(async c=>{
      await c.firestore().doc('users/admin').update({organizationId:'o'});
      await c.firestore().doc('orgs/o/members/admin').update({organizationId:'o',status:'active'});
      await c.firestore().doc(document).update(patch);
    });
    await assertFails(getBytes(ref(storage(),photo)));
  }
});
it.skipIf(!process.env.GAINPATH_PROFILE_STORAGE_RULES_FILE)('exact candidate keeps unrelated protected Storage paths denied',async()=>{
  for(const path of ['tutorials/existing.mp4','orgs/o/content/image.png','orgs/o/members/admin/profile.png']){
    await assertFails(uploadBytes(ref(storage(),path),png,{contentType:'image/png'}));
  }
});
