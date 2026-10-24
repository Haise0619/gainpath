import type { DocumentData, TransactionPort } from '../../platform/firestore/store';
import { DomainError } from '../../platform/errors';
import { keyOf } from '../../platform/idempotency';
import { resolveMembershipEntitlement } from './membership-entitlement';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
const CYCLE = 30 * 86400000;
const validTime = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) > 0 && Number(v) <= 8640000000000000;
const id = (v: unknown): v is string => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const ids = (v: unknown): v is string[] => Array.isArray(v) && v.length > 0 && v.length <= 100 && v.every(id) && new Set(v).size === v.length;
const unavailable = () => new DomainError('unavailable', 'Premium Coach voucher is unavailable.');
const review = () => new DomainError('failed-precondition', 'Voucher payment requires authorized review.');
const root = (org: string) => `orgs/${org}`;
const headPath = (org: string, uid: string) => `${root(org)}/premiumCoachVoucherHeads/${uid}`;
const termPath = (org: string, paymentId: string) => `${root(org)}/premiumCoachVoucherTerms/${paymentId}`;
const voucherPath = (org: string, voucherId: string) => `${root(org)}/premiumCoachVouchers/${voucherId}`;

/** Complete explicit configuration only. Unsupported commercial choices remain disabled. */
export function premiumCoachVoucherPolicy(d: DocumentData | undefined) {
  if (!d || d.schemaVersion !== 1 || d.enabled !== true || !id(d.policyVersion)
    || d.currency !== 'MYR' || d.cycleDays !== 30 || d.discountBasisPoints !== 1000 || d.maximumDiscountMinor !== 1500
    || !['floor', 'half_up'].includes(String(d.rounding)) || d.fundingSource !== 'gym' || d.coachCommissionBasis !== 'gross_fee'
    || !id(d.financeApprovalId) || d.commissionPolicyVersion !== 'sandbox-coach-80-v1' || !ids(d.eligibleBranchIds) || !ids(d.eligibleCoachIds)
    || !Array.isArray(d.eligibleDurationsMinutes) || d.eligibleDurationsMinutes.length === 0 || d.eligibleDurationsMinutes.length > 2
    || !d.eligibleDurationsMinutes.every(v => v === 30 || v === 60) || new Set(d.eligibleDurationsMinutes).size !== d.eligibleDurationsMinutes.length
    || d.expiry !== 'cycle_end' || d.stacking !== 'none' || d.refund !== 'no_reinstatement' || d.unpaidRecovery !== 'provider_deleted_only') return undefined;
  return { policyVersion: d.policyVersion, rounding: d.rounding as 'floor' | 'half_up', eligibleBranchIds: d.eligibleBranchIds,
    eligibleCoachIds: d.eligibleCoachIds, eligibleDurationsMinutes: d.eligibleDurationsMinutes as number[],
    fundingSource: 'gym' as const, coachCommissionBasis: 'gross_fee' as const, financeApprovalId: d.financeApprovalId,
    commissionPolicyVersion: d.commissionPolicyVersion };
}
function clearedPremium(p: DocumentData | undefined, org: string, uid: string, paymentId: string): p is DocumentData {
  return !!p && p.schemaVersion === 1 && p.organizationId === org && p.memberId === uid && p.transactionId === paymentId
    && ['MembershipPurchase', 'MembershipRenewal'].includes(String(p.kind)) && p.environment === 'sandbox' && p.provider === 'billplz'
    && p.currency === 'MYR' && p.planId === 'premium' && p.durationDays === 30 && p.paymentStatus === 'cleared'
    && ['confirmed','reconciliation_required'].includes(String(p.fulfilmentStatus)) && id(p.billId) && id(p.collectionId) && Number.isSafeInteger(p.amountMinor)
    && Number(p.amountMinor) > 0 && validTime(p.clearedAtMillis) && validTime(p.expiresAtMillis)
    && p.expiresAtMillis - CYCLE >= p.clearedAtMillis
    && (p.refundStatus === undefined || ['pending_review','approved','rejected'].includes(String(p.refundStatus)));
}
function validTerm(t: DocumentData | undefined, org: string, uid: string, paymentId: string): t is DocumentData {
  return !!t && t.schemaVersion === 1 && t.organizationId === org && t.memberId === uid && t.paymentId === paymentId
    && validTime(t.startAtMillis) && validTime(t.endAtMillis) && t.endAtMillis - t.startAtMillis === CYCLE
    && (t.previousPaymentId === null || id(t.previousPaymentId));
}

/** Prepare before any writes; apply alongside the confirmed paid membership transaction.
 * No policy/grant migration, and an unusable benefit never blocks legacy payment settlement.
 */
export async function preparePremiumCoachVoucherTerm(tx: TransactionPort, org: string, p: DocumentData, previousAccount?: DocumentData): Promise<() => void> {
  const noop = () => undefined;
  if (!id(p.memberId) || !id(p.transactionId) || !clearedPremium(p, org, p.memberId, p.transactionId)) return noop;
  if (!premiumCoachVoucherPolicy(await tx.get(`${root(org)}/settings/premiumCoachVoucher`))) return noop;
  const uid = p.memberId, paymentId = p.transactionId;
  const existing = await tx.get(termPath(org, paymentId));
  if (existing) return noop; // Duplicate settlements cannot mint a second cycle.
  const head = await tx.get(headPath(org, uid));
  let previousPaymentId: string | null = null;
  if (head) {
    if (head.schemaVersion !== 1 || head.organizationId !== org || head.memberId !== uid || !id(head.paymentId)) return noop;
    const previous = await tx.get(termPath(org, head.paymentId));
    if (!validTerm(previous, org, uid, head.paymentId) || Number(previous.endAtMillis) > Number(p.expiresAtMillis) - CYCLE) return noop;
    previousPaymentId = head.paymentId;
  }
  // The existing membership service preserves paid time. Refuse to mint an overlapping term.
  if (previousAccount && (previousAccount.organizationId !== org || previousAccount.memberId !== uid
    || (validTime(previousAccount.expiresAtMillis) && Number(previousAccount.expiresAtMillis) > Number(p.expiresAtMillis) - CYCLE))) return noop;
  const term = { schemaVersion: 1, organizationId: org, memberId: uid, paymentId, previousPaymentId,
    startAtMillis: Number(p.expiresAtMillis) - CYCLE, endAtMillis: Number(p.expiresAtMillis) };
  return () => {
    tx.create(termPath(org, paymentId), term);
    tx.set(headPath(org, uid), { schemaVersion: 1, organizationId: org, memberId: uid, paymentId });
  };
}

export interface PremiumCoachVoucherOffer {
  status: 'unavailable' | 'ineligible' | 'available' | 'reserved' | 'consumed';
  voucherId?: string; cycleStartAtMillis?: number; cycleEndAtMillis?: number; discountMinor?: number;
}
export interface VoucherSnapshot extends DocumentData {
  schemaVersion: 1; voucherId: string; memberId: string; policyVersion: string; cycleStartAtMillis: number; cycleEndAtMillis: number;
  grossAmountMinor: number; discountMinor: number; amountMinor: number;
}
export async function premiumCoachVoucherOffer(tx: TransactionPort, auth: Auth, org: string, context: {
  coachId: string; branchId: string; durationMinutes: number; amountMinor: number;
}, now: number): Promise<{ offer: PremiumCoachVoucherOffer; snapshot?: VoucherSnapshot; prior?: DocumentData }> {
  const entitlement = await resolveMembershipEntitlement(tx, auth, org, now);
  const policy = premiumCoachVoucherPolicy(await tx.get(`${root(org)}/settings/premiumCoachVoucher`));
  if (!policy) return { offer: { status: 'unavailable' } };
  if (entitlement.status !== 'resolved') return { offer: { status: 'unavailable' } };
  if (entitlement.effectiveTier !== 'premium' || !policy.eligibleBranchIds.includes(context.branchId)
    || !policy.eligibleCoachIds.includes(context.coachId) || !policy.eligibleDurationsMinutes.includes(context.durationMinutes)) return { offer: { status: 'ineligible' } };
  const uid = auth!.uid, head = await tx.get(headPath(org, uid));
  if (!head || head.schemaVersion !== 1 || head.organizationId !== org || head.memberId !== uid || !id(head.paymentId)) return { offer: { status: 'unavailable' } };
  let paymentId: string | null = head.paymentId, nextStart = Infinity;
  const seen = new Set<string>();
  for (let i = 0; paymentId && i < 64; i++) {
    if (seen.has(paymentId)) return { offer: { status: 'unavailable' } }; seen.add(paymentId);
    const term = await tx.get(termPath(org, paymentId));
    if (!validTerm(term, org, uid, paymentId) || Number(term.endAtMillis) > nextStart) return { offer: { status: 'unavailable' } };
    const p = await tx.get(`${root(org)}/transactions/${paymentId}`);
    if (!clearedPremium(p, org, uid, paymentId) || p.expiresAtMillis !== term.endAtMillis
      || Number(p.clearedAtMillis) > now) return { offer: { status: 'unavailable' } };
    if (now >= Number(term.startAtMillis) && now < Number(term.endAtMillis)) {
      const voucherId = keyOf(uid, term.startAtMillis), prior = await tx.get(voucherPath(org, voucherId));
      if (prior && (prior.schemaVersion !== 1 || prior.organizationId !== org || prior.memberId !== uid || prior.voucherId !== voucherId
        || prior.cycleStartAtMillis !== term.startAtMillis || prior.cycleEndAtMillis !== term.endAtMillis
        || !['available', 'reserved', 'consumed'].includes(String(prior.status)))) return { offer: { status: 'unavailable' } };
      const discountMinor = Math.min(1500, policy.rounding === 'floor' ? Math.floor(context.amountMinor / 10) : Math.floor((context.amountMinor + 5) / 10));
      if (discountMinor < 1 || !Number.isSafeInteger(context.amountMinor) || context.amountMinor - discountMinor < 1) return { offer: { status: 'ineligible' } };
      const offer: PremiumCoachVoucherOffer = { status: prior ? prior.status as PremiumCoachVoucherOffer['status'] : 'available', voucherId,
        cycleStartAtMillis: Number(term.startAtMillis), cycleEndAtMillis: Number(term.endAtMillis), discountMinor };
      const snapshot: VoucherSnapshot = { schemaVersion: 1, voucherId, memberId: uid, policyVersion: policy.policyVersion,
        cycleStartAtMillis: Number(term.startAtMillis), cycleEndAtMillis: Number(term.endAtMillis), grossAmountMinor: context.amountMinor,
        discountMinor, amountMinor: context.amountMinor - discountMinor, rounding: policy.rounding,
        fundingSource: policy.fundingSource, coachCommissionBasis: policy.coachCommissionBasis,
        financeApprovalId: policy.financeApprovalId, commissionPolicyVersion: policy.commissionPolicyVersion,
        stacking: 'none', refund: 'no_reinstatement', unpaidRecovery: 'provider_deleted_only' };
      return { offer, snapshot, prior };
    }
    if (now >= Number(term.endAtMillis)) return { offer: { status: 'ineligible' } };
    nextStart = Number(term.startAtMillis); paymentId = term.previousPaymentId as string | null;
  }
  return { offer: { status: 'unavailable' } };
}
export function requireAvailablePremiumCoachVoucher(result: Awaited<ReturnType<typeof premiumCoachVoucherOffer>>): VoucherSnapshot {
  if (!result.snapshot || result.offer.status === 'unavailable') throw unavailable();
  if (result.offer.status !== 'available') throw new DomainError('failed-precondition', 'No eligible unused Premium Coach voucher is available.');
  return result.snapshot;
}
/** All reads performed by premiumCoachVoucherOffer before checkout writes begin. */
export function reservePremiumCoachVoucher(tx: TransactionPort, org: string, bookingId: string, snapshot: VoucherSnapshot, prior: DocumentData | undefined, now: number) {
  tx.set(voucherPath(org, snapshot.voucherId), { ...prior, ...snapshot, organizationId: org, bookingId,
    status: 'reserved', reservedAtMillis: now });
}
export function bookingVoucherProjection(d: DocumentData) {
  return d.premiumVoucher === undefined ? {} : { grossAmountMinor: d.grossAmountMinor, discountMinor: d.discountMinor, premiumVoucher: d.premiumVoucher };
}
/** Read before booking settlement writes; consumes on money clearance even if booking needs review. */
export function validatedPremiumCoachVoucherSnapshot(d: DocumentData): VoucherSnapshot | undefined {
  const v = d.premiumVoucher as VoucherSnapshot;
  if (!v || v.schemaVersion !== 1 || !id(v.voucherId) || v.memberId !== d.memberId || v.amountMinor !== d.amountMinor
    || v.grossAmountMinor !== d.grossAmountMinor || v.discountMinor !== d.discountMinor || !id(v.policyVersion)
    || !Number.isSafeInteger(v.grossAmountMinor) || v.grossAmountMinor < 1 || v.grossAmountMinor > 100000000
    || !Number.isSafeInteger(v.discountMinor) || v.discountMinor < 1 || v.discountMinor > 1500
    || v.grossAmountMinor - v.discountMinor !== v.amountMinor || v.fundingSource !== 'gym' || v.coachCommissionBasis !== 'gross_fee'
    || !id(v.financeApprovalId) || v.commissionPolicyVersion !== 'sandbox-coach-80-v1' || v.stacking !== 'none' || v.refund !== 'no_reinstatement'
    || !validTime(v.cycleStartAtMillis) || !validTime(v.cycleEndAtMillis) || v.cycleEndAtMillis-v.cycleStartAtMillis !== CYCLE
    || v.unpaidRecovery !== 'provider_deleted_only' || !['floor','half_up'].includes(String(v.rounding))
    || v.discountMinor !== Math.min(1500,v.rounding === 'floor' ? Math.floor(v.grossAmountMinor / 10) : Math.floor((v.grossAmountMinor + 5) / 10))) return undefined;
  return v;
}
async function reservedVoucher(tx: TransactionPort, org: string, bookingId: string, d: DocumentData) {
  const v = validatedPremiumCoachVoucherSnapshot(d); if (!v) throw review();
  const prior = await tx.get(voucherPath(org, v.voucherId));
  if (!prior || prior.status !== 'reserved' || prior.organizationId !== org || prior.memberId !== d.memberId
    || prior.bookingId !== bookingId || Object.entries(v).some(([key,value]) => prior[key] !== value)) throw review();
  return { prior, path: voucherPath(org,v.voucherId) };
}
export async function preparePremiumCoachVoucherConsumption(tx: TransactionPort, org: string, bookingId: string, d: DocumentData, now: number) {
  if (d.premiumVoucher === undefined) return () => undefined;
  const { prior, path } = await reservedVoucher(tx,org,bookingId,d);
  return () => tx.set(path, { ...prior, status: 'consumed', consumedAtMillis: now });
}

/** Called only after independent provider verification of this exact permanently deleted unpaid bill. */
export async function preparePremiumCoachVoucherRelease(tx: TransactionPort, org: string, bookingId: string, d: DocumentData, now: number) {
  const { prior, path } = await reservedVoucher(tx,org,bookingId,d);
  if (d.paymentStatus !== 'pending') throw review();
  return () => tx.set(path, { ...prior, status: 'available', releasedAtMillis: now, releaseReason: 'provider_verified_deleted' });
}
