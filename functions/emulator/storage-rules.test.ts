import { readFileSync } from 'node:fs';
import type firebase from 'firebase/compat/app';
import 'firebase/compat/storage';
import {
  afterAll,
  beforeAll,
  beforeEach,
  it,
} from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

let env: RulesTestEnvironment;
const bucket = 'gs://demo-gainpath.appspot.com';

beforeAll(async () => {
  if (!process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    throw new Error('Run using the Firestore and Storage emulators.');
  }
  env = await initializeTestEnvironment({
    projectId: 'demo-gainpath',
    firestore: { rules: readFileSync('../firebase/firestore.rules', 'utf8') },
    storage: { rules: readFileSync('../firebase/storage.rules', 'utf8') },
  });
});

afterAll(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async context => {
    await context.firestore().doc('orgs/o/members/member').set({
      role: 'member',
      status: 'active',
      branchIds: ['main'],
    });
    await context
        .storage(bucket)
        .ref('orgs/o/content/welcome.txt')
        .putString('welcome', 'raw', { contentType: 'text/plain' });
  });
});

const storageFor = (verified: boolean) =>
  env
      .authenticatedContext('member', { email_verified: verified })
      .storage(bucket);

const uploadPromise = (task: firebase.storage.UploadTask) =>
  new Promise((resolve, reject) => task.then(resolve, reject));

it('allows verified members to upload allowed member files', async () => {
  const upload = storageFor(true)
      .ref('orgs/o/members/member/profile.png')
      .putString('image', 'raw', { contentType: 'image/png' });
  await assertSucceeds(uploadPromise(upload));
});

it('denies protected Storage access before email verification', async () => {
  const storage = storageFor(false);
  await assertFails(
    uploadPromise(storage
      .ref('orgs/o/members/member/profile.png')
      .putString('image', 'raw', { contentType: 'image/png' })),
  );
  await assertFails(
    storage.ref('orgs/o/content/welcome.txt').getDownloadURL(),
  );
});
