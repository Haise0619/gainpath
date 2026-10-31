import {createHash, randomBytes} from 'node:crypto';
import {requireActiveMembership, requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {readAll, type DocumentData, type DocumentStore, type TransactionPort} from '../../platform/firestore/store';
import {requiredIdentifier} from '../../platform/validation';
import {rewardInteger, rewardTime} from './mini-game-reward-policy';

type Auth = {uid: string; token: Record<string, unknown>};
type Status = 'open' | 'awaiting_verification' | 'abandoned';
export interface MiniGameRoundSnapshot {
  schemaVersion: 1; organizationId: string; memberId: string; gameId: 'move-catch-v1' | 'reach-tap-v1'; attemptId: string;
  challengeToken: string; status: Status; sequence: number; activeMillis: number;
  startedAtMillis: number; leaseUntilMillis: number; expiresAtMillis: number;
  physicalVerified: false; pointsAwarded: 0;
}
interface Round extends MiniGameRoundSnapshot {lastAtMillis: number; phase: 'active' | 'paused'; requestId: string}
interface Dependencies {freshAuth(auth: Auth): Promise<void>; clock?: () => number; randomId?: () => string}
const digest = (...parts: unknown[]) => createHash('sha256').update(JSON.stringify(parts)).digest('hex');
const hex = (v: unknown): v is string => typeof v === 'string' && /^[a-f0-9]{32}$/.test(v);
const fail = (message = 'Round timing could not be confirmed.') => new DomainError('failed-precondition', message);
const deny = () => new DomainError('permission-denied', 'Current Member and owned round challenge required.');
const LEASE = 90000, MAX_LIFETIME = 15 * 60000;
function parse(raw: unknown): DocumentData {
  const invalid = () => new DomainError('invalid-argument', 'Invalid mini-game round command.');
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw invalid();
  const d = raw as DocumentData;
  const actions: Record<string, string[]> = {begin: ['requestId', 'gameId'],
    checkpoint: ['attemptId', 'challengeToken', 'sequence', 'activeMillis', 'phase'],
    finish: ['attemptId', 'challengeToken', 'sequence'], abandon: ['attemptId', 'challengeToken']};
  if (d.schemaVersion !== 1 || typeof d.action !== 'string' || !Object.hasOwn(actions, d.action)) throw invalid();
  const keys = ['schemaVersion', 'organizationId', 'action', ...actions[d.action]];
  if (Object.keys(d).length !== keys.length || Object.keys(d).some(k => !keys.includes(k))) throw invalid();
  try {requiredIdentifier(d.organizationId, 'organizationId');} catch {throw invalid();}
  if (d.action === 'begin') {if (!hex(d.requestId) || !['move-catch-v1','reach-tap-v1'].includes(String(d.gameId))) throw invalid();}
  else {
    if (!hex(d.attemptId) || !hex(d.challengeToken)) throw invalid();
    if (d.action !== 'abandon' && !rewardInteger(d.sequence, 1, 361)) throw invalid();
    if (d.action === 'checkpoint' && (!rewardInteger(d.activeMillis, 0, 40000) || !['active', 'paused'].includes(String(d.phase)))) throw invalid();
  }
  return d;
}
async function authorize(tx: TransactionPort, auth: Auth, org: string) {
  const [member, user, organization] = await readAll(tx, [`orgs/${org}/members/${auth.uid}`, `users/${auth.uid}`, `orgs/${org}`]);
  const role = requireActiveMembership(member).role;
  if (role !== 'member' || member?.organizationId !== org || (member.userId !== undefined && member.userId !== auth.uid)
      || user?.organizationId !== org || (user.role !== undefined && user.role !== role) || organization?.status !== 'active') throw deny();
  const l = user.accountLifecycle as DocumentData | undefined;
  if (l !== undefined && (!l || l.schemaVersion !== 1 || l.state !== 'active' || l.revocationPending !== false
    || !rewardInteger(l.sessionNotBeforeSeconds) || (l.sessionNotBeforeSeconds > 0
      && (!rewardInteger(auth.token.auth_time) || auth.token.auth_time < l.sessionNotBeforeSeconds)))) throw deny();
}
function readRound(data: DocumentData | undefined, org: string, uid: string, attemptId: string): Round {
  if (!data || data.schemaVersion !== 1 || data.organizationId !== org || data.memberId !== uid || data.attemptId !== attemptId) throw deny();
  if (!['move-catch-v1','reach-tap-v1'].includes(String(data.gameId)) || !hex(data.challengeToken) || !hex(data.requestId)
    || !['open', 'awaiting_verification', 'abandoned'].includes(String(data.status))
    || !rewardInteger(data.sequence, 0, 361) || !rewardInteger(data.activeMillis, 0, 40000)
    || !rewardTime(data.startedAtMillis) || !rewardTime(data.lastAtMillis) || !rewardTime(data.leaseUntilMillis)
    || !rewardTime(data.expiresAtMillis) || data.lastAtMillis < data.startedAtMillis
    || data.expiresAtMillis !== data.startedAtMillis + MAX_LIFETIME || data.leaseUntilMillis > data.expiresAtMillis
    || !['active', 'paused'].includes(String(data.phase)) || data.physicalVerified !== false || data.pointsAwarded !== 0) throw fail();
  return data as unknown as Round;
}
function snapshot(r: Round): MiniGameRoundSnapshot {
  const {schemaVersion, organizationId, memberId, gameId, attemptId, challengeToken, status, sequence, activeMillis,
    startedAtMillis, leaseUntilMillis, expiresAtMillis, physicalVerified, pointsAwarded} = r;
  return {schemaVersion, organizationId, memberId, gameId, attemptId, challengeToken, status, sequence, activeMillis,
    startedAtMillis, leaseUntilMillis, expiresAtMillis, physicalVerified, pointsAwarded};
}
/** Server timing checks only. Never writes trusted camera evidence, awards, policy or balances. */
export async function miniGameRounds(store: DocumentStore, auth: Auth | undefined, raw: unknown, deps: Dependencies): Promise<MiniGameRoundSnapshot> {
  requireVerifiedEmail(auth); const d = parse(raw), org = String(d.organizationId), uid = requiredIdentifier(auth!.uid, 'uid');
  await deps.freshAuth(auth!);
  const now = (deps.clock ?? Date.now)(); if (!rewardTime(now) || now > 8640000000000000 - MAX_LIFETIME) throw fail();
  const id = deps.randomId ?? (() => randomBytes(16).toString('hex'));
  // Generate outside the retryable transaction. A repeated begin recovers its persisted challenge.
  const candidate = d.action === 'begin' ? {attemptId: id(), challengeToken: id()} : null;
  if (candidate && (!hex(candidate.attemptId) || !hex(candidate.challengeToken) || candidate.attemptId === candidate.challengeToken)) throw fail();
  const result = await store.transact(async tx => {
    await authorize(tx, auth!, org);
    const base = `orgs/${org}`, leasePath = `${base}/miniGameRoundLeases/${digest(uid)}`;
    const roundPath = (attempt: string) => `${base}/miniGameRoundSessions/${attempt}`;
    if (d.action === 'begin') {
      const operationPath = `${base}/miniGameRoundRequests/${digest(uid, d.requestId)}`, prior = await tx.get(operationPath);
      if (prior) {
        if (prior.schemaVersion !== 1 || prior.organizationId !== org || prior.memberId !== uid
          || prior.requestId !== d.requestId || prior.gameId !== d.gameId || !hex(prior.attemptId)) throw fail();
        const r = readRound(await tx.get(roundPath(prior.attemptId)), org, uid, prior.attemptId);
        if (r.status === 'open' && (r.leaseUntilMillis <= now || r.expiresAtMillis <= now)) throw fail('Round expired. Start a new local round.');
        return snapshot(r);
      }
      const [lease, collision] = await readAll(tx, [leasePath, roundPath(candidate!.attemptId)]);
      if (collision) throw fail();
      if (lease && (lease.schemaVersion !== 1 || lease.organizationId !== org || lease.memberId !== uid
        || !hex(lease.attemptId) || !rewardTime(lease.leaseUntilMillis) || !['open', 'closed'].includes(String(lease.status)))) throw fail();
      if (lease?.status === 'open' && Number(lease.leaseUntilMillis) > now) throw new DomainError('resource-exhausted', 'Another round is being checked. Continue playing locally or wait for it to finish.');
      const r: Round = {schemaVersion: 1, organizationId: org, memberId: uid, gameId: d.gameId as Round['gameId'], ...candidate!,
        requestId: String(d.requestId), status: 'open', sequence: 0, activeMillis: 0, phase: 'paused', lastAtMillis: now,
        startedAtMillis: now, leaseUntilMillis: now + LEASE, expiresAtMillis: now + MAX_LIFETIME, physicalVerified: false, pointsAwarded: 0};
      tx.create(roundPath(r.attemptId), r);
      tx.create(operationPath, {schemaVersion: 1, organizationId: org, memberId: uid, requestId: d.requestId, gameId: d.gameId, attemptId: r.attemptId});
      tx.set(leasePath, {schemaVersion: 1, organizationId: org, memberId: uid, attemptId: r.attemptId, status: 'open', leaseUntilMillis: r.leaseUntilMillis});
      return snapshot(r);
    }
    const attempt = String(d.attemptId), target = roundPath(attempt);
    const r = readRound(await tx.get(target), org, uid, attempt);
    if (r.challengeToken !== d.challengeToken) throw deny();
    const receiptPath = `${target}/commands/${d.action === 'abandon' ? 'abandon' : String(d.sequence)}`;
    const prior = await tx.get(receiptPath), fingerprint = digest(d.action, d.attemptId, d.challengeToken,
      d.sequence ?? null, d.activeMillis ?? null, d.phase ?? null);
    if (prior) {
      if (prior.fingerprint !== fingerprint) throw new DomainError('already-exists', 'Round command already used with different fields.');
      const saved = readRound(prior.round as DocumentData, org, uid, attempt);
      return snapshot(saved);
    }
    const lease = await tx.get(leasePath);
    if (r.status !== 'open') throw fail('Round is already closed.');
    if (!lease || lease.schemaVersion !== 1 || lease.organizationId !== org || lease.memberId !== uid
      || lease.attemptId !== attempt || lease.status !== 'open') throw fail('Round no longer owns the active lease.');
    if (d.action !== 'abandon' && (now < r.lastAtMillis || now >= r.leaseUntilMillis || now >= r.expiresAtMillis)) throw fail('Round expired. Continue playing locally.');
    if (d.action !== 'abandon' && d.sequence !== r.sequence + 1) throw fail('Round checkpoints must arrive in order.');
    let updated: Round;
    if (d.action === 'checkpoint') {
      const active = Number(d.activeMillis), delta = active - r.activeMillis;
      if (Number(d.sequence) > 360 || delta < 0 || delta > 5000 || delta > now - r.lastAtMillis + 500
        || (r.phase === 'paused' && d.phase === 'paused' && delta !== 0)
        || active > now - r.startedAtMillis + 500) throw fail('Reported round time is inconsistent with server timing.');
      updated = {...r, sequence: Number(d.sequence), activeMillis: active, phase: d.phase as 'active' | 'paused',
        lastAtMillis: now, leaseUntilMillis: Math.min(now + LEASE, r.expiresAtMillis)};
    } else {
      if (d.action === 'finish' && (r.activeMillis !== 40000 || now - r.startedAtMillis < 40000)) throw fail('A full round of timing checkpoints is required.');
      updated = {...r, status: d.action === 'finish' ? 'awaiting_verification' : 'abandoned',
        sequence: d.action === 'finish' ? Number(d.sequence) : r.sequence, lastAtMillis: Math.max(now, r.lastAtMillis)};
    }
    tx.set(target, updated); tx.create(receiptPath, {fingerprint, round: updated});
    tx.set(leasePath, {schemaVersion: 1, organizationId: org, memberId: uid, attemptId: attempt,
      status: updated.status === 'open' ? 'open' : 'closed', leaseUntilMillis: updated.leaseUntilMillis});
    return snapshot(updated);
  });
  await deps.freshAuth(auth!); await store.transact(tx => authorize(tx, auth!, org));
  return result;
}
