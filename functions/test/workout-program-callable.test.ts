import {beforeEach, expect, it, vi} from 'vitest';
const mocks = vi.hoisted(() => ({getUser: vi.fn(), transact: vi.fn(), options: {} as Record<string, unknown>}));
vi.mock('firebase-functions/v2/https', async importOriginal => {
  const actual = await importOriginal<typeof import('firebase-functions/v2/https')>();
  return {...actual, onCall: (options: any, handler: any) => {Object.assign(mocks.options, options); return actual.onCall(options, handler);}};
});
vi.mock('firebase-admin/auth', () => ({getAuth: () => ({getUser: mocks.getUser})}));
vi.mock('firebase-admin/firestore', () => ({getFirestore: () => ({})}));
vi.mock('../src/platform/firestore/firestore-store', () => ({FirestoreStore: class {transact = mocks.transact;}}));
import {workoutProgramCommand} from '../src/modules/content/workout-program-callable';
import {MemoryStore} from './memory-store';

const now = 1800000000000, data = {schemaVersion: 1, organizationId: 'gainpath', action: 'list'};
const auth = {uid: 'admin', token: {email_verified: true, email: 'admin@example.test', auth_time: now / 1000}};
const request = {app: {appId: 'synthetic'}, auth, data};
let store: MemoryStore;
beforeEach(() => {
  vi.resetAllMocks(); vi.stubEnv('WORKOUT_PROGRAM_ORGANIZATION_ID', 'gainpath');
  store = new MemoryStore(); mocks.transact.mockImplementation(work => store.transact(work));
  store.documents.set('orgs/gainpath', {status: 'active'});
  store.documents.set('users/admin', {organizationId: 'gainpath', role: 'admin'});
  store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', userId: 'admin', role: 'admin', status: 'active', branchIds: []});
  mocks.getUser.mockResolvedValue({disabled: false, emailVerified: true, email: auth.token.email, tokensValidAfterTime: new Date(0).toUTCString()});
});
it('pins Singapore, App Check and bounded callable runtime options', () => {
  expect((workoutProgramCommand as any).__endpoint).toMatchObject({region: ['asia-southeast1'], timeoutSeconds: 60, maxInstances: 5, availableMemoryMb: 512});
  expect(mocks.options).toMatchObject({enforceAppCheck: true, concurrency: 1});
});
it('requires App Check and verified Auth before backend access', async () => {
  for (const [req, code] of [[{data}, 'unauthenticated'], [{app: request.app, data}, 'unauthenticated'], [{...request, auth: {...auth, token: {email_verified: false}}}, 'permission-denied']] as const) {
    await expect(workoutProgramCommand.run(req as any)).rejects.toMatchObject({code});
  }
  expect(mocks.getUser).not.toHaveBeenCalled(); expect(mocks.transact).not.toHaveBeenCalled();
});
it('restricts the configured organization before data access', async () => {
  await expect(workoutProgramCommand.run({...request, data: {...data, organizationId: 'other'}} as any)).rejects.toMatchObject({code: 'permission-denied'});
  expect(mocks.transact).not.toHaveBeenCalled();
});
it('returns no fake Programs and checks fresh Auth before and after', async () => {
  expect(await workoutProgramCommand.run(request as any)).toEqual({programs: [], drafts: []});
  expect(mocks.getUser).toHaveBeenCalledTimes(2);
});
it.each(['disabled', 'unverified', 'changed-email', 'revoked', 'invalid-revocation'])('rejects fresh account state %s', async mode => {
  mocks.getUser.mockResolvedValue({disabled: mode === 'disabled', emailVerified: mode !== 'unverified', email: mode === 'changed-email' ? 'other@example.test' : auth.token.email,
    tokensValidAfterTime: mode === 'invalid-revocation' ? 'invalid' : new Date(mode === 'revoked' ? now + 1000 : 0).toUTCString()});
  await expect(workoutProgramCommand.run(request as any)).rejects.toMatchObject({code: 'unauthenticated'});
  expect(mocks.transact).not.toHaveBeenCalled();
});
it('requires complete signed session claims', async () => {
  await expect(workoutProgramCommand.run({...request, auth: {...auth, token: {email_verified: true}}} as any)).rejects.toMatchObject({code: 'unauthenticated'});
  expect(mocks.getUser).not.toHaveBeenCalled();
});
it('maps validation errors and hides infrastructure details', async () => {
  await expect(workoutProgramCommand.run({...request, data: {...data, aiSupported: true}} as any)).rejects.toMatchObject({code: 'invalid-argument'});
  mocks.getUser.mockRejectedValue(new Error('private backend path'));
  await expect(workoutProgramCommand.run(request as any)).rejects.toMatchObject({code: 'unavailable', message: expect.not.stringContaining('private')});
});
