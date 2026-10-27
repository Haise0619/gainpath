import {beforeEach, expect, it, vi} from 'vitest';
const mocks = vi.hoisted(() => ({getUser: vi.fn(), transact: vi.fn(), options: {} as Record<string, unknown>}));
vi.mock('firebase-functions/v2/https', async importOriginal => {
  const actual = await importOriginal<typeof import('firebase-functions/v2/https')>();
  return {...actual, onCall: (options: any, handler: any) => {Object.assign(mocks.options, options); return actual.onCall(options, handler);}};
});
vi.mock('firebase-admin/auth', () => ({getAuth: () => ({getUser: mocks.getUser})}));
vi.mock('firebase-admin/firestore', () => ({getFirestore: () => ({})}));
vi.mock('../src/platform/firestore/firestore-store', () => ({FirestoreStore: class {transact = mocks.transact;}}));
import {miniGameContentCommand} from '../src/modules/content/mini-game-content-callables';
import {MemoryStore} from './memory-store';

const now = 1800000000000;
const data = {schemaVersion: 1, organizationId: 'gainpath', action: 'list'};
const auth = {uid: 'admin', token: {email_verified: true, email: 'admin@example.test', auth_time: now / 1000}};
const request = {app: {appId: 'synthetic'}, auth, data};
let store: MemoryStore;
beforeEach(() => {
  vi.resetAllMocks();
  vi.stubEnv('MINI_GAME_CONTENT_ORGANIZATION_ID', 'gainpath');
  store = new MemoryStore(); mocks.transact.mockImplementation(work => store.transact(work));
  store.documents.set('orgs/gainpath', {status: 'active'});
  store.documents.set('users/admin', {organizationId: 'gainpath', role: 'admin'});
  store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', userId: 'admin', role: 'admin', status: 'active', branchIds: []});
  mocks.getUser.mockResolvedValue({disabled: false, emailVerified: true, email: auth.token.email, tokensValidAfterTime: new Date(0).toUTCString()});
});
it('pins Singapore, App Check and bounded callable runtime options', () => {
  expect((miniGameContentCommand as any).__endpoint).toMatchObject({region: ['asia-southeast1'], timeoutSeconds: 60, maxInstances: 5, availableMemoryMb: 512});
  expect(mocks.options).toMatchObject({enforceAppCheck: true, concurrency: 1});
});
it('requires App Check and verified Auth before any backend access', async () => {
  for (const [req, code] of [[{data}, 'unauthenticated'], [{app: request.app, data}, 'unauthenticated'], [{...request, auth: {...auth, token: {email_verified: false}}}, 'permission-denied']] as const) {
    await expect(miniGameContentCommand.run(req as any)).rejects.toMatchObject({code});
  }
  expect(mocks.getUser).not.toHaveBeenCalled(); expect(mocks.transact).not.toHaveBeenCalled();
});
it('restricts the configured organization before database access', async () => {
  await expect(miniGameContentCommand.run({...request, data: {...data, organizationId: 'other'}} as any)).rejects.toMatchObject({code: 'permission-denied'});
  expect(mocks.getUser).not.toHaveBeenCalled(); expect(mocks.transact).not.toHaveBeenCalled();
});
it('reads real defaults with fresh Auth before and after', async () => {
  expect(await miniGameContentCommand.run(request as any)).toMatchObject({games: [{gameId: 'move-catch-v1', revision: 0}]});
  expect(mocks.getUser).toHaveBeenCalledTimes(2);
});
it.each(['disabled', 'unverified', 'changed-email', 'revoked', 'invalid-revocation'])('rejects a fresh account state %s', async mode => {
  const user = {disabled: mode === 'disabled', emailVerified: mode !== 'unverified', email: mode === 'changed-email' ? 'other@example.test' : auth.token.email,
    tokensValidAfterTime: mode === 'invalid-revocation' ? 'invalid' : new Date(mode === 'revoked' ? now + 1000 : 0).toUTCString()};
  mocks.getUser.mockResolvedValue(user);
  await expect(miniGameContentCommand.run(request as any)).rejects.toMatchObject({code: 'unauthenticated'});
  expect(mocks.transact).not.toHaveBeenCalled();
});
it.each([{email_verified: true}, {email_verified: true, email: auth.token.email, auth_time: '0'}])('requires complete signed session claims %j', async token => {
  await expect(miniGameContentCommand.run({...request, auth: {...auth, token}} as any)).rejects.toMatchObject({code: 'unauthenticated'});
  expect(mocks.getUser).not.toHaveBeenCalled();
});
it('rechecks fresh Auth before disclosing the result', async () => {
  mocks.getUser.mockResolvedValueOnce({disabled: false, emailVerified: true, email: auth.token.email}).mockResolvedValueOnce({disabled: true, emailVerified: true, email: auth.token.email});
  await expect(miniGameContentCommand.run(request as any)).rejects.toMatchObject({code: 'unauthenticated'});
});
it('maps strict request validation to invalid-argument and hides infrastructure errors', async () => {
  await expect(miniGameContentCommand.run({...request, data: {...data, points: 50}} as any)).rejects.toMatchObject({code: 'invalid-argument'});
  mocks.getUser.mockRejectedValue(new Error('private synthetic backend failure'));
  await expect(miniGameContentCommand.run(request as any)).rejects.toMatchObject({code: 'unavailable', message: expect.not.stringContaining('private')});
});
