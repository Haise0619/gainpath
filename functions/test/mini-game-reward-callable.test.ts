import {beforeEach, expect, it, vi} from 'vitest';
const mocks = vi.hoisted(() => ({getUser: vi.fn(), transact: vi.fn(), options: {} as Record<string, unknown>}));
vi.mock('firebase-functions/v2/https', async importOriginal => {
  const actual = await importOriginal<typeof import('firebase-functions/v2/https')>();
  return {...actual, onCall: (options: any, handler: any) => {Object.assign(mocks.options, options); return actual.onCall(options, handler);}};
});
vi.mock('firebase-admin/auth', () => ({getAuth: () => ({getUser: mocks.getUser})}));
vi.mock('firebase-admin/firestore', () => ({getFirestore: () => ({})}));
vi.mock('../src/platform/firestore/firestore-store', () => ({FirestoreStore: class {transact = mocks.transact;}}));
import {miniGameRewardsCommand} from '../src/modules/gamification/mini-game-reward-callable';
import {seed, now} from './reward-journey-fixture';
const data = {schemaVersion: 1, organizationId: 'gainpath', action: 'overview'};
const auth = {uid: 'member', token: {email_verified: true, email: 'member@example.test', auth_time: now / 1000}};
const request = {app: {appId: 'synthetic'}, auth, data};
let store: ReturnType<typeof seed>;
beforeEach(() => {
  vi.resetAllMocks(); vi.stubEnv('VERIFIED_REWARDS_ORGANIZATION_ID', 'gainpath');
  store = seed(); mocks.transact.mockImplementation(work => store.transact(work));
  mocks.getUser.mockResolvedValue({disabled: false, emailVerified: true, email: auth.token.email, tokensValidAfterTime: new Date(0).toUTCString()});
});
it('registers App Check enforcement and bounded Singapore runtime', () => {
  expect((miniGameRewardsCommand as any).__endpoint).toMatchObject({region: ['asia-southeast1'], timeoutSeconds: 60, maxInstances: 5, availableMemoryMb: 512, concurrency: 1});
  expect(mocks.options.enforceAppCheck).toBe(true);
});
it('rejects missing App Check/Auth and unverified email before backend access', async () => {
  for (const [req, code] of [[{data}, 'unauthenticated'], [{app: request.app, data}, 'unauthenticated'],
    [{...request, auth: {...auth, token: {email_verified: false}}}, 'permission-denied']] as const) {
    await expect(miniGameRewardsCommand.run(req as any)).rejects.toMatchObject({code});
  }
  expect(mocks.getUser).not.toHaveBeenCalled(); expect(mocks.transact).not.toHaveBeenCalled();
});
it('rejects a different organization before identity/database access', async () => {
  await expect(miniGameRewardsCommand.run({...request, data: {...data, organizationId: 'other'}} as any)).rejects.toMatchObject({code: 'permission-denied'});
  expect(mocks.getUser).not.toHaveBeenCalled(); expect(mocks.transact).not.toHaveBeenCalled();
});
it('loads the actual held defaults with one fresh Auth check before and after', async () => {
  expect(await miniGameRewardsCommand.run(request as any)).toMatchObject({issuanceActive: false, policy: {enabled: false, dailyPointsCap: 60}});
  expect(mocks.getUser).toHaveBeenCalledTimes(2);
});
it.each(['disabled', 'unverified', 'changed-email', 'revoked', 'invalid-revocation'])('rejects changed fresh identity %s', async mode => {
  mocks.getUser.mockResolvedValue({disabled: mode === 'disabled', emailVerified: mode !== 'unverified',
    email: mode === 'changed-email' ? 'other@example.test' : auth.token.email,
    tokensValidAfterTime: mode === 'invalid-revocation' ? 'invalid' : new Date(mode === 'revoked' ? now + 1000 : 0).toUTCString()});
  await expect(miniGameRewardsCommand.run(request as any)).rejects.toMatchObject({code: 'unauthenticated'});
  expect(mocks.transact).not.toHaveBeenCalled();
});
it('rejects revoked identity before disclosing an overview', async () => {
  mocks.getUser.mockResolvedValueOnce({disabled: false, emailVerified: true, email: auth.token.email})
    .mockResolvedValueOnce({disabled: true, emailVerified: true, email: auth.token.email});
  await expect(miniGameRewardsCommand.run(request as any)).rejects.toMatchObject({code: 'unauthenticated'});
});
it('production claim is held and command validation never accepts a score', async () => {
  await expect(miniGameRewardsCommand.run({...request, data: {...data, action: 'claim', attemptId: 'local'}} as any)).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(miniGameRewardsCommand.run({...request, data: {...data, score: 999}} as any)).rejects.toMatchObject({code: 'invalid-argument'});
  expect(store.documents.get('orgs/gainpath/rewardBalances/member')?.points).toBe(1000);
});
it('hides infrastructure details', async () => {
  mocks.getUser.mockRejectedValue(new Error('private synthetic error'));
  await expect(miniGameRewardsCommand.run(request as any)).rejects.toMatchObject({code: 'unavailable', message: expect.not.stringContaining('private')});
});
it('participation overview stays separate and production participation claims remain disabled', async () => {
 const overview=await miniGameRewardsCommand.run({...request,data:{...data,action:'participationOverview'}} as any);
 expect(overview).toMatchObject({mode:'participation_demo',redeemable:false,physicalVerified:false,overview:{issuanceActive:false,demoBalance:0}});
 const result=await miniGameRewardsCommand.run({...request,data:{...data,action:'claimParticipation',attemptId:'a'.repeat(32)}} as any);
 expect(result.result.status).toBe('not-active');expect(store.documents.get('orgs/gainpath/rewardBalances/member')?.points).toBe(1000);
 await expect(miniGameRewardsCommand.run({...request,data:{...data,action:'claimParticipation',attemptId:'a'.repeat(32),score:1000}} as any)).rejects.toMatchObject({code:'invalid-argument'});
});
it('owner-approved v2 participation overview uses the spendable wallet without creating a claim',async()=>{
 const before=[...store.documents];
 const result=await miniGameRewardsCommand.run({...request,data:{...data,schemaVersion:2,action:'participationOverview'}} as any);
 expect(result).toMatchObject({schemaVersion:2,mode:'participation',redeemable:true,physicalVerified:false,overview:{issuanceActive:true,balance:1000,earnedToday:0,remainingToday:60}});
 expect([...store.documents]).toEqual(before);
});
