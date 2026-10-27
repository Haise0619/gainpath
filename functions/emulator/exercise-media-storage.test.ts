import { readFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { afterAll, beforeAll, beforeEach, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment,
  type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getMetadata, deleteObject, listAll } from 'firebase/storage';

let env: RulesTestEnvironment;
const bucket = 'gs://demo-gainpath.appspot.com';
const bytes = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]);
let objectPrefix: string;
const objectId = (id: string) => /^[a-f0-9]{32}$/.test(id) ? objectPrefix + id.slice(8) : id;
const image = (uid = 'admin', id = 'a'.repeat(32)) => `orgs/o/exerciseImages/${uid}/${objectId(id)}`;
const video = (uid = 'admin', id = 'b'.repeat(32)) => `orgs/o/exerciseVideos/${uid}/${objectId(id)}.mp4`;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    throw Error('Isolated Firestore/Storage emulators required.');
  }
  env = await initializeTestEnvironment({projectId:'demo-gainpath',
    firestore:{rules:readFileSync(process.env.GAINPATH_EXERCISE_FIRESTORE_RULES_FILE || '../firebase/firestore.rules', 'utf8')},
    storage:{rules:readFileSync(process.env.GAINPATH_EQUIPMENT_STORAGE_RULES_FILE || '../firebase/storage.rules', 'utf8')}});
});
afterAll(async () => env?.cleanup());
beforeEach(async () => {
  // clearStorage() only deletes root objects in this SDK version, not prefixes.
  // Use independent immutable object IDs instead of weakening overwrite Rules.
  objectPrefix = randomBytes(4).toString('hex');
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    for (const [uid, role] of [['admin','admin'], ['staff','staff'], ['member','member'], ['coach','coach']]) {
      await context.firestore().doc(`users/${uid}`).set({organizationId:'o'});
      await context.firestore().doc(`orgs/o/members/${uid}`).set({organizationId:'o', role, status:'active'});
    }
  });
});
const storage = (uid: string, verified = true) => env.authenticatedContext(uid, {email_verified:verified}).storage(bucket);
const put = (uid: string, path: string, type: string, data = bytes) =>
  uploadBytes(ref(storage(uid), path), data, {contentType:type});

it('Admin and Staff upload covers/MP4s; active Members read without listing', async () => {
  for (const [index, type] of ['image/jpeg','image/png','image/webp'].entries()) {
    await assertSucceeds(put('admin', image('admin', String(index).repeat(32)), type));
  }
  await assertSucceeds(put('staff', image('staff'), 'image/png'));
  await assertSucceeds(put('admin', video(), 'video/mp4'));
  await assertSucceeds(put('staff', video('staff'), 'video/mp4'));
  await assertSucceeds(getMetadata(ref(storage('member'), image('staff'))));
  await assertSucceeds(getMetadata(ref(storage('member'), video())));
  await assertFails(listAll(ref(storage('member'), 'orgs/o/exerciseImages')));
  await assertFails(listAll(ref(storage('admin'), 'orgs/o/exerciseVideos')));
});
it('rejects unauthorized roles, unverified callers, wrong uploader and organization', async () => {
  for (const uid of ['member','coach']) {
    await assertFails(put(uid, image(uid), 'image/png'));
    await assertFails(put(uid, video(uid), 'video/mp4'));
  }
  await assertFails(uploadBytes(ref(storage('admin', false), image()), bytes, {contentType:'image/png'}));
  await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(bucket), video()), bytes, {contentType:'video/mp4'}));
  await assertFails(put('admin', image('staff'), 'image/png'));
  await assertFails(put('admin', video('staff'), 'video/mp4'));
  await assertFails(put('admin', image().replace('orgs/o/', 'orgs/other/'), 'image/png'));
  await assertFails(put('admin', video().replace('orgs/o/', 'orgs/other/'), 'video/mp4'));
});
it('rejects unsupported types, invalid object IDs and empty uploads', async () => {
  await assertFails(put('admin', image(), 'image/svg+xml'));
  await assertFails(put('admin', video(), 'video/quicktime'));
  await assertFails(put('admin', image('admin', 'local-filename.jpg'), 'image/png'));
  await assertFails(put('admin', video('admin', 'local-filename'), 'video/mp4'));
  await assertFails(put('admin', image(), 'image/png', new Uint8Array()));
  await assertFails(put('admin', video(), 'video/mp4', new Uint8Array()));
});
it('enforces the 5 MB cover and 100 MB video bounds', async () => {
  await assertSucceeds(put('admin', image(), 'image/png', new Uint8Array(5 * 1024 * 1024)));
  await assertFails(put('staff', image('staff'), 'image/png', new Uint8Array(5 * 1024 * 1024 + 1)));
  await assertFails(put('admin', video(), 'video/mp4', new Uint8Array(100 * 1024 * 1024 + 1)));
});
it('replacement/removal cannot overwrite or delete existing media objects', async () => {
  await assertSucceeds(put('admin', image(), 'image/png'));
  await assertSucceeds(put('admin', video(), 'video/mp4'));
  await assertFails(put('admin', image(), 'image/png'));
  await assertFails(put('admin', video(), 'video/mp4'));
  await assertFails(deleteObject(ref(storage('admin'), image())));
  await assertFails(deleteObject(ref(storage('admin'), video())));
});
it('stale assignments, inactive members and mismatched memberships lose access', async () => {
  await assertSucceeds(put('admin', image(), 'image/png'));
  await assertSucceeds(put('admin', video(), 'video/mp4'));
  await env.withSecurityRulesDisabled(async context => {
    await context.firestore().doc('users/admin').update({organizationId:'other'});
    await context.firestore().doc('orgs/o/members/staff').update({status:'suspended'});
    await context.firestore().doc('orgs/o/members/member').update({organizationId:'other'});
  });
  await assertFails(put('admin', image('admin','c'.repeat(32)), 'image/png'));
  await assertFails(put('staff', video('staff'), 'video/mp4'));
  await assertFails(getMetadata(ref(storage('member'), image())));
  await assertFails(getMetadata(ref(storage('admin'), video())));
});
