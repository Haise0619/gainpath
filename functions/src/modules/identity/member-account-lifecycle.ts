import { randomUUID } from 'node:crypto';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore } from '../../platform/firestore/store';

const DAY = 86_400_000;
// Longer than the callable's 30-second execution timeout. Cancellation waits
// through this lease even after acknowledgement, fencing delayed invocations.
const REVOCATION_LEASE_MILLIS = 90_000;
// Frozen adjacent callables gate membership but do not check token revocation.
// Keep that membership closed beyond the maximum ordinary one-hour ID-token
// lifetime, so restoring it cannot revive a pre-deactivation bearer token.
const REACTIVATION_SECURITY_COOLDOWN_MILLIS = 65 * 60_000;
type State = 'active' | 'pendingDeletion';
type Policy = 'pendingApproval' | 'grace30Days';
export interface LifecycleAuth { uid: string; token: Record<string, unknown> }
export interface LifecycleDependencies {
  clock?: () => number;
  grace30DaysApproved?: boolean;
  revokeRefreshTokens: (uid: string) => Promise<void>;
}
interface Lifecycle {
  schemaVersion: 1; state: State; revision: number;
  requestedAtMillis: number | null; retentionEndsAtMillis: number | null;
  policy: Policy; sessionNotBeforeSeconds: number; lastRequestId: string | null;
  revocationPending: boolean; reactivatedAtMillis: number | null;
  updatedAtMillis: number | null; revocationLeaseUntilMillis: number;
  revocationAttemptId: string | null;
  sessionRevokedAtMillis: number | null;
}
export interface MemberAccountLifecycleResult {
  schemaVersion: 1; state: State; revision: number;
  requestedAtMillis: number | null; retentionEndsAtMillis: number | null;
  policy: Policy; sessionNotBeforeSeconds: number; sessionRevocationPending: boolean;
  reactivationAllowed: boolean; reactivationAvailableAtMillis: number | null;
  currentTimeMillis: number; lastRequestId: string | null;
}
interface Account {
  user: DocumentData; member: DocumentData; userPath: string; memberPath: string;
  organizationId: string; lifecycle: Lifecycle;
}
interface Command { requestId: string; expectedRevision: number }
function integer(value: unknown): value is number { return Number.isSafeInteger(value) && Number(value) >= 0; }
function identifier(value: unknown): value is string { return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value); }
function invalidState(): never { throw new DomainError('failed-precondition', 'The account lifecycle needs trusted support review.'); }
function nowFrom(dependencies: LifecycleDependencies): number {
  const now = (dependencies.clock ?? Date.now)();
  if (!integer(now) || now === 0 || now > 8_640_000_000_000_000 - 30 * DAY) invalidState();
  return now;
}
function principal(auth: LifecycleAuth | undefined, now: number, recent: boolean): LifecycleAuth {
  requireVerifiedEmail(auth);
  if (!auth || !identifier(auth.uid)) throw new DomainError('unauthenticated', 'Sign in first.');
  const time = auth.token.auth_time;
  if (!integer(time) || time > Math.floor(now / 1000) || (recent && Math.floor(now / 1000) - time > 300)) {
    throw new DomainError('unauthenticated', 'Confirm your password again before continuing.');
  }
  return auth;
}
function input(data: unknown, mutation: boolean): Command {
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new DomainError('invalid-argument', 'Request data must be an object.');
  const value = data as Record<string, unknown>;
  const keys = mutation ? ['schemaVersion', 'requestId', 'expectedRevision'] : ['schemaVersion'];
  if (value.schemaVersion !== 1 || Object.keys(value).some(key => !keys.includes(key))) throw new DomainError('invalid-argument', 'Unsupported lifecycle command fields.');
  if (!mutation) return { requestId: '', expectedRevision: 0 };
  if (!identifier(value.requestId) || value.requestId.length < 8 || !integer(value.expectedRevision)) throw new DomainError('invalid-argument', 'Use a stable request ID and the loaded revision.');
  return { requestId: value.requestId, expectedRevision: value.expectedRevision };
}
function decode(raw: unknown, status: unknown): Lifecycle {
  if (raw === undefined) {
    if (status !== 'active') invalidState();
    return { schemaVersion: 1, state: 'active', revision: 0, requestedAtMillis: null, retentionEndsAtMillis: null, policy: 'pendingApproval', sessionNotBeforeSeconds: 0, lastRequestId: null, revocationPending: false, reactivatedAtMillis: null, updatedAtMillis: null, revocationLeaseUntilMillis: 0, revocationAttemptId: null, sessionRevokedAtMillis: null };
  }
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) invalidState();
  const value = raw as Record<string, unknown>;
  if (value.schemaVersion !== 1 || !['active', 'pendingDeletion'].includes(String(value.state)) || value.state !== status
    || !integer(value.revision) || value.revision < 1 || !integer(value.requestedAtMillis) || value.requestedAtMillis === 0
    || !integer(value.updatedAtMillis) || value.updatedAtMillis < value.requestedAtMillis
    || !integer(value.sessionNotBeforeSeconds) || value.sessionNotBeforeSeconds !== Math.floor(value.requestedAtMillis / 1000) + 1
    || !identifier(value.lastRequestId) || typeof value.revocationPending !== 'boolean'
    || !integer(value.revocationLeaseUntilMillis)
    || !(value.revocationAttemptId === null || identifier(value.revocationAttemptId))) invalidState();
  if (value.revocationPending ? value.sessionRevokedAtMillis !== null
    : !integer(value.sessionRevokedAtMillis) || value.sessionRevokedAtMillis < value.requestedAtMillis) invalidState();
  if (value.policy === 'pendingApproval') {
    if (value.retentionEndsAtMillis !== null) invalidState();
  } else if (value.policy === 'grace30Days') {
    if (value.retentionEndsAtMillis !== value.requestedAtMillis + 30 * DAY) invalidState();
  } else invalidState();
  if (value.state === 'pendingDeletion') {
    if (value.reactivatedAtMillis !== null) invalidState();
  } else if (!integer(value.reactivatedAtMillis) || value.reactivatedAtMillis < value.requestedAtMillis || value.revocationPending) invalidState();
  return value as unknown as Lifecycle;
}
async function account(tx: { get(path: string): Promise<DocumentData | undefined> }, uid: string): Promise<Account> {
  const userPath = `users/${uid}`;
  const user = await tx.get(userPath);
  if (!user || !identifier(user.organizationId)) throw new DomainError('permission-denied', 'A canonical Member account is required.');
  const organizationId = user.organizationId;
  const memberPath = `orgs/${organizationId}/members/${uid}`;
  const member = await tx.get(memberPath);
  const organization = await tx.get(`orgs/${organizationId}`);
  if (organization?.status !== 'active') throw new DomainError('permission-denied', 'The canonical organization is unavailable.');
  if (!member || member.organizationId !== organizationId || member.role !== 'member'
    || (member.userId !== undefined && member.userId !== uid)
    || !['active', 'pendingDeletion'].includes(String(member.status))) throw new DomainError('permission-denied', 'A canonical Member account is required.');
  return { user, member, userPath, memberPath, organizationId, lifecycle: decode(user.accountLifecycle, member.status) };
}
function result(value: Lifecycle, now: number, approved: boolean): MemberAccountLifecycleResult {
  const availableAt = value.sessionRevokedAtMillis === null ? null
    : Math.max(value.revocationLeaseUntilMillis, value.sessionRevokedAtMillis + REACTIVATION_SECURITY_COOLDOWN_MILLIS);
  const allowed = value.state === 'pendingDeletion' && value.policy === 'grace30Days' && approved
    && !value.revocationPending && availableAt !== null && now >= availableAt && now < value.retentionEndsAtMillis!;
  return { schemaVersion: 1, state: value.state, revision: value.revision, requestedAtMillis: value.requestedAtMillis,
    retentionEndsAtMillis: value.retentionEndsAtMillis, policy: value.policy, sessionNotBeforeSeconds: value.sessionNotBeforeSeconds,
    sessionRevocationPending: value.revocationPending, reactivationAllowed: allowed,
    reactivationAvailableAtMillis: value.state === 'pendingDeletion' ? availableAt : null,
    currentTimeMillis: now, lastRequestId: value.lastRequestId };
}
function receiptPath(value: Account, uid: string, requestId: string): string {
  return `orgs/${value.organizationId}/memberLifecycleCommands/${uid}/requests/${requestId}`;
}
// Reserve revocation before doing an external Auth effect. Firestore transaction
// retries never repeat the side effect. A crash is retried after the bounded lease.
async function finishRevocation(store: DocumentStore, auth: LifecycleAuth, dependencies: LifecycleDependencies): Promise<void> {
  const attemptId = randomUUID();
  const reserved = await store.transact(async tx => {
    const current = await account(tx, auth.uid);
    const value = current.lifecycle;
    const now = nowFrom(dependencies);
    if (value.state !== 'pendingDeletion' || !value.revocationPending) return null;
    if (value.revocationLeaseUntilMillis > now) throw new DomainError('unavailable', 'Session cleanup is in progress. Retry shortly.');
    const next = { ...value, revocationAttemptId: attemptId, revocationLeaseUntilMillis: now + REVOCATION_LEASE_MILLIS };
    tx.set(current.userPath, { ...current.user, accountLifecycle: next });
    return { revision: value.revision, requestId: value.lastRequestId! };
  });
  if (!reserved) return;
  try { await dependencies.revokeRefreshTokens(auth.uid); }
  catch {
    // Keep the lease and pending marker: a timeout may have committed in Auth.
    throw new DomainError('unavailable', 'Deactivation is saved. Sign out; retry account recovery shortly to finish session cleanup.');
  }
  await store.transact(async tx => {
    const current = await account(tx, auth.uid);
    const value = current.lifecycle;
    const path = receiptPath(current, auth.uid, reserved.requestId);
    const receipt = await tx.get(path);
    if (value.revision !== reserved.revision || value.revocationAttemptId !== attemptId || !value.revocationPending) return;
    if (!receipt || receipt.appliedRevision !== value.revision || receipt.action !== 'deactivate') invalidState();
    const completedAt = nowFrom(dependencies);
    tx.set(current.userPath, { ...current.user, accountLifecycle: { ...value, revocationPending: false, sessionRevokedAtMillis: completedAt } });
    tx.set(path, { ...receipt, revocationCompletedAtMillis: completedAt });
  });
}
async function snapshot(store: DocumentStore, auth: LifecycleAuth, dependencies: LifecycleDependencies): Promise<MemberAccountLifecycleResult> {
  return store.transact(async tx => result((await account(tx, auth.uid)).lifecycle, nowFrom(dependencies), dependencies.grace30DaysApproved === true));
}
export async function readMemberAccountLifecycle(store: DocumentStore, rawAuth: LifecycleAuth | undefined, data: unknown, dependencies: LifecycleDependencies): Promise<MemberAccountLifecycleResult> {
  input(data, false);
  const auth = principal(rawAuth, nowFrom(dependencies), false);
  try { await finishRevocation(store, auth, dependencies); }
  catch (error) {
    if (!(error instanceof DomainError) || error.code !== 'unavailable') throw error;
    // Status remains readable during Auth outages or another cleanup lease.
  }
  return snapshot(store, auth, dependencies);
}
async function transition(store: DocumentStore, auth: LifecycleAuth, command: Command, action: 'deactivate' | 'reactivate', dependencies: LifecycleDependencies): Promise<void> {
  await store.transact(async tx => {
    const current = await account(tx, auth.uid);
    const value = current.lifecycle;
    const now = nowFrom(dependencies);
    principal(auth, now, true);
    const path = receiptPath(current, auth.uid, command.requestId);
    const receipt = await tx.get(path);
    if (receipt) {
      if (receipt.schemaVersion !== 1 || receipt.action !== action || receipt.expectedRevision !== command.expectedRevision
        || !integer(receipt.appliedRevision) || receipt.appliedRevision > value.revision) throw new DomainError('already-exists', 'That request ID has already been used.');
      return; // A receipt can never replay an old transition after reactivation.
    }
    if (Number(auth.token.auth_time) < value.sessionNotBeforeSeconds) throw new DomainError('unauthenticated', 'Sign in again before changing this account.');
    if (value.revision === Number.MAX_SAFE_INTEGER) invalidState();
    if (command.expectedRevision !== value.revision) throw new DomainError('aborted', 'Account state changed. Reload before continuing.');
    let next: Lifecycle;
    if (action === 'deactivate') {
      if (value.state !== 'active') throw new DomainError('failed-precondition', 'The account is already pending deletion.');
      next = { schemaVersion: 1, state: 'pendingDeletion', revision: value.revision + 1, requestedAtMillis: now,
        retentionEndsAtMillis: dependencies.grace30DaysApproved === true ? now + 30 * DAY : null,
        policy: dependencies.grace30DaysApproved === true ? 'grace30Days' : 'pendingApproval',
        sessionNotBeforeSeconds: Math.floor(now / 1000) + 1, lastRequestId: command.requestId,
        revocationPending: true, reactivatedAtMillis: null, updatedAtMillis: now, revocationLeaseUntilMillis: 0, revocationAttemptId: null, sessionRevokedAtMillis: null };
    } else {
      if (value.state !== 'pendingDeletion' || !result(value, now, dependencies.grace30DaysApproved === true).reactivationAllowed) throw new DomainError('failed-precondition', 'Reactivation is unavailable during the 65-minute session security wait, pending cleanup or policy approval, or after the approved window ends.');
      if (Number(auth.token.auth_time) < value.sessionNotBeforeSeconds) throw new DomainError('unauthenticated', 'Sign in again to restore this account.');
      next = { ...value, state: 'active', revision: value.revision + 1, lastRequestId: command.requestId, reactivatedAtMillis: now, updatedAtMillis: now };
    }
    tx.set(current.userPath, { ...current.user, accountLifecycle: next, updatedAtMillis: now });
    tx.set(current.memberPath, { ...current.member, status: next.state, updatedAtMillis: now });
    tx.create(path, { schemaVersion: 1, action, expectedRevision: value.revision, appliedRevision: next.revision, committedAtMillis: now, revocationCompletedAtMillis: action === 'deactivate' ? null : now });
  });
}
export async function requestMemberDeactivation(store: DocumentStore, rawAuth: LifecycleAuth | undefined, data: unknown, dependencies: LifecycleDependencies): Promise<MemberAccountLifecycleResult> {
  const command = input(data, true);
  const auth = principal(rawAuth, nowFrom(dependencies), true);
  await transition(store, auth, command, 'deactivate', dependencies);
  await finishRevocation(store, auth, dependencies);
  return snapshot(store, auth, dependencies);
}
export async function cancelMemberDeactivation(store: DocumentStore, rawAuth: LifecycleAuth | undefined, data: unknown, dependencies: LifecycleDependencies): Promise<MemberAccountLifecycleResult> {
  const command = input(data, true);
  const auth = principal(rawAuth, nowFrom(dependencies), true);
  await transition(store, auth, command, 'reactivate', dependencies);
  return snapshot(store, auth, dependencies);
}
