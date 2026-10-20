import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment,
  type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getMetadata, deleteObject, listAll } from 'firebase/storage';

let env: RulesTestEnvironment;
const bucket = 'gs://demo-gainpath.appspot.com';
const path = 'orgs/o/equipmentImages/admin/image-one';
const png = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]);
beforeAll(async () => {
  if (!process.env.FIREBASE_STORAGE_EMULATOR_HOST) throw Error('Emulators required');
  env = await initializeTestEnvironment({ projectId: 'demo-gainpath',
    firestore: { rules: readFileSync('../firebase/firestore.rules', 'utf8') },
    storage: { rules: readFileSync(process.env.GAINPATH_EQUIPMENT_STORAGE_RULES_FILE || '../firebase/storage.rules', 'utf8') } });
});
afterAll(async () => env?.cleanup());
beforeEach(async () => {
  await env.clearFirestore(); await env.clearStorage();
  await env.withSecurityRulesDisabled(async c => {
    for (const [uid, role] of [['admin', 'admin'], ['staff', 'staff'], ['member', 'member'], ['coach', 'coach']]) {
      await c.firestore().doc(`users/${uid}`).set({ organizationId: 'o' });
      await c.firestore().doc(`orgs/o/members/${uid}`).set({ organizationId: 'o', role, status: 'active', branchIds: ['main'] });
    }
  });
});
const storage = (uid: string, verified = true) => env.authenticatedContext(uid, { email_verified: verified }).storage(bucket);
it('Admin and Staff create scoped images; active Members read metadata, not lists', async () => {
  await assertSucceeds(uploadBytes(ref(storage('admin'), path), png, { contentType: 'image/png' }));
  await assertSucceeds(uploadBytes(ref(storage('staff'), 'orgs/o/equipmentImages/staff/image-two'), png, { contentType: 'image/png' }));
  await assertSucceeds(getMetadata(ref(storage('member'), path)));
  await assertFails(listAll(ref(storage('member'), 'orgs/o/equipmentImages')));
});
it('denies unverified, other-role, other-owner and cross-organization uploads', async () => {
  for (const uid of ['member', 'coach']) {
    await assertFails(uploadBytes(ref(storage(uid), `orgs/o/equipmentImages/${uid}/one`), png, { contentType: 'image/png' }));
  }
  await assertFails(uploadBytes(ref(storage('admin', false), path), png, { contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(storage('admin'), 'orgs/o/equipmentImages/staff/one'), png, { contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(storage('admin'), 'orgs/other/equipmentImages/admin/one'), png, { contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(bucket), path), png, { contentType: 'image/png' }));
});
it('rejects oversized or unsupported images and preserves existing objects', async () => {
  const uniquePath = `${path}-immutable`;
  await assertFails(uploadBytes(ref(storage('admin'), `${path}-invalid-type`), png, { contentType: 'image/svg+xml' }));
  await assertFails(uploadBytes(ref(storage('admin'), `${path}-oversized`), new Uint8Array(5 * 1024 * 1024 + 1), { contentType: 'image/png' }));
  await assertSucceeds(uploadBytes(ref(storage('admin'), uniquePath), png, { contentType: 'image/png' }))
    .catch(() => { throw Error('Initial valid image creation failed'); });
  await assertFails(uploadBytes(ref(storage('admin'), uniquePath), new Uint8Array([...png, 1]), { contentType: 'image/png' }))
    .catch(() => { throw Error('Existing image replacement was not denied'); });
  await assertFails(deleteObject(ref(storage('admin'), uniquePath)))
    .catch(() => { throw Error('Existing image deletion was not denied'); });
});
it('denies stale organization assignments, inactive and mismatched membership', async () => {
  await env.withSecurityRulesDisabled(async c => {
    await c.firestore().doc('users/admin').update({ organizationId: 'other' });
    await c.firestore().doc('orgs/o/members/staff').update({ status: 'suspended' });
    await c.firestore().doc('orgs/o/members/member').update({ organizationId: 'other' });
    await uploadBytes(ref(c.storage(bucket), path), png, { contentType: 'image/png' });
  });
  await assertFails(uploadBytes(ref(storage('admin'), 'orgs/o/equipmentImages/admin/new'), png, { contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(storage('staff'), 'orgs/o/equipmentImages/staff/new'), png, { contentType: 'image/png' }));
  await assertFails(getMetadata(ref(storage('member'), path)));
});
it.skipIf(!process.env.GAINPATH_EQUIPMENT_STORAGE_RULES_FILE)('activation candidate keeps unrelated paths denied', async () => {
  for (const other of ['tutorials/existing.mp4', 'orgs/o/content/image.png', 'orgs/o/members/admin/profile.png']) {
    await assertFails(uploadBytes(ref(storage('admin'), other), png, { contentType: 'image/png' }));
  }
});
