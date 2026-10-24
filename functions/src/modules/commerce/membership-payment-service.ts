import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { requiredIdentifier } from '../../platform/validation';
import { allowed, object } from '../coaching/coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from '../coaching/booking-validation';
import type { BillplzGateway, SandboxBill } from './billplz-sandbox';
import type { CoachIdentityReader } from '../coaching/coach-profile-service';
import { readMembershipEntitlement } from './membership-entitlement';
import { preparePremiumCoachVoucherTerm } from './premium-coach-voucher';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
const DAY = 86400000;
const root = (org: string) => `orgs/${org}`;
const accountPath = (org: string, uid: string) => `${root(org)}/membershipAccounts/${uid}`;
const paymentPath = (org: string, id: string) => `${root(org)}/transactions/${id}`;
const unavailable = () => new DomainError('failed-precondition', 'Membership configuration or payment state unavailable. Refresh or contact Admin.');
function context(auth: Auth, raw: unknown, keys: string[]) {
  requireVerifiedEmail(auth);
  const d = object(raw); allowed(d, ['schemaVersion', 'organizationId', ...keys]);
  if (d.schemaVersion !== 1) throw unavailable();
  return { d, org: requiredIdentifier(d.organizationId, 'organizationId'), uid: auth!.uid };
}
async function member(tx: TransactionPort, org: string, uid: string) {
  const m = await currentBookingMembership(tx, org, uid);
  if (m.role !== 'member') throw new DomainError('permission-denied', 'Current Member access required.');
  await requireBookingOrganization(tx, org); // No branch restrictions on membership.
}
export function membershipPlan(id: string, d: DocumentData | undefined) {
  if (!d || d.active !== true || d.currency !== 'MYR' || !Number.isSafeInteger(d.amountMinor) || Number(d.amountMinor) < 1
      || !Number.isSafeInteger(d.durationDays) || Number(d.durationDays) < 1 || Number(d.durationDays) > 3660
      || typeof d.name !== 'string' || !d.name.trim() || typeof d.version !== 'string' || !d.version
      || !Array.isArray(d.benefits) || !d.benefits.every(x => typeof x === 'string' && x.length <= 500)) throw unavailable();
  return { planId: id, name: d.name, amountMinor: Number(d.amountMinor), currency: 'MYR', durationDays: Number(d.durationDays), benefits: d.benefits, version: d.version };
}
async function quote(tx: TransactionPort, org: string, d: DocumentData, now: number) {
  const id = requiredIdentifier(d.planId, 'planId');
  const plan = membershipPlan(id, await tx.get(`${root(org)}/membershipPlans/${id}`));
  let promo: DocumentData | undefined, code: string | undefined;
  if (d.promoCode !== undefined && d.promoCode !== '') {
    if (typeof d.promoCode !== 'string' || !/^[A-Z0-9_-]{1,64}$/.test(d.promoCode)) throw new DomainError('invalid-argument', 'Invalid promo code.');
    code = d.promoCode;
    promo = await tx.get(`${root(org)}/promoCodes/${code}`);
    if (!promo || promo.active !== true || !Number.isSafeInteger(promo.validFromMillis) || !Number.isSafeInteger(promo.validToMillis)
        || now < Number(promo.validFromMillis) || now >= Number(promo.validToMillis)
        || !Number.isSafeInteger(promo.maxRedemptions) || !Number.isSafeInteger(promo.currentRedemptions)
        || Number(promo.currentRedemptions) < 0 || Number(promo.currentRedemptions) >= Number(promo.maxRedemptions)
        || typeof promo.discountPercent !== 'number' || !Number.isFinite(promo.discountPercent) || promo.discountPercent <= 0 || promo.discountPercent >= 100
        || !Array.isArray(promo.planIds) || !promo.planIds.includes(id)) throw new DomainError('failed-precondition', 'Invalid, expired, exhausted or inapplicable promo code.');
  }
  const amountMinor = Math.round(plan.amountMinor * (1 - Number(promo?.discountPercent ?? 0) / 100));
  if (amountMinor < 1) throw unavailable();
  return { value: { ...plan, baseAmountMinor: plan.amountMinor, amountMinor, quoteId: keyOf(id, plan.version, plan.amountMinor, amountMinor, plan.durationDays, code ?? ''), ...(code ? { promoCode: code } : {}) }, promo, code };
}
export async function membershipQuote(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now) {
  const { d, org, uid } = context(auth, raw, ['planId', 'promoCode']);
  return store.transact(async tx => { await member(tx, org, uid); return (await quote(tx, org, d, clock())).value; });
}
export function membershipPayment(d: DocumentData | undefined, org: string, id: string): DocumentData {
  if (!d || d.organizationId !== org || d.transactionId !== id || !['MembershipPurchase', 'MembershipRenewal'].includes(String(d.kind))
      || d.environment !== 'sandbox' || d.provider !== 'billplz' || d.currency !== 'MYR' || typeof d.memberId !== 'string'
      || !Number.isSafeInteger(d.amountMinor) || Number(d.amountMinor) < 1 || !Number.isSafeInteger(d.durationDays) || Number(d.durationDays) < 1) throw unavailable();
  return d;
}
export function membershipPaymentView(d: DocumentData) {
  return Object.fromEntries(['transactionId', 'organizationId', 'memberId', 'kind', 'planId', 'planName', 'benefits', 'amountMinor', 'baseAmountMinor', 'currency', 'durationDays', 'paymentStatus', 'fulfilmentStatus', 'checkoutUrl', 'billId', 'createdAtMillis', 'checkoutExpiresAtMillis', 'clearedAtMillis', 'expiresAtMillis', 'refundStatus', 'refundReason', 'refundNotes', 'reviewReason', 'resolutionReason', 'invoiceStatus', 'promoCode'].filter(k => d[k] !== undefined).map(k => [k, d[k]]));
}
function event(tx: TransactionPort, org: string, id: string, name: string, now: number, extra: DocumentData = {}) {
  tx.set(`${paymentPath(org, id)}/events/${keyOf(name)}`, { event: name, atMillis: now, ...extra });
}
export async function createMembershipPayment(store: DocumentStore, auth: Auth, raw: unknown, gateway: BillplzGateway, clock = Date.now) {
  const { d, org, uid } = context(auth, raw, ['planId', 'promoCode', 'requestId', 'intent', 'quoteId']);
  const requestId = requiredIdentifier(d.requestId, 'requestId');
  if (!['purchase', 'renewal'].includes(String(d.intent))) throw unavailable();
  const id = `membership_${keyOf(uid, requestId)}`, fingerprint = keyOf(d.planId, d.promoCode ?? '', d.intent, d.quoteId ?? '');
  const reserved = await store.transact(async tx => {
    await member(tx, org, uid);
    const old = await tx.get(paymentPath(org, id));
    if (old) { if (old.fingerprint !== fingerprint) throw new DomainError('already-exists', 'Checkout request already used.'); return { p: old, create: false }; }
    const a = await tx.get(accountPath(org, uid));
    // A new client request ID cannot bypass an unresolved checkout.
    if (typeof a?.pendingTransactionId === 'string' && a.pendingTransactionId) {
      const pending = membershipPayment(await tx.get(paymentPath(org, a.pendingTransactionId)), org, a.pendingTransactionId);
      if (pending.paymentStatus !== 'cleared' && !['expired', 'failed'].includes(String(pending.fulfilmentStatus))) return { p: pending, create: false };
    }
    const now = clock(), q = await quote(tx, org, d, now), user = await tx.get(`users/${uid}`);
    if (d.quoteId !== undefined && d.quoteId !== q.value.quoteId) throw new DomainError('failed-precondition', 'Plan or promo pricing changed. Review a fresh quote.');
    if (typeof user?.email !== 'string' || !user.email.includes('@')) throw unavailable();
    if (d.intent === 'renewal' && a?.planId !== d.planId) throw new DomainError('failed-precondition', 'Renew your current plan.');
    if (Number(a?.expiresAtMillis ?? 0) > now && a?.planId !== d.planId) throw new DomainError('failed-precondition', 'Active plan changes require an Admin policy.');
    const p = { schemaVersion: 1, organizationId: org, transactionId: id, memberId: uid, kind: d.intent === 'renewal' ? 'MembershipRenewal' : 'MembershipPurchase',
      environment: 'sandbox', provider: 'billplz', planId: d.planId, planName: q.value.name, planVersion: q.value.version, benefits: q.value.benefits,
      amountMinor: q.value.amountMinor, baseAmountMinor: q.value.baseAmountMinor, currency: 'MYR', durationDays: q.value.durationDays,
      ...(q.code ? { promoCode: q.code } : {}), paymentStatus: 'pending', fulfilmentStatus: 'creating', invoiceStatus: 'pending',
      createdAtMillis: now, updatedAtMillis: now, checkoutExpiresAtMillis: now + 30 * 60000, fingerprint };
    // Capacity counts allocated checkouts conservatively. Never release an uncertain provider attempt.
    if (q.promo && q.code) tx.set(`${root(org)}/promoCodes/${q.code}`, { ...q.promo, currentRedemptions: Number(q.promo.currentRedemptions) + 1 });
    tx.create(paymentPath(org, id), p);
    tx.set(accountPath(org, uid), { ...a, organizationId: org, memberId: uid, pendingTransactionId: id });
    event(tx, org, id, 'checkout_reserved', now);
    return { p, create: true, email: user.email, name: typeof user.displayName === 'string' && user.displayName ? user.displayName : 'Member' };
  });
  if (!reserved.create) return membershipPaymentView(reserved.p);
  let bill: SandboxBill;
  try {
    bill = await gateway.create({ amountMinor: Number(reserved.p.amountMinor), name: reserved.name!, email: reserved.email!, reference: id, organizationId: org, description: `Membership: ${reserved.p.planName}` });
    if (bill.reference_1 !== id || bill.reference_2 !== org || bill.amount !== reserved.p.amountMinor || !bill.collection_id) throw unavailable();
  } catch {
    return store.transact(async tx => {
      const p = membershipPayment(await tx.get(paymentPath(org, id)), org, id);
      const next = { ...p, fulfilmentStatus: 'reconciliation_required', resolutionReason: 'bill_creation_uncertain', updatedAtMillis: clock() };
      tx.set(paymentPath(org, id), next); return membershipPaymentView(next);
    });
  }
  return store.transact(async tx => {
    const p = membershipPayment(await tx.get(paymentPath(org, id)), org, id);
    const next = { ...p, billId: bill.id, collectionId: bill.collection_id, checkoutUrl: bill.url, fulfilmentStatus: 'awaiting_payment', updatedAtMillis: clock() };
    tx.set(paymentPath(org, id), next); event(tx, org, id, 'bill_created', clock());
    return membershipPaymentView(next);
  });
}
export async function settleMembershipPayment(store: DocumentStore, org: string, id: string, bill: SandboxBill, clock = Date.now, readIdentity?: CoachIdentityReader) {
  let identityIneligible = false;
  if (readIdentity && bill.paid && bill.state === 'paid') {
    const initial = await store.transact(async tx => membershipPayment(await tx.get(paymentPath(org, id)), org, id));
    if (initial.paymentStatus === 'cleared') return membershipPaymentView(initial);
    // Auth verification stays outside retryable Firestore transactions.
    const identity = await readIdentity(String(initial.memberId));
    identityIneligible = !identity.exists || identity.disabled || !identity.emailVerified;
  }
  return store.transact(async tx => {
    const p = membershipPayment(await tx.get(paymentPath(org, id)), org, id);
    if (p.billId !== bill.id || p.collectionId !== bill.collection_id || p.amountMinor !== bill.amount || bill.reference_1 !== id || bill.reference_2 !== org) throw unavailable();
    if (p.paymentStatus === 'cleared') return membershipPaymentView(p);
    const now = clock();
    if (!bill.paid || bill.state !== 'paid') {
      const status = bill.state === 'deleted' ? 'failed' : now >= Number(p.checkoutExpiresAtMillis) ? 'expired' : 'awaiting_payment';
      const next = { ...p, fulfilmentStatus: status, updatedAtMillis: now };
      tx.set(paymentPath(org, id), next); return membershipPaymentView(next);
    }
    if (bill.paid_amount !== p.amountMinor) throw unavailable();
    const a = await tx.get(accountPath(org, String(p.memberId)));
    // Re-check current organization authority. Paid but ineligible/late => review, never discard money.
    let reason = now >= Number(p.checkoutExpiresAtMillis) ? 'checkout_expired' : '';
    if (identityIneligible) reason = 'account_ineligible';
    try { await member(tx, org, String(p.memberId)); } catch { reason = 'account_ineligible'; }
    if (Number(a?.expiresAtMillis ?? 0) > now && a?.planId !== p.planId) reason = 'plan_changed';
    const expiresAtMillis = Math.max(now, Number(a?.expiresAtMillis ?? 0)) + Number(p.durationDays) * DAY;
    if (!Number.isSafeInteger(expiresAtMillis) || expiresAtMillis > 8640000000000000) throw unavailable();
    const next = { ...p, paymentStatus: 'cleared', clearedAtMillis: now, invoiceStatus: 'paid', fulfilmentStatus: reason ? 'reconciliation_required' : 'confirmed', updatedAtMillis: now, ...(reason ? { resolutionReason: reason } : { expiresAtMillis }) };
    const applyVoucherTerm = !reason ? await preparePremiumCoachVoucherTerm(tx, org, next, a) : () => undefined;
    if (!reason) tx.set(accountPath(org, String(p.memberId)), { ...a, organizationId: org, memberId: p.memberId, planId: p.planId, planName: p.planName, benefits: p.benefits,
      expiresAtMillis, lastTransactionId: id, pendingTransactionId: a?.pendingTransactionId === id ? '' : a?.pendingTransactionId ?? '', autoRenew: false, updatedAtMillis: now });
    tx.set(paymentPath(org, id), next); event(tx, org, id, reason ? 'payment_review_required' : 'membership_activated', now);
    applyVoucherTerm();
    return membershipPaymentView(next);
  });
}
export async function readMembershipPayment(store: DocumentStore, auth: Auth, raw: unknown, gateway: BillplzGateway, clock = Date.now, readIdentity?: CoachIdentityReader) {
  const { d, org, uid } = context(auth, raw, ['transactionId']);
  const id = requiredIdentifier(d.transactionId, 'transactionId');
  const captured = await store.transact(async tx => {
    await member(tx, org, uid); const p = membershipPayment(await tx.get(paymentPath(org, id)), org, id);
    if (p.memberId !== uid) throw new DomainError('permission-denied', 'Own membership payment required.');
    const now = clock(), check = p.paymentStatus !== 'cleared' && typeof p.billId === 'string' && now - Number(p.lastProviderCheckAtMillis ?? 0) >= 10000;
    let next = p;
    if (p.fulfilmentStatus === 'creating' && now - Number(p.createdAtMillis) >= 120000) next = { ...p, fulfilmentStatus: 'reconciliation_required', resolutionReason: 'bill_creation_uncertain' };
    if (check) next = { ...next, lastProviderCheckAtMillis: now };
    if (next !== p) tx.set(paymentPath(org, id), next);
    return { p: next, check };
  });
  if (captured.check) await settleMembershipPayment(store, org, id, await gateway.get(String(captured.p.billId)), clock, readIdentity);
  return store.transact(async tx => { await member(tx, org, uid); return membershipPaymentView(membershipPayment(await tx.get(paymentPath(org, id)), org, id)); });
}
export async function membershipRefund(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now) {
  const { d, org, uid } = context(auth, raw, ['transactionId', 'reason', 'notes']);
  const id = requiredIdentifier(d.transactionId, 'transactionId');
  if (typeof d.reason !== 'string' || d.reason.trim().length < 5 || d.reason.length > 200 || typeof d.notes !== 'string' || d.notes.length > 2000) throw new DomainError('invalid-argument', 'Enter a refund reason and notes.');
  const reason = d.reason.trim(), notes = d.notes.trim();
  return store.transact(async tx => {
    await member(tx, org, uid); const p = membershipPayment(await tx.get(paymentPath(org, id)), org, id), now = clock();
    if (p.memberId !== uid) throw new DomainError('permission-denied', 'Own membership payment required.');
    if (p.paymentStatus !== 'cleared' || !Number.isSafeInteger(p.clearedAtMillis) || now < Number(p.clearedAtMillis) || now - Number(p.clearedAtMillis) > 7 * DAY) throw new DomainError('failed-precondition', 'Refund requests require a cleared payment within seven days.');
    if (p.refundStatus) return membershipPaymentView(p);
    const next = { ...p, refundStatus: 'pending_review', invoiceStatus: 'disputed', refundReason: reason, refundNotes: notes, refundRequestedAtMillis: now, fulfilmentStatus: 'reconciliation_required', resolutionReason: 'member_refund_requested', updatedAtMillis: now };
    tx.set(paymentPath(org, id), next); event(tx, org, id, 'refund_requested', now, { actorId: uid });
    return membershipPaymentView(next);
  });
}

export async function membershipOverview(store: DocumentStore, auth: Auth, raw: unknown, reader: {
  plans(org: string): Promise<{ id: string; data: DocumentData }[]>;
  payments(org: string, uid: string): Promise<{ id: string; data: DocumentData }[]>;
}, clock = Date.now, readIdentity?: CoachIdentityReader) {
  const { org, uid } = context(auth, raw, []);
  // Independent authorization sources may overlap; neither catalogue nor
  // history is queried until both have succeeded. No cross-request cache.
  const [, identity] = await Promise.all([
    store.transact(tx => member(tx, org, uid)),
    readIdentity?.(uid),
  ]);
  if (readIdentity && (!identity || !identity.exists || identity.disabled || !identity.emailVerified)) {
    throw new DomainError('permission-denied', 'Current verified Member access is required.');
  }
  const [plans, payments] = await Promise.all([reader.plans(org), reader.payments(org, uid)]);
  return store.transact(async tx => {
    const now = clock(), { account: a, entitlement } = await readMembershipEntitlement(tx, auth, org, now);
    return { schemaVersion: 1, organizationId: org, memberId: uid, serverNowMillis: now, autoRenewSupported: false,
      entitlement,
      account: a ? { planId: a.planId ?? '', planName: a.planName ?? '', benefits: a.benefits ?? [], expiresAtMillis: a.expiresAtMillis ?? 0, status: Number(a.expiresAtMillis ?? 0) > now ? 'active' : 'expired' } : { status: 'none' },
      plans: plans.filter(r => r.data.active === true).map(r => membershipPlan(r.id, r.data)),
      transactions: payments.filter(r => ['MembershipPurchase', 'MembershipRenewal'].includes(String(r.data.kind)) && r.data.memberId === uid).map(r => membershipPaymentView(membershipPayment(r.data, org, r.id))).sort((a, b) => Number(b.createdAtMillis) - Number(a.createdAtMillis)) };
  });
}
