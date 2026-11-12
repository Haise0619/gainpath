import { requireActiveMembership, requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { readAll, type DocumentStore, type DocumentData, type TransactionPort } from '../../platform/firestore/store';
import { requiredIdentifier } from '../../platform/validation';
import { allowed, object } from '../coaching/coach-availability-contracts';
import type { CoachIdentityReader } from '../coaching/coach-profile-service';
import { readVerifiedTargetMembershipEntitlement, resolveMembershipEntitlement } from './membership-entitlement';
import {membershipCapabilities} from './membership-capabilities';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
export const MEMBERSHIP_ACCESS_POLICY = 'gainpath-membership-access-v1';
const denied = () => new DomainError('permission-denied', 'Current verified Admin access is required.');
function context(auth: Auth, raw: unknown, keys: string[]) {
  requireVerifiedEmail(auth);
  const d = object(raw); allowed(d, ['schemaVersion', 'organizationId', ...keys]);
  if (d.schemaVersion !== 1) throw new DomainError('invalid-argument', 'Unsupported request.');
  return { d, org: requiredIdentifier(d.organizationId, 'organizationId'), uid: auth!.uid };
}
function eligible(identity: Awaited<ReturnType<CoachIdentityReader>>) {
  return identity.exists && !identity.disabled && identity.emailVerified;
}
async function admin(tx: TransactionPort, auth: NonNullable<Auth>, org: string) {
  const [u, m, o] = await readAll(tx, [`users/${auth.uid}`, `orgs/${org}/members/${auth.uid}`, `orgs/${org}`]);
  if (requireActiveMembership(m).role !== 'admin' || u?.organizationId !== org || m?.organizationId !== org
    || (m.userId !== undefined && m.userId !== auth.uid) || o?.status !== 'active') throw denied();
  const l = u.accountLifecycle as DocumentData | undefined;
  if (l !== undefined && (!l || l.schemaVersion !== 1 || l.state !== 'active' || l.revocationPending !== false
    || !Number.isSafeInteger(l.sessionNotBeforeSeconds) || Number(l.sessionNotBeforeSeconds) < 0
    || (Number(l.sessionNotBeforeSeconds) > 0 && (!Number.isSafeInteger(auth.token.auth_time) || Number(auth.token.auth_time) < Number(l.sessionNotBeforeSeconds))))) throw denied();
}
function ids(value: unknown): value is string[] {
  return Array.isArray(value) && value.length <= 500 && value.every(id => typeof id === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(id)) && new Set(value).size === value.length;
}
/** No default whitelist/history cutoff/report definitions. Invalid policy never turns on restrictions. */
export function membershipAccessPolicy(raw: DocumentData | undefined) {
  if (!raw || raw.schemaVersion !== 1 || raw.policyVersion !== MEMBERSHIP_ACCESS_POLICY || raw.enabled !== true) return null;
  const ex = raw.exercises as DocumentData | undefined, reports = raw.advancedReports as DocumentData | undefined;
  if (ex !== undefined && (!ex || !ids(ex.supportedIds) || !ids(ex.freeIds) || !ex.freeIds.every(id => (ex.supportedIds as string[]).includes(id)))) return null;
  if (reports !== undefined && (!reports || !ids(reports.reportIds))) return null;
  return { exercises: ex ? { supportedIds: ex.supportedIds as string[], freeIds: ex.freeIds as string[] } : null,
    advancedReports: reports ? { reportIds: reports.reportIds as string[] } : null };
}
export async function membershipAccess(store: DocumentStore, auth: Auth, raw: unknown, readIdentity: CoachIdentityReader, clock = Date.now) {
  const { d, org, uid } = context(auth, raw, ['feature', 'resourceId']);
  if (!['exercise', 'advancedReport','gym','coach','miniGame'].includes(String(d.feature))) throw new DomainError('invalid-argument', 'Unsupported access feature.');
  const resourceId = requiredIdentifier(d.resourceId, 'resourceId');
  if (!eligible(await readIdentity(uid))) throw new DomainError('permission-denied', 'Current verified Member access is required.');
  const now = clock();
  return store.transact(async tx => {
    const entitlement = await resolveMembershipEntitlement(tx, auth, org, now);
    const common = { schemaVersion: 1, policyVersion: MEMBERSHIP_ACCESS_POLICY, organizationId: org, memberId: uid, resolvedAtMillis: now,
      feature: d.feature as string, resourceId, effectiveTier: entitlement.effectiveTier, requiredTier: null as string | null };
    if (['gym','coach','miniGame'].includes(String(d.feature))) {
      if(entitlement.status!=='resolved') return {...common,decision:'unknown',reason:'entitlement_unavailable'};
      const c=membershipCapabilities(entitlement);
      const allowed=d.feature==='gym'?c.canAccessGym:d.feature==='coach'?c.canBrowseCoaches:c.canAccessMiniGames;
      return {...common,requiredTier:'basic',decision:allowed?'allowed':'denied',reason:allowed?'tier_access':'paid_tier_required'};
    }
    // Approved commercial matrix supersedes legacy digital paywall policies.
    // Identity/session checks above remain mandatory; unknown paid evidence does
    // not remove independently authorized digital fitness or historical reports.
    return entitlement.status === 'resolved'
      ? {...common, requiredTier:'free', decision:'allowed', reason:'digital_fitness_included'}
      : {...common, decision:'legacy', reason:'digital_fitness_included'};
  });
}
export async function verifyMemberMembership(store: DocumentStore, auth: Auth, raw: unknown, readIdentity: CoachIdentityReader, clock = Date.now) {
  const { d, org, uid } = context(auth, raw, ['memberId']);
  const target = requiredIdentifier(d.memberId, 'memberId');
  if (!eligible(await readIdentity(uid))) throw denied();
  // Reauthorize after target Auth lookup, which remains outside retryable callbacks.
  await store.transact(tx => admin(tx, auth!, org));
  const targetIdentity = await readIdentity(target), now = clock();
  return store.transact(async tx => {
    await admin(tx, auth!, org);
    const common = { schemaVersion: 1, organizationId: org, memberId: target, verifiedAtMillis: now };
    try {
      const entitlement = await readVerifiedTargetMembershipEntitlement(tx, target, org, now, targetIdentity);
      const member = await tx.get(`orgs/${org}/members/${target}`);
      return { ...common, status: entitlement.status === 'resolved' ? 'verified' : 'unknown',
        identity: { displayName: typeof member?.displayName === 'string' ? member.displayName : null, email: typeof member?.email === 'string' ? member.email : null },
        gymAdmission: entitlement.status === 'resolved' && ['basic', 'premium'].includes(String(entitlement.effectiveTier)), entitlement };
    } catch (e) {
      if (!(e instanceof DomainError) || e.code !== 'permission-denied') throw e;
      return { ...common, status: 'denied', identity: null, gymAdmission: false, entitlement: null };
    }
  });
}
