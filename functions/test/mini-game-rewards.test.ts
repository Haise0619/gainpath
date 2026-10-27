import {beforeEach, expect, it} from 'vitest';
import {createHash} from 'node:crypto';
import {miniGameRewards, type MiniGameRewardDependencies} from '../src/modules/gamification/mini-game-rewards';
import {auth, adminAuth, now, org, path, seed} from './reward-journey-fixture';
import {buildPointsHistory} from '../src/modules/gamification/points-history';

let store: ReturnType<typeof seed>;
const digest = (parts: string[]) => createHash('sha256').update(JSON.stringify(parts)).digest('hex');
const freshAuth = async () => {};
const run = (action: string, fields = {}, options: Partial<MiniGameRewardDependencies> = {}, actor = auth) =>
  miniGameRewards(store, actor, {schemaVersion: 1, organizationId: org, action, ...fields}, {freshAuth, clock: () => now, ...options});
const admin = (action: string, fields = {}, options: Partial<MiniGameRewardDependencies> = {}) => run(action, fields, options, adminAuth);
const fields = {requestId: 'save', baseRevision: 0, dailyPointsCap: 60, games: [{gameId: 'move-catch-v1', points: 20, dailyClaimLimit: 1}]};
const future = {releaseApproved: true, acceptedVerificationVersions: ['server-camera-v1']};
const day = '2027-01-15'; // Fixture now is 08:00 UTC, 16:00 in Malaysia.
const dailyPath = (date = day) => path('miniGameRewardDailyClaims', digest([org, 'member', date]));
const evidencePath = (attemptId: string) => path('miniGameVerifiedRounds', attemptId);
async function accepted(attemptId = 'attempt', at = now) {
  if (!store.documents.has(path('miniGameRewardPolicies', 'current'))) await admin('savePolicy', fields);
  const policy = store.documents.get(path('miniGameRewardPolicies', 'current'))!;
  store.documents.set(path('miniGameRewardReleases', 'current'), {schemaVersion: 1, organizationId: org, policyVersion: policy.version, issuanceApproved: true, trustedProducerApproved: true});
  store.documents.set(evidencePath(attemptId), {schemaVersion: 1, organizationId: org, memberId: 'member', gameId: 'move-catch-v1', attemptId,
    status: 'verified', verificationVersion: 'server-camera-v1', cameraEvidence: 'server_verified', startedAtMillis: at - 50000,
    completedAtMillis: at - 1000, activeDurationMillis: 40000, verifiedAtMillis: at});
  return {attemptId};
}
beforeEach(() => {store = seed();});

it('returns the held 20-point draft and server Malaysia day without seeding records', async () => {
  const before = [...store.documents];
  expect(await run('overview')).toMatchObject({schemaVersion: 1, organizationId: org, memberId: 'member', today: day,
    timezone: 'Asia/Kuala_Lumpur', earnedPoints: 0, remainingPoints: 60, issuanceActive: false,
    policy: {revision: 0, version: 'mini-game-rewards-draft-v1', enabled: false, dailyPointsCap: 60, games: fields.games},
    games: [{gameId: 'move-catch-v1', claimsToday: 0, eligible: false, reason: 'not-active'}]});
  expect([...store.documents]).toEqual(before);
});
it('saves disabled immutable versions and returns the original policy on idempotent retry after later edits', async () => {
  const first = await admin('savePolicy', fields);
  await admin('savePolicy', {...fields, requestId: 'edit', baseRevision: 1, dailyPointsCap: 80});
  expect(await admin('savePolicy', fields)).toEqual(first);
  expect((await admin('adminOverview')).policy).toMatchObject({revision: 2, enabled: false, dailyPointsCap: 80});
  expect([...store.documents.keys()].filter(p => p.includes('/versions/'))).toHaveLength(2);
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1000);
  await expect(admin('savePolicy', {...fields, requestId: 'stale'})).rejects.toMatchObject({code: 'aborted'});
  await expect(admin('savePolicy', {...fields, dailyPointsCap: 70})).rejects.toMatchObject({code: 'already-exists'});
});
it.each([{enabled: true}, {today: day}, {dailyPointsCap: -1}, {dailyPointsCap: 10001}, {baseRevision: -1},
  {games: [{gameId: 'unknown', points: 20, dailyClaimLimit: 1}]}, {games: []},
  {games: [{gameId: 'move-catch-v1', points: 1001, dailyClaimLimit: 1}]},
  {games: [{gameId: 'move-catch-v1', points: 20, dailyClaimLimit: 2}]},
  {games: [{gameId: 'move-catch-v1', points: 20, dailyClaimLimit: 1, enabled: true}]}])('rejects invalid or activation configuration %j', async patch => {
  await expect(admin('savePolicy', {...fields, ...patch})).rejects.toThrow();
  expect(store.documents.has(path('miniGameRewardPolicies', 'current'))).toBe(false);
});
it('allows explicit zero draft values without enabling issuance or changing balances', async () => {
  expect((await admin('savePolicy', {...fields, dailyPointsCap: 0, games: [{gameId: 'move-catch-v1', points: 0, dailyClaimLimit: 0}]})).policy).toMatchObject({enabled: false, dailyPointsCap: 0});
  expect((await run('overview')).remainingPoints).toBe(0);
});
it('requires canonical active Member/Admin authority and current lifecycle', async () => {
  await expect(run('adminOverview')).rejects.toMatchObject({code: 'permission-denied'});
  await expect(run('overview', {}, {}, adminAuth)).rejects.toMatchObject({code: 'permission-denied'});
  store.documents.set('users/member', {organizationId: org, accountLifecycle: {schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: now / 1000 + 1}});
  await expect(run('overview')).rejects.toMatchObject({code: 'permission-denied'});
});
it('rechecks external identity and canonical authority after reading', async () => {
  let calls = 0;
  await expect(run('overview', {}, {freshAuth: async () => {if (++calls === 2) store.documents.set(path('members', 'member'), {role: 'member', status: 'suspended', branchIds: []});}})).rejects.toMatchObject({code: 'permission-denied'});
  expect(calls).toBe(2);
});
it('production hold rejects valid-looking evidence and a release record without writes', async () => {
  const request = await accepted(); const before = [...store.documents];
  await expect(run('claim', request)).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(run('claim', request, {releaseApproved: true})).rejects.toMatchObject({code: 'failed-precondition'});
  expect([...store.documents]).toEqual(before);
});
it.each([{score: 999}, {points: 20}, {today: day}, {gameId: 'move-catch-v1'}, {memberId: 'other'}, {policyVersion: 'mine'}])('rejects client earning/evidence fields %j', async patch => {
  await expect(run('claim', {attemptId: 'local-only', ...patch}, future)).rejects.toThrow();
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1000);
});
it('future injected acceptance awards atomically once across concurrent device retries and preserves the shared wallet', async () => {
  store.documents.set(path('appCheckInProfiles', 'member'), {sentinel: 'preserve'});
  const request = await accepted();
  const replies = await Promise.all([run('claim', request, future), run('claim', request, future)]);
  expect(replies[0].awardId).toBe(replies[1].awardId);
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1020);
  expect(store.documents.get(dailyPath())).toMatchObject({points: 20, claimsByGame: {'move-catch-v1': 1}});
  const awards = [...store.documents].filter(([p]) => p.includes('/rewardAwards/'));
  expect(awards).toHaveLength(1);
  expect(awards[0][1]).toMatchObject({points: 20, basePoints: 20, premiumBonus: false, policySnapshot: {enabled: false, dailyPointsCap: 60}});
  expect(buildPointsHistory(org, 'member', 1020, now, {claims: [], awards: [{id: String(awards[0][1].awardId), data: awards[0][1]}], adjustments: [], redemptions: []}).entries[0].points).toBe(20);
  expect(store.documents.get(path('appCheckInProfiles', 'member'))).toEqual({sentinel: 'preserve'});
});
it('counts every game type toward one shared cap and rejects partial point awards', async () => {
  const request = await accepted();
  store.documents.set(dailyPath(), {schemaVersion: 1, organizationId: org, memberId: 'member', timezone: 'Asia/Kuala_Lumpur', date: day, points: 45, claimsByGame: {'future-game': 1}});
  expect(await run('overview')).toMatchObject({earnedPoints: 45, remainingPoints: 15, games: [{claimsToday: 0, reason: 'not-active'}]});
  await expect(run('claim', request, future)).rejects.toMatchObject({code: 'resource-exhausted'});
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1000);
});
it('per-game cap survives simultaneous different attempts and policy revisions', async () => {
  const first = await accepted('first'), second = await accepted('second');
  const result = await Promise.allSettled([run('claim', first, future), run('claim', second, future)]);
  expect(result.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  await admin('savePolicy', {...fields, requestId: 'edit', baseRevision: 1, dailyPointsCap: 100});
  await accepted('third');
  await expect(run('claim', {attemptId: 'third'}, future)).rejects.toMatchObject({code: 'resource-exhausted'});
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1020);
});
it('recovers an immutable receipt after policy changes, the next day and the hold returning', async () => {
  const request = await accepted(); const awarded = await run('claim', request, future);
  store.documents.set(path('miniGameRewardPolicies', 'current'), {invalid: true});
  expect(await run('claim', request, {clock: () => now + 86400000})).toMatchObject({awardId: awarded.awardId, status: 'already-awarded', points: 20});
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1020);
});
it.each([{status: 'local_completed'}, {memberId: 'other'}, {gameId: 'unknown'}, {verificationVersion: 'client'},
  {cameraEvidence: 'local'}, {activeDurationMillis: 39999}, {activeDurationMillis: 50000}, {completedAtMillis: now + 1},
  {startedAtMillis: now - 20000}, {verifiedAtMillis: now - 2000}])('rejects invalid future evidence %j', async patch => {
  const request = await accepted(); store.documents.set(evidencePath('attempt'), {...store.documents.get(evidencePath('attempt')), ...patch});
  await expect(run('claim', request, future)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1000);
});
it('requires an approved release and a server-produced attempt', async () => {
  await expect(run('claim', {attemptId: 'local'}, future)).rejects.toMatchObject({code: 'failed-precondition'});
  const request = await accepted(); store.documents.delete(path('miniGameRewardReleases', 'current'));
  await expect(run('claim', request, future)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('uses Malaysia midnight for separate daily counters and refuses yesterday evidence today', async () => {
  const beforeMidnight = Date.parse('2027-01-15T15:59:59Z'), afterMidnight = Date.parse('2027-01-15T16:01:00Z');
  const first = await accepted('first', beforeMidnight); await run('claim', first, {...future, clock: () => beforeMidnight});
  expect((await run('overview', {}, {clock: () => afterMidnight})).today).toBe('2027-01-16');
  await accepted('old', beforeMidnight);
  await expect(run('claim', {attemptId: 'old'}, {...future, clock: () => afterMidnight})).rejects.toMatchObject({code: 'failed-precondition'});
  await run('claim', await accepted('next', afterMidnight), {...future, clock: () => afterMidnight});
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1040);
  expect(store.documents.has(dailyPath('2027-01-16'))).toBe(true);
});
it('awards exactly up to the shared cap including retained usage from future game types', async () => {
  const request = await accepted();
  store.documents.set(dailyPath(), {schemaVersion: 1, organizationId: org, memberId: 'member', timezone: 'Asia/Kuala_Lumpur', date: day,
    points: 40, claimsByGame: {'future-game-one': 1, 'future-game-two': 1}});
  expect(await run('claim', request, future)).toMatchObject({points: 20, status: 'awarded'});
  expect(await run('overview')).toMatchObject({earnedPoints: 60, remainingPoints: 0, games: [{claimsToday: 1, eligible: false}]});
  expect(store.documents.get(dailyPath())?.claimsByGame).toEqual({'future-game-one': 1, 'future-game-two': 1, 'move-catch-v1': 1});
});
it('a lowered policy cap never resets or hides previously awarded points', async () => {
  await run('claim', await accepted(), future);
  await admin('savePolicy', {...fields, requestId: 'lower', baseRevision: 1, dailyPointsCap: 10});
  expect(await run('overview')).toMatchObject({earnedPoints: 20, remainingPoints: 0, policy: {dailyPointsCap: 10}, games: [{claimsToday: 1}]});
});
it.each([{points: -1}, {memberId: 'other'}, {timezone: 'UTC'}, {claimsByGame: {'move-catch-v1': -1}}, {claimsByGame: []}])('fails closed on malformed shared counters %j', async patch => {
  const request = await accepted();
  store.documents.set(dailyPath(), {schemaVersion: 1, organizationId: org, memberId: 'member', timezone: 'Asia/Kuala_Lumpur', date: day,
    points: 0, claimsByGame: {}, ...patch});
  await expect(run('overview')).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(run('claim', request, future)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1000);
});
it('does not spend a globally consumed attempt even if the claim receipt is absent', async () => {
  const request = await accepted();
  store.documents.set(path('miniGameRewardAttemptClaims', digest([org, 'attempt'])), {memberId: 'other'});
  await expect(run('claim', request, future)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('preserves a concurrent daily check-in credit and its separate receipt', async () => {
  const {appCheckInCommand} = await import('../src/modules/gamification/app-check-in-service');
  const request = await accepted();
  await Promise.all([run('claim', request, future), appCheckInCommand(store, auth, {schemaVersion: 1, organizationId: org, action: 'claim'}, () => now)]);
  expect(store.documents.get(path('rewardBalances', 'member'))?.points).toBe(1070);
  expect(store.documents.get(path('appCheckInProfiles', 'member') + '/claims/' + day)?.points).toBe(50);
  expect(store.documents.get(dailyPath())?.points).toBe(20);
});
it('requires active canonical authority before recovering an old claim receipt', async () => {
  const request = await accepted(); await run('claim', request, future);
  store.documents.set(path('members', 'member'), {...store.documents.get(path('members', 'member')), status: 'suspended'});
  await expect(run('claim', request)).rejects.toMatchObject({code: 'permission-denied'});
});
