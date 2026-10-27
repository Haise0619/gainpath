import {createHash} from 'node:crypto';
import {requireActiveMembership, requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {readAll, type DocumentData, type DocumentStore, type TransactionPort} from '../../platform/firestore/store';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {defaultMiniGameRewardPolicy, miniGameRewardDate, parseMiniGameRewardPolicy, rewardInteger, rewardTime,
  validateMiniGameRewardFields, MINI_GAME_REWARD_ACCEPTED_VERIFICATION_VERSIONS, MINI_GAME_REWARD_RELEASE_APPROVED,
  MINI_GAME_REWARD_TIMEZONE, type MiniGameRewardPolicy} from './mini-game-reward-policy';
export {defaultMiniGameRewardPolicy} from './mini-game-reward-policy';

export type MiniGameRewardAuth = {uid: string; token: Record<string, unknown>};
export interface MiniGameRewardDependencies {
  freshAuth(auth: MiniGameRewardAuth): Promise<void>;
  clock?: () => number;
  /** Test-only injection. Production entrypoint supplies the frozen source gates. */
  releaseApproved?: boolean;
  acceptedVerificationVersions?: readonly string[];
}
export interface MiniGameRewardOverview {
  schemaVersion: 1; organizationId: string; memberId: string; timezone: typeof MINI_GAME_REWARD_TIMEZONE;
  today: string; policy: MiniGameRewardPolicy; earnedPoints: number; remainingPoints: number; issuanceActive: false;
  games: {gameId: string; claimsToday: number; eligible: false; reason: 'not-active'}[];
}
const digest = (parts: unknown[]) => createHash('sha256').update(JSON.stringify(parts)).digest('hex');
const identifier = (value: unknown): value is string => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const fail = (message = 'Mini-game rewards are not active. Trusted game acceptance and a separate release are required.') => new DomainError('failed-precondition', message);
const deny = () => new DomainError('permission-denied', 'Current verified organization authority is required.');
function request(raw: unknown): DocumentData {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new InputValidationError('Mini-game reward command required.');
  const data = raw as DocumentData;
  const actions: Record<string, string[]> = {overview: [], adminOverview: [], savePolicy: ['requestId', 'baseRevision', 'dailyPointsCap', 'games'], claim: ['attemptId']};
  if (data.schemaVersion !== 1 || typeof data.action !== 'string' || !Object.hasOwn(actions, data.action)) throw new InputValidationError('Unsupported mini-game reward command.');
  const fields = ['schemaVersion', 'organizationId', 'action', ...actions[data.action]];
  if (Object.keys(data).length !== fields.length || Object.keys(data).some(key => !fields.includes(key))) throw new InputValidationError('Invalid mini-game reward command fields.');
  requiredIdentifier(data.organizationId, 'organizationId');
  if (data.action === 'savePolicy') {
    requiredIdentifier(data.requestId, 'requestId');
    if (!rewardInteger(data.baseRevision, 0, Number.MAX_SAFE_INTEGER - 1)) throw new InputValidationError('Invalid reward policy revision.');
    validateMiniGameRewardFields(data);
  }
  if (data.action === 'claim') requiredIdentifier(data.attemptId, 'attemptId');
  return data;
}
async function authorize(tx: TransactionPort, auth: MiniGameRewardAuth, org: string, admin: boolean) {
  const [user, member, organization] = await readAll(tx, [`users/${auth.uid}`, `orgs/${org}/members/${auth.uid}`, `orgs/${org}`]);
  const role = requireActiveMembership(member).role;
  if (role !== (admin ? 'admin' : 'member') || organization?.status !== 'active' || user?.organizationId !== org
      || (user.role !== undefined && user.role !== role) || member?.organizationId !== org
      || (member.userId !== undefined && member.userId !== auth.uid)) throw deny();
  const lifecycle = user.accountLifecycle as DocumentData | undefined;
  if (lifecycle !== undefined && (!lifecycle || lifecycle.schemaVersion !== 1 || lifecycle.state !== 'active'
      || lifecycle.revocationPending !== false || !rewardInteger(lifecycle.sessionNotBeforeSeconds)
      || (lifecycle.sessionNotBeforeSeconds > 0 && (!rewardInteger(auth.token.auth_time)
        || auth.token.auth_time < lifecycle.sessionNotBeforeSeconds)))) throw deny();
}
function daily(data: DocumentData | undefined, org: string, uid: string, date: string) {
  if (!data) return {points: 0, claimsByGame: {} as Record<string, number>};
  if (data.schemaVersion !== 1 || data.organizationId !== org || data.memberId !== uid || data.date !== date
      || data.timezone !== MINI_GAME_REWARD_TIMEZONE || !rewardInteger(data.points)
      || !data.claimsByGame || typeof data.claimsByGame !== 'object' || Array.isArray(data.claimsByGame)) throw fail('Invalid daily mini-game reward record.');
  const counts = data.claimsByGame as DocumentData;
  // Include unknown/future registry IDs: editing or expanding a policy never resets the shared cap.
  if (Object.keys(counts).length > 100 || Object.entries(counts).some(([gameId, count]) => !identifier(gameId) || !rewardInteger(count, 1))) throw fail('Invalid per-game reward usage.');
  return {points: data.points, claimsByGame: {...counts} as Record<string, number>};
}
function priorAward(data: DocumentData, org: string, uid: string, attemptId: string, awardId: string) {
  if (data.schemaVersion !== 1 || data.organizationId !== org || data.memberId !== uid || data.attemptId !== attemptId
      || data.eventId !== attemptId || data.awardId !== awardId || data.sourceId !== 'mini_game_completion'
      || data.producerVersion !== 'mini-game-reward-v1' || !identifier(data.gameId) || !identifier(data.policyVersion)
      || !rewardInteger(data.points, 1, 1000) || data.basePoints !== data.points || data.premiumBonus !== false
      || !rewardTime(data.awardedAtMillis) || !rewardTime(data.occurredAtMillis) || data.occurredAtMillis > data.awardedAtMillis
      || !data.policySnapshot || typeof data.policySnapshot !== 'object' || Array.isArray(data.policySnapshot)) throw fail('Inconsistent mini-game reward receipt.');
  const snapshot = parseMiniGameRewardPolicy({...data.policySnapshot as DocumentData, organizationId: org}, org);
  if (snapshot.version !== data.policyVersion || snapshot.games.find(game => game.gameId === data.gameId)?.points !== data.points) throw fail('Inconsistent reward policy snapshot.');
  return {schemaVersion: 1, organizationId: org, memberId: uid, status: 'already-awarded', points: data.points, awardId, policyVersion: data.policyVersion};
}
/** Draft/status only in production. No producer, release switch or local-score acceptance exists here. */
export async function miniGameRewards(store: DocumentStore, auth: MiniGameRewardAuth | undefined, raw: unknown,
  deps: MiniGameRewardDependencies): Promise<Record<string, any>> {
  requireVerifiedEmail(auth);
  const data = request(raw), org = String(data.organizationId), uid = requiredIdentifier(auth!.uid, 'uid');
  const isAdmin = data.action === 'adminOverview' || data.action === 'savePolicy';
  const time = () => {const at = (deps.clock ?? Date.now)(); miniGameRewardDate(at); return at;};
  await deps.freshAuth(auth!);
  const result = await store.transact(async tx => {
    await authorize(tx, auth!, org, isAdmin);
    const now = time(), today = miniGameRewardDate(now), path = (kind: string, id: string) => `orgs/${org}/${kind}/${id}`;
    const policyPath = path('miniGameRewardPolicies', 'current');
    if (data.action === 'claim') {
      const attemptId = String(data.attemptId), awardId = 'mini_game_' + digest([org, uid, attemptId]);
      const awardPath = path('rewardAwards', awardId), prior = await tx.get(awardPath);
      if (prior) return priorAward(prior, org, uid, attemptId, awardId);
      if (!(deps.releaseApproved ?? MINI_GAME_REWARD_RELEASE_APPROVED)) throw fail();
      const versions = deps.acceptedVerificationVersions ?? MINI_GAME_REWARD_ACCEPTED_VERIFICATION_VERSIONS;
      if (!versions.length) throw fail();
      const policy = parseMiniGameRewardPolicy(await tx.get(policyPath), org), release = await tx.get(path('miniGameRewardReleases', 'current'));
      if (!release || release.schemaVersion !== 1 || release.organizationId !== org || release.policyVersion !== policy.version
          || release.issuanceApproved !== true || release.trustedProducerApproved !== true) throw fail();
      const evidence = await tx.get(path('miniGameVerifiedRounds', attemptId));
      if (!evidence || evidence.schemaVersion !== 1 || evidence.organizationId !== org || evidence.memberId !== uid
          || evidence.attemptId !== attemptId || evidence.status !== 'verified' || !identifier(evidence.gameId)
          || typeof evidence.verificationVersion !== 'string' || !versions.includes(evidence.verificationVersion)
          || evidence.cameraEvidence !== 'server_verified' || !rewardTime(evidence.startedAtMillis)
          || !rewardTime(evidence.completedAtMillis) || !rewardTime(evidence.verifiedAtMillis)
          || evidence.completedAtMillis > evidence.verifiedAtMillis || evidence.verifiedAtMillis > now
          || !rewardInteger(evidence.activeDurationMillis, 40000) || evidence.completedAtMillis - evidence.startedAtMillis < evidence.activeDurationMillis
          || miniGameRewardDate(evidence.completedAtMillis) !== today) throw fail('A trusted completed camera game round from today is required.');
      const game = policy.games.find(game => game.gameId === evidence.gameId);
      if (!game || !game.points || !game.dailyClaimLimit) throw fail('This game has no active reward configuration.');
      const dailyPath = path('miniGameRewardDailyClaims', digest([org, uid, today]));
      const consumedPath = path('miniGameRewardAttemptClaims', digest([org, attemptId]));
      const balancePath = path('rewardBalances', uid);
      const [dailyData, consumed, balance] = await readAll(tx, [dailyPath, consumedPath, balancePath]);
      if (consumed) throw fail('This verified game attempt has already been consumed.');
      const usage = daily(dailyData, org, uid, today), count = usage.claimsByGame[game.gameId] ?? 0;
      if (count >= game.dailyClaimLimit || usage.points + game.points > policy.dailyPointsCap) throw new DomainError('resource-exhausted', 'Daily mini-game reward limit reached. You can continue playing.');
      if (balance && (balance.schemaVersion !== 1 || balance.organizationId !== org || balance.memberId !== uid
          || !rewardInteger(balance.points) || !Array.isArray(balance.recentRedemptionIds)
          || balance.recentRedemptionIds.length > 50 || !balance.recentRedemptionIds.every(identifier))) throw fail('Invalid reward balance.');
      const points = Number(balance?.points ?? 0) + game.points;
      if (!rewardInteger(points) || !rewardInteger(usage.points + game.points)) throw fail('Reward balance overflow.');
      const receipt = {schemaVersion: 1, organizationId: org, memberId: uid, awardId, eventId: attemptId, attemptId,
        gameId: game.gameId, sourceId: 'mini_game_completion', producerVersion: 'mini-game-reward-v1',
        verificationVersion: evidence.verificationVersion, policyVersion: policy.version, policySnapshot: policy,
        timezone: MINI_GAME_REWARD_TIMEZONE, date: today, occurredAtMillis: evidence.completedAtMillis,
        awardedAtMillis: now, basePoints: game.points, points: game.points, premiumBonus: false, tierEvidence: 'no_multipliers'};
      tx.create(awardPath, receipt);
      tx.create(consumedPath, {schemaVersion: 1, organizationId: org, memberId: uid, attemptId, gameId: game.gameId, awardId, claimedAtMillis: now});
      tx.set(dailyPath, {schemaVersion: 1, organizationId: org, memberId: uid, timezone: MINI_GAME_REWARD_TIMEZONE, date: today,
        points: usage.points + game.points, claimsByGame: {...usage.claimsByGame, [game.gameId]: count + 1}});
      tx.set(balancePath, {...balance, schemaVersion: 1, organizationId: org, memberId: uid, points,
        recentRedemptionIds: balance?.recentRedemptionIds ?? [], updatedAtMillis: now});
      return {schemaVersion: 1, organizationId: org, memberId: uid, status: 'awarded', points: game.points, awardId, policyVersion: policy.version};
    }
    const adminResponse = (policy: MiniGameRewardPolicy) => ({schemaVersion: 1, organizationId: org, policy, issuanceActive: false});
    if (data.action === 'savePolicy') {
      const fields = validateMiniGameRewardFields(data), fingerprint = digest([data.baseRevision, fields.dailyPointsCap, fields.games]);
      const operationPath = path('miniGameRewardPolicyRequests', digest([uid, data.requestId])), prior = await tx.get(operationPath);
      if (prior) {
        if (prior.schemaVersion !== 1 || prior.organizationId !== org || prior.adminId !== uid || prior.requestId !== data.requestId
            || !prior.policy || typeof prior.policy !== 'object' || Array.isArray(prior.policy)) throw fail('Invalid policy save receipt.');
        if (prior.fingerprint !== fingerprint) throw new DomainError('already-exists', 'Request already used for another reward policy.');
        const policy = parseMiniGameRewardPolicy({...prior.policy as DocumentData, organizationId: org}, org);
        if (policy.revision !== Number(data.baseRevision) + 1 || policy.dailyPointsCap !== fields.dailyPointsCap
            || JSON.stringify(policy.games) !== JSON.stringify(fields.games)) throw fail('Inconsistent policy save receipt.');
        return adminResponse(policy);
      }
      const current = parseMiniGameRewardPolicy(await tx.get(policyPath), org);
      if (current.revision !== data.baseRevision) throw new DomainError('aborted', 'Reward policy changed. Reload before editing.');
      const policy: MiniGameRewardPolicy = {...defaultMiniGameRewardPolicy(), ...fields, revision: current.revision + 1,
        version: `mini-game-rewards-v${current.revision + 1}`, updatedAtMillis: now};
      tx.set(policyPath, {...policy, organizationId: org, updatedBy: uid});
      tx.create(`${policyPath}/versions/${policy.version}`, {...policy, organizationId: org, updatedBy: uid});
      tx.create(operationPath, {schemaVersion: 1, organizationId: org, adminId: uid, requestId: data.requestId, fingerprint, policy, savedAtMillis: now});
      return adminResponse(policy);
    }
    const policy = parseMiniGameRewardPolicy(await tx.get(policyPath), org);
    if (data.action === 'adminOverview') return adminResponse(policy);
    const usage = daily(await tx.get(path('miniGameRewardDailyClaims', digest([org, uid, today]))), org, uid, today);
    const overview: MiniGameRewardOverview = {schemaVersion: 1, organizationId: org, memberId: uid, timezone: MINI_GAME_REWARD_TIMEZONE,
      today, policy, earnedPoints: usage.points, remainingPoints: Math.max(0, policy.dailyPointsCap - usage.points), issuanceActive: false,
      games: policy.games.map(game => ({gameId: game.gameId, claimsToday: usage.claimsByGame[game.gameId] ?? 0, eligible: false, reason: 'not-active'}))};
    return overview;
  });
  await deps.freshAuth(auth!);
  await store.transact(tx => authorize(tx, auth!, org, isAdmin));
  return result;
}
