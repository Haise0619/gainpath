import { requireActiveMembership, requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { readAll, type DocumentData, type TransactionPort } from '../../platform/firestore/store';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
export const MEMBERSHIP_ENTITLEMENT_POLICY = 'gainpath-effective-membership-v1';
const timestamp = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) > 0 && Number(v) <= 8640000000000000;
const text = (v: unknown): v is string => typeof v === 'string' && v.trim().length > 0 && v.length <= 500;
const tier = (v: unknown): v is 'basic' | 'premium' => v === 'basic' || v === 'premium';
const denied = () => new DomainError('permission-denied', 'Current verified Member access is required.');

/** Read-only effective membership. Organization authority is never a paid tier. */
export async function readMembershipEntitlement(tx: TransactionPort, auth: Auth, org: string, now: number) {
  requireVerifiedEmail(auth);
  return readMemberFacts(tx, auth!.uid, org, now, auth!.token.auth_time, true);
}

/** Privileged lookup consumes current Admin SDK identity, never a manufactured Member token. */
export async function readVerifiedTargetMembershipEntitlement(tx: TransactionPort, uid: string, org: string, now: number,
  identity: { exists: boolean; disabled: boolean; emailVerified: boolean }) {
  if (!identity.exists || identity.disabled || !identity.emailVerified) throw denied();
  return (await readMemberFacts(tx, uid, org, now, undefined, false)).entitlement;
}

async function readMemberFacts(tx: TransactionPort, uid: string, org: string, now: number, authTime: unknown, sessionRequired: boolean) {
  if (!timestamp(now)) throw new DomainError('unavailable', 'Membership time is unavailable.');
  const [user, member, organization, account] = await readAll(tx, [
    `users/${uid}`, `orgs/${org}/members/${uid}`, `orgs/${org}`, `orgs/${org}/membershipAccounts/${uid}`,
  ]);
  const authority = requireActiveMembership(member);
  if (authority.role !== 'member' || user?.organizationId !== org || member?.organizationId !== org
      || (member.userId !== undefined && member.userId !== uid) || organization?.status !== 'active') throw denied();
  const lifecycle = user.accountLifecycle as DocumentData | undefined;
  if (lifecycle !== undefined && (!lifecycle || lifecycle.schemaVersion !== 1 || lifecycle.state !== 'active'
      || lifecycle.revocationPending !== false || !Number.isSafeInteger(lifecycle.sessionNotBeforeSeconds)
      || Number(lifecycle.sessionNotBeforeSeconds) < 0
      || (sessionRequired && Number(lifecycle.sessionNotBeforeSeconds) > 0 && (!Number.isSafeInteger(authTime)
        || Number(authTime) < Number(lifecycle.sessionNotBeforeSeconds))))) throw denied();

  const common = { schemaVersion: 1, policyVersion: MEMBERSHIP_ENTITLEMENT_POLICY, organizationId: org, memberId: uid, resolvedAtMillis: now };
  const empty = { paidTier: null, paidPlanId: null, paidPlanName: null, paidExpiresAtMillis: null, benefits: [] as string[] };
  const unknown = (reason: string, retain = true) => ({ account, entitlement: {
    ...common, ...empty, ...(retain && account ? {
      paidTier: tier(account.planId) ? account.planId : null,
      paidPlanId: text(account.planId) ? account.planId : null,
      paidPlanName: text(account.planName) ? account.planName : null,
      paidExpiresAtMillis: timestamp(account.expiresAtMillis) ? account.expiresAtMillis : null,
    } : {}), status: 'unknown', effectiveTier: null, paidStatus: 'unknown', reason,
  } });
  if (account && (account.organizationId !== org || account.memberId !== uid)) return unknown('invalid_paid_membership', false);
  const hasPaidFacts = account && ['planId', 'expiresAtMillis', 'lastTransactionId'].some(k => account[k] !== undefined);
  if (!hasPaidFacts) return { account, entitlement: { ...common, ...empty, status: 'resolved', effectiveTier: 'free', paidStatus: 'none', reason: 'no_paid_membership' } };
  if (!tier(account!.planId)) return unknown(text(account!.planId) ? 'unsupported_paid_tier' : 'invalid_paid_membership');
  if (!timestamp(account!.expiresAtMillis) || typeof account!.lastTransactionId !== 'string'
      || !/^[A-Za-z0-9_-]{1,128}$/.test(account!.lastTransactionId)) return unknown('invalid_paid_membership');
  const p = await tx.get(`orgs/${org}/transactions/${account!.lastTransactionId}`);
  if (!p || p.schemaVersion !== 1 || p.organizationId !== org || p.memberId !== uid || p.transactionId !== account!.lastTransactionId
      || !['MembershipPurchase', 'MembershipRenewal'].includes(String(p.kind)) || p.planId !== account!.planId
      || p.environment !== 'sandbox' || p.provider !== 'billplz' || p.currency !== 'MYR' || p.paymentStatus !== 'cleared'
      || !['confirmed', 'reconciliation_required'].includes(String(p.fulfilmentStatus))
      || !text(p.billId) || !text(p.collectionId) || !Number.isSafeInteger(p.amountMinor) || Number(p.amountMinor) < 1
      || !Number.isSafeInteger(p.durationDays) || Number(p.durationDays) < 1 || Number(p.durationDays) > 3660
      || !timestamp(p.clearedAtMillis) || p.clearedAtMillis > now || p.expiresAtMillis !== account!.expiresAtMillis
      || Number(p.expiresAtMillis) <= p.clearedAtMillis || !text(p.planName)
      || !Array.isArray(p.benefits) || !p.benefits.every(x => typeof x === 'string' && x.length <= 500)) return unknown('payment_evidence_unavailable');
  const active = Number(account!.expiresAtMillis) > now;
  return { account, entitlement: { ...common, status: 'resolved', effectiveTier: active ? account!.planId : 'free',
    paidTier: account!.planId, paidPlanId: account!.planId, paidPlanName: p.planName, paidExpiresAtMillis: account!.expiresAtMillis,
    paidStatus: active ? 'active' : 'expired', benefits: active ? p.benefits : [], reason: active ? 'active_paid_membership' : 'paid_membership_expired' } };
}

export async function resolveMembershipEntitlement(tx: TransactionPort, auth: Auth, org: string, now: number) {
  return (await readMembershipEntitlement(tx, auth, org, now)).entitlement;
}
