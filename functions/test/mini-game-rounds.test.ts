import {beforeEach, expect, it} from 'vitest';
import {miniGameRounds} from '../src/modules/gamification/mini-game-rounds';
import {auth, adminAuth, seed, now, org} from './reward-journey-fixture';
import {miniGameRewards} from '../src/modules/gamification/mini-game-rewards';
import {defaultMiniGameRewardPolicy} from '../src/modules/gamification/mini-game-reward-policy';
let store: ReturnType<typeof seed>, at: number, ids: number;
const requestId = 'a'.repeat(32), gameId = 'move-catch-v1';
beforeEach(() => {store = seed(); at = now; ids = 0;});
const call = (action: string, fields: Record<string, unknown> = {}, actor = auth) => miniGameRounds(store, actor,
  {schemaVersion: 1, organizationId: org, action, ...fields}, {freshAuth: async () => {}, clock: () => at,
    randomId: () => (++ids).toString(16).padStart(32, '0')});
const begin = (id = requestId) => call('begin', {requestId: id, gameId});
const bound = (round: any) => ({attemptId: round.attemptId, challengeToken: round.challengeToken});
async function complete(round: any) {
  for (let sequence = 1; sequence <= 20; sequence++) {at += 2000;
    await call('checkpoint', {...bound(round), sequence, activeMillis: sequence * 2000, phase: 'active'});}
  return call('finish', {...bound(round), sequence: 21});
}
it('server-generated attempt and challenge survive concurrent begin retries', async () => {
  const [a,b] = await Promise.all([begin(), begin()]); expect(a).toEqual(b);
  expect(a).toMatchObject({gameId, memberId: 'member', status: 'open', sequence: 0, activeMillis: 0, physicalVerified: false, pointsAwarded: 0});
  expect(a.attemptId).not.toBe(requestId); expect(a.challengeToken).not.toBe(a.attemptId);
});
it('only one live round per Member across distinct device requests', async () => {
  await begin(); await expect(begin('b'.repeat(32))).rejects.toMatchObject({code: 'resource-exhausted'});
});
it('owned challenge, supported game and canonical Member are required', async () => {
  const r = await begin(); at += 2000;
  for (const fields of [{...bound(r), challengeToken:'f'.repeat(32)}, {...bound(r), attemptId:'f'.repeat(32)}])
    await expect(call('checkpoint', {...fields, sequence:1, activeMillis:2000, phase:'active'})).rejects.toMatchObject({code:'permission-denied'});
  await expect(call('checkpoint', {...bound(r), sequence:1, activeMillis:2000, phase:'active'}, {...auth,uid:'other'})).rejects.toMatchObject({code:'permission-denied'});
  await expect(call('begin', {requestId,gameId},adminAuth)).rejects.toMatchObject({code:'permission-denied'});
  await expect(call('begin', {requestId,gameId:'fake-game'})).rejects.toMatchObject({code:'invalid-argument'});
});
it('checkpoint retries are idempotent; changed payload and skipped order reject', async () => {
  const r=await begin(); at+=2000; const input={...bound(r),sequence:1,activeMillis:2000,phase:'active'};
  const [a,b]=await Promise.all([call('checkpoint',input),call('checkpoint',input)]);expect(a).toEqual(b);
  await expect(call('checkpoint',{...input,activeMillis:1999})).rejects.toMatchObject({code:'already-exists'});
  await expect(call('checkpoint',{...input,sequence:3})).rejects.toMatchObject({code:'failed-precondition'});
});
it('equivalent JSON field order recovers the same checkpoint receipt',async()=>{
 const r=await begin();at+=2000;
 const a=await call('checkpoint',{...bound(r),sequence:1,activeMillis:2000,phase:'active'});
 const b=await call('checkpoint',{phase:'active',activeMillis:2000,sequence:1,challengeToken:r.challengeToken,attemptId:r.attemptId});
 expect(a).toEqual(b);
});
it('fast-forwarded duration, backwards progress and repeated paused credit reject',async()=>{
 const r=await begin();at+=1000;
 await expect(call('checkpoint',{...bound(r),sequence:1,activeMillis:5000,phase:'active'})).rejects.toMatchObject({code:'failed-precondition'});
 await call('checkpoint',{...bound(r),sequence:1,activeMillis:0,phase:'paused'});at+=2000;
 await expect(call('checkpoint',{...bound(r),sequence:2,activeMillis:2000,phase:'paused'})).rejects.toMatchObject({code:'failed-precondition'});
 await call('checkpoint',{...bound(r),sequence:2,activeMillis:2000,phase:'active'});at+=2000;
 await expect(call('checkpoint',{...bound(r),sequence:3,activeMillis:1000,phase:'active'})).rejects.toMatchObject({code:'failed-precondition'});
});
it('completed timing is immutable pending evidence, never trusted camera evidence or points',async()=>{
 const r=await begin();const a=await complete(r), b=await call('finish',{...bound(r),sequence:21});expect(a).toEqual(b);
 expect(a).toMatchObject({status:'awaiting_verification',activeMillis:40000,physicalVerified:false,pointsAwarded:0});
 expect(store.documents.get(`orgs/${org}/rewardBalances/member`)?.points).toBe(1000);
 expect([...store.documents.keys()].some(p=>/miniGameVerifiedRounds|rewardAwards|miniGameRewardDailyClaims/.test(p))).toBe(false);
 const next=await begin('b'.repeat(32));expect(next.attemptId).not.toBe(r.attemptId);
});
it('timing completion cannot satisfy the future reward service even with test-only release gates',async()=>{
 const r=await begin();await complete(r);
 const policy={...defaultMiniGameRewardPolicy(),organizationId:org,revision:1,version:'mini-game-rewards-v1',updatedAtMillis:now};
 store.documents.set(`orgs/${org}/miniGameRewardPolicies/current`,policy);
 store.documents.set(`orgs/${org}/miniGameRewardReleases/current`,{schemaVersion:1,organizationId:org,policyVersion:policy.version,issuanceApproved:true,trustedProducerApproved:true});
 await expect(miniGameRewards(store,auth,{schemaVersion:1,organizationId:org,action:'claim',attemptId:r.attemptId},
  {clock:()=>at,freshAuth:async()=>{},releaseApproved:true,acceptedVerificationVersions:['timing-only-v1']})).rejects.toMatchObject({code:'failed-precondition'});
 expect(store.documents.get(`orgs/${org}/rewardBalances/member`)?.points).toBe(1000);
});
it('premature finish, reuse after abandonment and expired lease are rejected',async()=>{
 const r=await begin();await expect(call('finish',{...bound(r),sequence:1})).rejects.toMatchObject({code:'failed-precondition'});
 const abandoned=await call('abandon',bound(r));expect(abandoned.status).toBe('abandoned');
 expect(await call('abandon',bound(r))).toEqual(abandoned);
 await expect(call('finish',{...bound(r),sequence:1})).rejects.toMatchObject({code:'failed-precondition'});
 const n=await begin('b'.repeat(32));at+=90001;
 await expect(call('checkpoint',{...bound(n),sequence:1,activeMillis:1000,phase:'active'})).rejects.toMatchObject({code:'failed-precondition'});
 const newer=await begin('c'.repeat(32));expect(newer.attemptId).not.toBe(n.attemptId);
});
it.each(['score','points','cameraEvidence','verified','startedAtMillis'])('rejects client authority field %s',async field=>{
 await expect(call('begin',{requestId,gameId,[field]:1})).rejects.toMatchObject({code:'invalid-argument'});
});
it('checks current membership before and after disclosing a receipt',async()=>{
 let checks=0;
 await expect(miniGameRounds(store,auth,{schemaVersion:1,organizationId:org,action:'begin',requestId,gameId},{clock:()=>at,randomId:()=> (++ids).toString(16).padStart(32,'0'),freshAuth:async()=>{if(++checks===2)store.documents.set(`orgs/${org}/members/member`,{status:'suspended'});}})).rejects.toMatchObject({code:'permission-denied'});
});
