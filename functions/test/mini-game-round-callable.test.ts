import {beforeEach, expect, it, vi} from 'vitest';
const mocks = vi.hoisted(() => ({getUser: vi.fn(), transact: vi.fn(), options: {} as Record<string, unknown>}));
vi.mock('firebase-functions/v2/https', async importOriginal => {
  const actual = await importOriginal<typeof import('firebase-functions/v2/https')>();
  return {...actual, onCall: (options: any, handler: any) => {Object.assign(mocks.options, options); return actual.onCall(options, handler);}};
});
vi.mock('firebase-admin/auth', () => ({getAuth: () => ({getUser: mocks.getUser})}));
vi.mock('firebase-admin/firestore', () => ({getFirestore: () => ({})}));
vi.mock('../src/platform/firestore/firestore-store', () => ({FirestoreStore: class {transact = mocks.transact;}}));
import {miniGameRoundCommand} from '../src/modules/gamification/mini-game-round-callable';
import {seed, now} from './reward-journey-fixture';
const data = {schemaVersion: 1, organizationId: 'gainpath', action: 'begin', requestId: 'a'.repeat(32), gameId: 'move-catch-v1'};
const auth = {uid: 'member', token: {email_verified: true, email: 'member@example.test', auth_time: now / 1000}};
const request = {app: {appId: 'synthetic'}, auth, data};
let store: ReturnType<typeof seed>;
beforeEach(() => {
  vi.resetAllMocks(); vi.stubEnv('VERIFIED_REWARDS_ORGANIZATION_ID', 'gainpath');
  store = seed(); mocks.transact.mockImplementation(work => store.transact(work));
  mocks.getUser.mockResolvedValue({disabled: false, emailVerified: true, email: auth.token.email, tokensValidAfterTime: new Date(0).toUTCString()});
});
it('registers App Check enforcement and bounded Singapore runtime', () => {
  expect((miniGameRoundCommand as any).__endpoint).toMatchObject({region: ['asia-southeast1'], timeoutSeconds: 30, maxInstances: 5, availableMemoryMb: 512, concurrency: 1});
  expect(mocks.options.enforceAppCheck).toBe(true);
});
it('rejects missing App Check/Auth and unverified email before backend access', async () => {
  for (const [req, code] of [[{data}, 'unauthenticated'], [{app: request.app, data}, 'unauthenticated'],
    [{...request, auth: {...auth, token: {email_verified: false}}}, 'permission-denied']] as const) {
    await expect(miniGameRoundCommand.run(req as any)).rejects.toMatchObject({code});
  }
  expect(mocks.getUser).not.toHaveBeenCalled(); expect(mocks.transact).not.toHaveBeenCalled();
});
it('rejects a different organization before identity/database access', async () => {
  await expect(miniGameRoundCommand.run({...request, data: {...data, organizationId: 'other'}} as any)).rejects.toMatchObject({code: 'permission-denied'});
  expect(mocks.getUser).not.toHaveBeenCalled(); expect(mocks.transact).not.toHaveBeenCalled();
});
it('creates only unverified timing metadata with one fresh Auth check before and after', async () => {
  expect(await miniGameRoundCommand.run(request as any)).toMatchObject({status: 'open', physicalVerified: false, pointsAwarded: 0});
  expect(mocks.getUser).toHaveBeenCalledTimes(2);
});
it.each(['disabled', 'unverified', 'changed-email', 'revoked', 'invalid-revocation'])('rejects changed fresh identity %s', async mode => {
  mocks.getUser.mockResolvedValue({disabled: mode === 'disabled', emailVerified: mode !== 'unverified',
    email: mode === 'changed-email' ? 'other@example.test' : auth.token.email,
    tokensValidAfterTime: mode === 'invalid-revocation' ? 'invalid' : new Date(mode === 'revoked' ? now + 1000 : 0).toUTCString()});
  await expect(miniGameRoundCommand.run(request as any)).rejects.toMatchObject({code: 'unauthenticated'});
  expect(mocks.transact).not.toHaveBeenCalled();
});
it('rejects revoked identity before disclosing an overview', async () => {
  mocks.getUser.mockResolvedValueOnce({disabled: false, emailVerified: true, email: auth.token.email})
    .mockResolvedValueOnce({disabled: true, emailVerified: true, email: auth.token.email});
  await expect(miniGameRoundCommand.run(request as any)).rejects.toMatchObject({code: 'unauthenticated'});
});
it('unsupported claim and client score fields cannot authorize points', async () => {
  await expect(miniGameRoundCommand.run({...request, data: {...data, action: 'claim', attemptId: 'local'}} as any)).rejects.toMatchObject({code: 'invalid-argument'});
  await expect(miniGameRoundCommand.run({...request, data: {...data, score: 999}} as any)).rejects.toMatchObject({code: 'invalid-argument'});
  expect(store.documents.get('orgs/gainpath/rewardBalances/member')?.points).toBe(1000);
});
it('hides infrastructure details', async () => {
  mocks.getUser.mockRejectedValue(new Error('private synthetic error'));
  await expect(miniGameRoundCommand.run(request as any)).rejects.toMatchObject({code: 'unavailable', message: expect.not.stringContaining('private')});
});
