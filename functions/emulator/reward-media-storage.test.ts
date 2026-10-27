import {readFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import {beforeAll, beforeEach, afterAll, it} from 'vitest';
import {initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {ref, uploadBytes, getMetadata, deleteObject, listAll} from 'firebase/storage';
let env: RulesTestEnvironment;
let id: string;
const bucket = 'gs://demo-gainpath.appspot.com';
const image = (uid = 'admin', objectId = id) => `orgs/o/rewardImages/${uid}/${objectId}`;
const storage = (uid: string, verified = true, time = 100) => env.authenticatedContext(uid, {email_verified: verified, auth_time: time}).storage(bucket);
const bytes = new Uint8Array([255,216,255,0]);
const put = (uid: string, path = image(uid), data = bytes, type = 'image/jpeg') => uploadBytes(ref(storage(uid), path), data, {contentType:type});
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) throw Error('Loopback emulators required');
  env = await initializeTestEnvironment({projectId:'demo-gainpath', firestore:{rules:readFileSync('../firebase/firestore.rules','utf8')}, storage:{rules:readFileSync(process.env.GAINPATH_REWARD_STORAGE_RULES_FILE || '../firebase/storage.rules','utf8')}});
});
afterAll(async () => env?.cleanup());
beforeEach(async () => {
  id = randomBytes(16).toString('hex');
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    await c.firestore().doc('orgs/o').set({status:'active'});
    for (const [uid,role] of [['admin','admin'],['staff','staff'],['member','member'],['coach','coach']]) {
      await c.firestore().doc(`users/${uid}`).set({organizationId:'o'});
      await c.firestore().doc(`orgs/o/members/${uid}`).set({organizationId:'o',status:'active',role});
    }
  });
});
it('only verified active organization Admin creates images; active members get without list', async () => {
  await assertSucceeds(put('admin'));
  await assertSucceeds(getMetadata(ref(storage('member'), image())));
  for (const uid of ['staff','member','coach']) await assertFails(put(uid));
  await assertFails(uploadBytes(ref(storage('admin',false),image()),bytes,{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(bucket),image()),bytes,{contentType:'image/jpeg'}));
  await assertFails(put('admin',image('staff')));
  await assertFails(put('admin',image().replace('orgs/o/','orgs/other/')));
  await assertFails(listAll(ref(storage('admin'),'orgs/o/rewardImages')));
});
it('enforces immutable JPG/PNG/WebP images, anonymous IDs and 5MB size', async () => {
  await assertSucceeds(put('admin',image(),new Uint8Array(5*1024*1024),'image/png'));
  await assertFails(put('admin'));
  await assertFails(deleteObject(ref(storage('admin'),image())));
  await assertFails(put('admin',image('admin',randomBytes(16).toString('hex')),new Uint8Array(5*1024*1024+1)));
  await assertFails(put('admin',image('admin',randomBytes(16).toString('hex')),new Uint8Array()));
  await assertFails(put('admin',image('admin','local-photo.jpg')));
  await assertFails(put('admin',image('admin',randomBytes(16).toString('hex')),bytes,'image/svg+xml'));
  await assertSucceeds(put('admin',image('admin',randomBytes(16).toString('hex')),bytes,'image/webp'));
});
it('organization reassignment, suspension and stale reactivated sessions lose access', async () => {
  await assertSucceeds(put('admin'));
  await env.withSecurityRulesDisabled(async c => {
    await c.firestore().doc('orgs/o/members/member').update({status:'suspended'});
    await c.firestore().doc('users/staff').update({organizationId:'elsewhere'});
    await c.firestore().doc('users/admin').update({accountLifecycle:{schemaVersion:1,state:'active',revision:1,requestedAtMillis:200000,sessionNotBeforeSeconds:201,revocationPending:false,sessionRevokedAtMillis:200000,reactivatedAtMillis:200001}});
  });
  await assertFails(getMetadata(ref(storage('member'),image())));
  await assertFails(getMetadata(ref(storage('staff'),image())));
  await assertFails(getMetadata(ref(storage('admin'),image())));
  await assertFails(put('admin',image('admin',randomBytes(16).toString('hex'))));
  await assertSucceeds(getMetadata(ref(storage('admin',true,201),image())));
});
it('inactive and missing organizations cannot upload or read reward images', async () => {
  await assertSucceeds(put('admin'));
  for (const state of ['inactive','missing']) {
    await env.withSecurityRulesDisabled(async c => {
      const org = c.firestore().doc('orgs/o');
      if (state === 'missing') await org.delete(); else await org.update({status:state});
    });
    await assertFails(put('admin',image('admin',randomBytes(16).toString('hex'))));
    await assertFails(getMetadata(ref(storage('member'),image())));
  }
});
