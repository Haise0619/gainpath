import { expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { InputValidationError } from '../src/platform/validation';
import { saveCoachProfile, setCoachDirectoryStatus } from '../src/modules/coaching/coach-profile-service';

const root = 'orgs/o', auth = (uid: string, email_verified = true) => ({ uid, token: { email_verified } });
const fields = { displayName: 'Coach example', specialty: 'Strength', bio: 'Professional bio', specializationTags: ['Strength'], yearsExperience: null };
const save = (requestId = 'save', expectedRevision = 0, patch: object = fields) => ({ schemaVersion: 1, organizationId: 'o', requestId, expectedRevision, patch });
const publish = (requestId = 'publish', expectedProfileRevision = 1, expectedPublicRevision = 0) => ({ schemaVersion: 1, organizationId: 'o', coachId: 'coach', requestId, action: 'publish', expectedProfileRevision, expectedPublicRevision, expectedCoachBranchIds: ['main'] });
const deactivate = (requestId = 'deactivate', expectedPublicRevision = 1) => ({ schemaVersion: 1, organizationId: 'o', coachId: 'coach', requestId, action: 'deactivate', expectedPublicRevision });
const identity = async () => ({ exists: true, emailVerified: true, disabled: false });
function setup() {
  const store = new MemoryStore();
  store.documents.set(root, { status: 'active' });
  store.documents.set(`${root}/branches/main`, { status: 'active' });
  for (const [uid, role] of [['coach', 'coach'], ['admin', 'admin'], ['staff', 'staff'], ['member', 'member']]) {
    store.documents.set(`users/${uid}`, { organizationId: 'o' });
    store.documents.set(`${root}/members/${uid}`, { organizationId: 'o', role, status: 'active', branchIds: ['main'] });
  }
  return store;
}
it('creates/edits only private profile; publishes an allowlist and safely deactivates a public-only row', async () => {
  const store = setup();
  await saveCoachProfile(store, auth('coach'), save(), () => 100);
  expect(store.documents.has(`${root}/coaches/coach`)).toBe(false);
  const privateDoc = store.documents.get(`${root}/coachProfiles/coach`)!;
  privateDoc.privateNote = 'never public';
  await saveCoachProfile(store, auth('coach'), save('edit', 1, { bio: 'New bio', yearsExperience: 4 }), () => 200);
  expect(store.documents.get(`${root}/coachProfiles/coach`)).toMatchObject({ revision: 2, createdAtMillis: 100, privateNote: 'never public', displayName: fields.displayName });
  await setCoachDirectoryStatus(store, auth('admin'), publish('pub', 2), identity, () => 300);
  const publicDoc = store.documents.get(`${root}/coaches/coach`)!;
  expect(publicDoc).toMatchObject({ revision: 1, sourceRevision: 2, status: 'published', branchIds: ['main'], yearsExperience: 4 });
  expect(publicDoc).not.toHaveProperty('privateNote');
  expect(publicDoc).not.toHaveProperty('verified');
  store.documents.delete(`${root}/coachProfiles/coach`);
  store.documents.delete(`${root}/members/coach`);
  await setCoachDirectoryStatus(store, auth('admin'), deactivate(), async () => { throw Error('not used'); }, () => 400);
  expect(store.documents.get(`${root}/coaches/coach`)).toEqual({ ...publicDoc, status: 'inactive', revision: 2, updatedAtMillis: 400 });
  await setCoachDirectoryStatus(store, auth('admin'), deactivate('again', 2), identity, () => 500);
  expect(store.documents.get(`${root}/coaches/coach`)?.updatedAtMillis).toBe(400);
});
it('idempotently replays canonical patches; rejects changed intent and replay after authorization loss', async () => {
  const store = setup();
  const result = await saveCoachProfile(store, auth('coach'), save());
  expect(await saveCoachProfile(store, auth('coach'), save('save', 0, { ...fields, bio: fields.bio }))).toEqual(result);
  await expect(saveCoachProfile(store, auth('coach'), save('save', 0, { ...fields, bio: 'Changed' }))).rejects.toMatchObject({ code: 'already-exists' });
  await setCoachDirectoryStatus(store, auth('admin'), publish(), identity);
  expect(await setCoachDirectoryStatus(store, auth('admin'), publish(), async () => { throw Error('replay must not recheck target'); })).toMatchObject({ revision: 1 });
  store.documents.get(`${root}/members/admin`)!.role = 'staff';
  await expect(setCoachDirectoryStatus(store, auth('admin'), publish(), identity)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('rejects concurrent edits and stale publication source/public/branch baselines without adopting new revisions', async () => {
  const store = setup();
  await saveCoachProfile(store, auth('coach'), save());
  const outcomes = await Promise.allSettled(['one', 'two'].map(requestId => saveCoachProfile(store, auth('coach'), save(requestId, 1, { bio: requestId }))));
  expect(outcomes.filter(o => o.status === 'fulfilled')).toHaveLength(1);
  expect((outcomes.find(o => o.status === 'rejected') as PromiseRejectedResult).reason.code).toBe('aborted');
  await expect(setCoachDirectoryStatus(store, auth('admin'), publish(), identity)).rejects.toMatchObject({ code: 'aborted' });
  await expect(setCoachDirectoryStatus(store, auth('admin'), { ...publish('branch', 2), expectedCoachBranchIds: ['elsewhere'] }, identity)).rejects.toMatchObject({ code: 'aborted' });
  await setCoachDirectoryStatus(store, auth('admin'), publish('fresh', 2), identity);
  await expect(setCoachDirectoryStatus(store, auth('admin'), publish('stale-public', 2), identity)).rejects.toMatchObject({ code: 'aborted' });
});
it.each(['member', 'staff', 'admin'])('rejects %s own profile authoring', async uid => {
  await expect(saveCoachProfile(setup(), auth(uid), save())).rejects.toMatchObject({ code: 'permission-denied' });
});
it.each(['coach', 'staff', 'member'])('rejects %s directory management', async uid => {
  await expect(setCoachDirectoryStatus(setup(), auth(uid), publish(), identity)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('rejects unverification, cross-org assignment, inactive branches and unsupported/missing records', async () => {
  const store = setup();
  await expect(saveCoachProfile(store, auth('coach', false), save())).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.get('users/coach')!.organizationId = 'other';
  await expect(saveCoachProfile(store, auth('coach'), save())).rejects.toMatchObject({ code: 'permission-denied' });
  store.documents.get('users/coach')!.organizationId = 'o';
  store.documents.get(`${root}/branches/main`)!.status = 'inactive';
  await expect(saveCoachProfile(store, auth('coach'), save())).rejects.toMatchObject({ code: 'failed-precondition' });
  store.documents.get(`${root}/branches/main`)!.status = 'active';
  await expect(setCoachDirectoryStatus(store, auth('admin'), publish(), identity)).rejects.toMatchObject({ code: 'not-found' });
  await expect(setCoachDirectoryStatus(store, auth('admin'), deactivate(), identity)).rejects.toMatchObject({ code: 'not-found' });
  store.documents.set(`${root}/coachProfiles/coach`, { ...fields, schemaVersion: 2, revision: 1 });
  await expect(saveCoachProfile(store, auth('coach'), save('bad-schema', 1, { bio: 'Edit' }))).rejects.toMatchObject({ code: 'failed-precondition' });
});
it.each([{ exists: false, emailVerified: false, disabled: false }, { exists: true, emailVerified: false, disabled: false }, { exists: true, emailVerified: true, disabled: true }])('blocks ineligible target Auth identity without claiming certification', async flags => {
  const store = setup(); await saveCoachProfile(store, auth('coach'), save());
  await expect(setCoachDirectoryStatus(store, auth('admin'), publish(), async () => flags)).rejects.toMatchObject({ code: 'failed-precondition' });
});
it('rejects unknown/private author fields and invalid experience with safe errors', async () => {
  for (const patch of [{ ...fields, verified: true }, { ...fields, yearsExperience: 1.5 }, { ...fields, specializationTags: ['X', 'X'] }, { bio: 'incomplete' }]) {
    await expect(saveCoachProfile(setup(), auth('coach'), save('bad', 0, patch))).rejects.toBeInstanceOf(InputValidationError);
  }
});

it.each([
  ['private', 'createdAtMillis'], ['private', 'updatedAtMillis'],
  ['public', 'createdAtMillis'], ['public', 'updatedAtMillis'], ['public', 'publishedAtMillis'],
])('rejects malformed %s %s without changing documents or receipts', async (kind, field) => {
  for (const invalid of [-1, 1.5, '100', null, undefined, Number.MAX_SAFE_INTEGER + 1]) {
    const store = setup();
    const data: Record<string, unknown> = { ...fields, schemaVersion: 1, revision: 1, createdAtMillis: 100, updatedAtMillis: 100,
      ...(kind === 'public' ? { sourceRevision: 1, status: 'published', branchIds: ['main'], publishedAtMillis: 100 } : {}) };
    if (invalid === undefined) delete data[field]; else data[field] = invalid;
    store.documents.set(`${root}/${kind === 'public' ? 'coaches' : 'coachProfiles'}/coach`, data);
    const before = structuredClone([...store.documents]);
    const operation = kind === 'private'
      ? saveCoachProfile(store, auth('coach'), save(`edit-${field}`, 1, { bio: 'Edited' }), () => 200)
      : setCoachDirectoryStatus(store, auth('admin'), deactivate(`deactivate-${field}`), identity, () => 200);
    await expect(operation).rejects.toMatchObject({ code: 'failed-precondition', message: 'The profile needs an authorized schema review.' });
    expect([...store.documents]).toEqual(before);
  }
});
it('rejects publication of a negative-timestamp draft without creating a projection or receipt', async () => {
  const store = setup();
  store.documents.set(`${root}/coachProfiles/coach`, { ...fields, schemaVersion: 1, revision: 1, createdAtMillis: -1, updatedAtMillis: 100 });
  const before = structuredClone([...store.documents]);
  await expect(setCoachDirectoryStatus(store, auth('admin'), publish('fresh-publication'), identity, () => 200)).rejects.toMatchObject({ code: 'failed-precondition' });
  expect([...store.documents]).toEqual(before);
});
it.each([0, 100])('retains Dart-compatible timestamp %s for own edit and public deactivation', async timestamp => {
  const store = setup();
  store.documents.set(`${root}/coachProfiles/coach`, { ...fields, schemaVersion: 1, revision: 1, createdAtMillis: timestamp, updatedAtMillis: timestamp });
  await saveCoachProfile(store, auth('coach'), save('valid-edit', 1, { bio: 'Edited' }), () => 200);
  expect(store.documents.get(`${root}/coachProfiles/coach`)).toMatchObject({ createdAtMillis: timestamp, updatedAtMillis: 200, revision: 2 });
  store.documents.set(`${root}/coaches/coach`, { ...fields, schemaVersion: 1, revision: 1, sourceRevision: 1, status: 'published', branchIds: ['main'], createdAtMillis: timestamp, updatedAtMillis: timestamp, publishedAtMillis: timestamp });
  await setCoachDirectoryStatus(store, auth('admin'), deactivate('valid-deactivate'), identity, () => 200);
  expect(store.documents.get(`${root}/coaches/coach`)).toMatchObject({ createdAtMillis: timestamp, updatedAtMillis: 200, publishedAtMillis: timestamp, status: 'inactive', revision: 2 });
});
