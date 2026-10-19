import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { requiredIdentifier } from '../../platform/validation';
import { keyOf } from '../../platform/idempotency';
import { allowed, object } from '../coaching/coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from '../coaching/booking-validation';
import type { CoachIdentityReader } from '../coaching/coach-profile-service';
import type { BillplzGateway, SandboxBill } from './billplz-sandbox';
import { settleBookingPayment } from './booking-payment-service';
type Auth = {
    uid: string;
    token: Record<string, unknown>;
} | undefined;
type RefundOrder = {
    id: string;
    collectionId: string;
    reference: string;
    amountMinor: number;
    status: string;
};
export interface PaymentAdminDependencies {
    bills: BillplzGateway;
    collectionId: string;
    refundCollectionId?: string;
    refunds?: {
        create(input: {
            reference: string;
            amountMinor: number;
            name: string;
            description: string;
        }): Promise<RefundOrder>;
        get(id: string): Promise<RefundOrder>;
    };
    readIdentity: CoachIdentityReader;
    reader: {
        list(org: string, afterId?: string): Promise<{
            id: string;
            data: DocumentData;
        }[]>;
        events(org: string, id: string): Promise<{
            id: string;
            data: DocumentData;
        }[]>;
    };
}
const path = (org: string, id: string) => `orgs/${org}/transactions/${id}`;
const invalid = () => new DomainError('failed-precondition', 'Payment review state changed. Reload and check the provider record.');
function context(auth: Auth, raw: unknown, keys: string[]) { requireVerifiedEmail(auth); const d = object(raw); allowed(d, keys); if (d.schemaVersion !== 1)
    throw invalid(); return { d, org: requiredIdentifier(d.organizationId, 'organizationId'), uid: auth!.uid }; }
async function admin(tx: TransactionPort, org: string, uid: string) { const a = await currentBookingMembership(tx, org, uid); if (a.role !== 'admin')
    throw new DomainError('permission-denied', 'Current Admin access is required.'); await requireBookingOrganization(tx, org); }
function payment(d: DocumentData | undefined, org: string, id: string): DocumentData { if (!d || d.schemaVersion !== 1 || d.environment !== 'sandbox' || d.provider !== 'billplz' || d.organizationId !== org || d.bookingId !== id || d.currency !== 'MYR' || !Number.isSafeInteger(d.amountMinor) || Number(d.amountMinor) < 1 || !['pending', 'cleared'].includes(String(d.paymentStatus)) || !['creating', 'awaiting_payment', 'confirmed', 'reconciliation_required'].includes(String(d.fulfilmentStatus)))
    throw invalid(); return d; }
function projection(d: DocumentData) { return Object.fromEntries(['bookingId', 'memberId', 'coachName', 'branchName', 'amountMinor', 'currency', 'paymentStatus', 'fulfilmentStatus', 'createdAtMillis', 'updatedAtMillis', 'billId', 'resolutionReason', 'refundStatus', 'refundOrderId', 'reviewReason'].filter(k => d[k] !== undefined).map(k => [k, d[k]])); }
function audit(tx: TransactionPort, org: string, id: string, event: string, requestId: string, uid: string, now: number, extra: DocumentData = {}) { tx.create(`${path(org, id)}/events/${keyOf(event, requestId)}`, { schemaVersion: 1, environment: 'sandbox', event, atMillis: now, actorId: uid, ...extra }); }
async function snapshot(store: DocumentStore, org: string, id: string, uid: string) { return store.transact(async (tx) => { await admin(tx, org, uid); return payment(await tx.get(path(org, id)), org, id); }); }
export async function listAdminBookingPayments(store: DocumentStore, auth: Auth, raw: unknown, deps: PaymentAdminDependencies) { const { d, org, uid } = context(auth, raw, ['schemaVersion', 'organizationId', 'afterId']); const afterId = d.afterId === undefined ? undefined : requiredIdentifier(d.afterId, 'afterId'); await store.transact(tx => admin(tx, org, uid)); const rows = await deps.reader.list(org, afterId); if (rows.length > 21)
    throw invalid(); await store.transact(tx => admin(tx, org, uid)); return { schemaVersion: 1, records: rows.slice(0, 20).filter(r => r.data.environment === 'sandbox' && r.data.provider === 'billplz').map(r => projection(payment(r.data, org, r.id))), ...(rows.length > 20 ? { nextAfterId: rows[19].id } : {}) }; }
export async function getAdminBookingPayment(store: DocumentStore, auth: Auth, raw: unknown, deps: PaymentAdminDependencies) { const { d, org, uid } = context(auth, raw, ['schemaVersion', 'organizationId', 'bookingId']); const id = requiredIdentifier(d.bookingId, 'bookingId'); await snapshot(store, org, id, uid); const events = await deps.reader.events(org, id); const p = await snapshot(store, org, id, uid); return { schemaVersion: 1, payment: projection(p), events: events.map(r => ({ id: r.id, ...Object.fromEntries(['event', 'atMillis', 'actorId', 'reason'].filter(k => r.data[k] !== undefined).map(k => [k, r.data[k]])) })), refundExecutionAvailable: !!deps.refunds && !!deps.refundCollectionId }; }
function eligible(d: DocumentData) { if (d.paymentStatus !== 'cleared' || d.fulfilmentStatus !== 'reconciliation_required')
    throw invalid(); }
function matchBill(b: SandboxBill, d: DocumentData, org: string, id: string, collectionId: string) { if (b.id !== d.billId || b.collection_id !== collectionId || b.amount !== d.amountMinor || b.reference_1 !== id || b.reference_2 !== org)
    throw invalid(); }
function paid(b: SandboxBill, d: DocumentData) { if (!b.paid || b.state !== 'paid' || b.paid_amount !== d.amountMinor)
    throw invalid(); }
function note(d: DocumentData) { if (typeof d.reason !== 'string' || d.reason.trim().length < 5 || d.reason.trim().length > 500 || /[\x00-\x1f\x7f]/.test(d.reason))
    throw new DomainError('invalid-argument', 'Enter a reason of 5–500 characters.'); return d.reason.trim(); }
async function applyOrder(store: DocumentStore, org: string, id: string, uid: string, order: RefundOrder, deps: PaymentAdminDependencies, requestId: string, reason: string, fingerprint: string, clock: () => number) { return store.transact(async (tx) => { await admin(tx, org, uid); const d = payment(await tx.get(path(org, id)), org, id); const resultPath = `${path(org, id)}/adminResults/${keyOf(requestId)}`; const prior = await tx.get(resultPath); const receiptPath = `${path(org, id)}/adminCommands/${requestId}`; const receipt = await tx.get(receiptPath); if (receipt && receipt.fingerprint !== fingerprint)
    throw new DomainError('already-exists', 'Request belongs to another review action.'); if (prior)
    return; eligible(d); if (order.collectionId !== deps.refundCollectionId || order.collectionId !== d.refundCollectionId || order.reference !== d.refundReference || order.amountMinor !== d.amountMinor || (d.refundOrderId && d.refundOrderId !== order.id) || !['processing', 'uncertain', 'completed', 'failed'].includes(String(d.refundStatus)))
    throw invalid(); if (['completed', 'failed'].includes(String(d.refundStatus)))
    return; const status = order.status === 'completed' ? 'completed' : order.status === 'refunded' ? 'failed' : 'processing'; const now = clock(); tx.set(path(org, id), { ...d, refundStatus: status, refundOrderId: order.id, refundProviderStatus: order.status, updatedAtMillis: now }); if (!receipt)
    tx.create(receiptPath, { fingerprint, atMillis: now, actorId: uid }); tx.create(resultPath, { atMillis: now, actorId: uid }); audit(tx, org, id, 'refund_' + status, requestId, uid, now, { reason }); }); }
export async function manageAdminBookingPayment(store: DocumentStore, auth: Auth, raw: unknown, deps: PaymentAdminDependencies, clock = Date.now) {
    const { d, org, uid } = context(auth, raw, ['schemaVersion', 'organizationId', 'bookingId', 'requestId', 'action', 'reason', 'billId', 'refundOrderId']);
    const id = requiredIdentifier(d.bookingId, 'bookingId'), requestId = requiredIdentifier(d.requestId, 'requestId'), action = String(d.action);
    if (!['verify', 'recover_bill', 'approve_refund', 'reject_refund', 'execute_refund', 'check_refund', 'recover_refund'].includes(action))
        throw new DomainError('invalid-argument', 'Unsupported payment action.');
    const reason = ['verify', 'check_refund'].includes(action) ? 'Provider status checked by Admin' : note(d);
    const receipt = `${path(org, id)}/adminCommands/${requestId}`, fingerprint = keyOf(action, reason, d.billId ?? null, d.refundOrderId ?? null);
    const initial = await store.transact(async (tx) => { await admin(tx, org, uid); const p = payment(await tx.get(path(org, id)), org, id), old = await tx.get(receipt); if (old && old.fingerprint !== fingerprint)
        throw new DomainError('already-exists', 'Request belongs to another review action.'); return { p, replay: !!old }; });
    const result = () => getAdminBookingPayment(store, auth, { schemaVersion: 1, organizationId: org, bookingId: id }, deps);
    if (initial.replay) {
        if (action === 'verify' || action === 'recover_bill') {
            const boundId = requiredIdentifier(initial.p.billId, 'billId');
            const b = await deps.bills.get(boundId);
            matchBill(b, initial.p, org, id, deps.collectionId);
            await snapshot(store, org, id, uid);
            await settleBookingPayment(store, org, id, b, deps.readIdentity, clock);
        }
        return result();
    }
    if (action === 'approve_refund' || action === 'reject_refund') {
        await store.transact(async (tx) => { await admin(tx, org, uid); const p = payment(await tx.get(path(org, id)), org, id), old = await tx.get(receipt); if (old) {
            if (old.fingerprint !== fingerprint)
                throw invalid();
            return;
        } eligible(p); if (p.refundOrderId || p.refundReservedAtMillis || ['processing', 'uncertain', 'completed', 'failed'].includes(String(p.refundStatus)))
            throw invalid(); const status = action === 'approve_refund' ? 'approved' : 'rejected', now = clock(); tx.set(path(org, id), { ...p, refundStatus: status, reviewReason: reason, reviewedBy: uid, reviewedAtMillis: now, updatedAtMillis: now }); tx.create(receipt, { fingerprint, atMillis: now, actorId: uid }); audit(tx, org, id, 'refund_' + status, requestId, uid, now, { reason }); });
        return result();
    }
    if (action === 'verify' || action === 'recover_bill') {
        const billId = action === 'recover_bill' ? requiredIdentifier(d.billId, 'billId') : requiredIdentifier(initial.p.billId, 'billId');
        const b = await deps.bills.get(billId);
        await store.transact(async (tx) => { await admin(tx, org, uid); const p = payment(await tx.get(path(org, id)), org, id), old = await tx.get(receipt); if (old) {
            if (old.fingerprint !== fingerprint)
                throw invalid();
            return;
        } matchBill(b, { ...p, billId }, org, id, deps.collectionId); if (action === 'recover_bill') {
            if (p.billId || p.paymentStatus !== 'pending' || p.fulfilmentStatus !== 'reconciliation_required' || p.resolutionReason !== 'bill_creation_uncertain')
                throw invalid();
            tx.set(path(org, id), { ...p, billId, collectionId: b.collection_id, updatedAtMillis: clock() });
        } tx.create(receipt, { fingerprint, atMillis: clock(), actorId: uid }); audit(tx, org, id, action === 'verify' ? 'provider_checked' : 'bill_recovered', requestId, uid, clock(), { reason }); });
        // Existing settlement performs all trusted hold/lock checks; recovery never creates another bill.
        await settleBookingPayment(store, org, id, b, deps.readIdentity, clock);
        return result();
    }
    if (!deps.refunds || !deps.refundCollectionId)
        throw new DomainError('unavailable', 'Sandbox Payment Order collection is not configured. No refund was sent.');
    if (action === 'check_refund' || action === 'recover_refund') {
        eligible(initial.p);
        if (!['processing', 'uncertain'].includes(String(initial.p.refundStatus)))
            throw invalid();
        const orderId = action === 'recover_refund' ? requiredIdentifier(d.refundOrderId, 'refundOrderId') : requiredIdentifier(initial.p.refundOrderId, 'refundOrderId');
        const order = await deps.refunds.get(orderId);
        await applyOrder(store, org, id, uid, order, deps, requestId, reason, fingerprint, clock);
        return result();
    }
    eligible(initial.p);
    if (initial.p.refundStatus !== 'approved')
        throw invalid();
    const b = await deps.bills.get(requiredIdentifier(initial.p.billId, 'billId'));
    matchBill(b, initial.p, org, id, deps.collectionId);
    paid(b, initial.p);
    const reserved = await store.transact(async (tx) => { await admin(tx, org, uid); const p = payment(await tx.get(path(org, id)), org, id), old = await tx.get(receipt); if (old) {
        if (old.fingerprint !== fingerprint)
            throw invalid();
        return false;
    } eligible(p); if (p.refundStatus !== 'approved' || p.billId !== b.id || p.amountMinor !== b.paid_amount)
        throw invalid(); const now = clock(); tx.set(path(org, id), { ...p, refundStatus: 'processing', refundReference: 'refund-' + id, refundCollectionId: deps.refundCollectionId, refundReservedAtMillis: now, updatedAtMillis: now }); tx.create(receipt, { fingerprint, atMillis: now, actorId: uid }); audit(tx, org, id, 'refund_reserved', requestId, uid, now, { reason }); return true; });
    if (!reserved)
        return result();
    let order: RefundOrder;
    try {
        order = await deps.refunds.create({ reference: 'refund-' + id, amountMinor: Number(initial.p.amountMinor), name: 'GainPath Sandbox Refund', description: 'Sandbox booking refund ' + id });
    }
    catch {
        await store.transact(async (tx) => { const p = payment(await tx.get(path(org, id)), org, id); if (p.refundStatus !== 'processing' || p.refundOrderId)
            return; tx.set(path(org, id), { ...p, refundStatus: 'uncertain', updatedAtMillis: clock() }); audit(tx, org, id, 'refund_uncertain', requestId, uid, clock(), { reason: 'Provider result uncertain; recover the original order. Do not resend.' }); });
        return result();
    }
    // A lost Admin session cannot authorize another payout. The already-issued order is retained for later review.
    await store.transact(async (tx) => { const p = payment(await tx.get(path(org, id)), org, id); if (order.collectionId !== deps.refundCollectionId || order.collectionId !== p.refundCollectionId || order.reference !== p.refundReference || order.amountMinor !== p.amountMinor)
        throw invalid(); if (!p.refundOrderId && p.refundStatus === 'processing')
        tx.set(path(org, id), { ...p, refundOrderId: order.id, updatedAtMillis: clock() }); });
    let verified: RefundOrder;
    try {
        verified = await deps.refunds.get(order.id);
    }
    catch {
        return result();
    }
    await applyOrder(store, org, id, uid, verified, deps, requestId, reason, fingerprint, clock);
    return result();
}
