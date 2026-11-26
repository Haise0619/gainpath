import { DomainError } from '../../platform/errors';
import { keyOf } from '../../platform/idempotency';
import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { membershipBillingPath } from './membership-billing';
import { xenditBookingReference } from './xendit-booking';

const failure = () => new DomainError('failed-precondition', 'Unable to verify the original Xendit Test payment or refund.');
export const xenditRefundReference = (org: string, id: string) => keyOf('xendit-refund-v1', org, id);
const ledger = (org: string, id: string) => 'orgs/' + org + '/transactions/' + id;
const refundId = (id: unknown): id is string => typeof id === 'string' && /^rfd-[0-9a-f-]{36}$/.test(id);

export class XenditRefundGateway {
  constructor(private readonly key: string, private readonly fetcher = fetch) {}
  private async request(path: string, body?: object) {
    if (!/^xnd_development_[A-Za-z0-9_-]+$/.test(this.key)) throw failure();
    const response = await this.fetcher('https://api.xendit.co' + path, {
      method: body ? 'POST' : 'GET', redirect: 'error', signal: AbortSignal.timeout(10000),
      headers: { Authorization: 'Basic ' + Buffer.from(this.key + ':').toString('base64'),
        'Content-Type': 'application/json', 'api-version': '2024-11-11' },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const data = await response.json() as DocumentData;
    if (!response.ok) {
      if (body && [400, 401, 403, 404, 422].includes(response.status)) {
        return { rejected: safeCode(data.error_code) };
      }
      throw failure();
    }
    return data;
  }
  async originalPayment(org: string, id: string, row: DocumentData) {
    if (typeof row.billId !== 'string' || !/^ps-[0-9a-f]{24}$/.test(row.billId)) throw failure();
    const session = await this.request('/sessions/' + row.billId);
    if (session.payment_session_id !== row.billId || session.reference_id !== xenditBookingReference(org, id) ||
        session.country !== 'MY' || session.currency !== 'MYR' || session.session_type !== 'PAY' ||
        session.status !== 'COMPLETED' || session.amount !== Number(row.amountMinor) / 100 ||
        typeof session.payment_id !== 'string' || !/^py-[0-9a-f-]{36}$/.test(session.payment_id)) throw failure();
    return session.payment_id;
  }
  create(reference: string, paymentId: string, amountMinor: number) {
    return this.request('/v3/refunds', { reference_id: reference, payment_id: paymentId,
      amount: amountMinor / 100, reason: 'REQUESTED_BY_CUSTOMER' });
  }
  get(id: unknown) {
    if (!refundId(id)) throw failure();
    return this.request('/v3/refunds/' + id);
  }
}

function safeCode(value: unknown) {
  return typeof value === 'string' && /^[A-Z0-9_]{1,80}$/.test(value) ? value : 'PROVIDER_REJECTED';
}

export async function membershipRefundEffect(tx: TransactionPort, org: string, id: string, row: DocumentData) {
  const uid = row.memberId;
  if (typeof uid !== 'string') throw failure();
  const accountPath = 'orgs/' + org + '/membershipAccounts/' + uid;
  const billingPath = membershipBillingPath(org, uid);
  const account = await tx.get(accountPath);
  const billing = await tx.get(billingPath);
  const scheduled = account?.scheduledUpgrade as DocumentData | undefined;
  const wasScheduled = scheduled?.lastTransactionId === id;
  const isCurrent = account?.lastTransactionId === id;
  if (isCurrent && scheduled && !wasScheduled) throw new DomainError('failed-precondition', 'Review the separately paid scheduled upgrade before refunding its preceding term.');
  if (!isCurrent && !wasScheduled && account?.lastTransactionId && Number(account.expiresAtMillis) > Number(row.expiresAtMillis ?? 0) &&
      row.expiresAtMillis !== undefined) {
    const later = await tx.get(ledger(org, String(account.lastTransactionId)));
    if (!later || Number(later.clearedAtMillis) < Number(row.expiresAtMillis)) {
      throw new DomainError('failed-precondition', 'This payment overlaps a later paid term. Resolve the membership adjustment before refunding.');
    }
  }
  const previous = row.previousMembershipTerm as DocumentData | undefined;
  let restore: DocumentData | undefined;
  if (isCurrent) {
    if (previous && typeof previous.lastTransactionId === 'string') {
      const prior = await tx.get(ledger(org, previous.lastTransactionId));
      if (!prior || prior.memberId !== uid || prior.paymentStatus !== 'cleared' || prior.refundStatus === 'completed' ||
          prior.planId !== previous.planId || prior.expiresAtMillis !== previous.expiresAtMillis) throw failure();
      restore = previous;
    } else if (Number(row.expiresAtMillis) - Number(row.clearedAtMillis) > 30 * 86400000 || row.upgradeMode === 'immediate' || row.upgradeExpiresAtMillis !== undefined) {
      throw new DomainError('failed-precondition', 'The previous paid membership term could not be reconstructed safely.');
    }
  }
  return () => {
    if (account && (isCurrent || wasScheduled)) {
      const next = { ...account, scheduledUpgrade: null, refundInProgress: null };
      if (isCurrent) {
        for (const field of ['planId', 'planName', 'benefits', 'expiresAtMillis', 'lastTransactionId']) delete (next as DocumentData)[field];
        Object.assign(next, restore);
      }
      tx.set(accountPath, next);
    }
    if (account?.refundInProgress === id && !isCurrent && !wasScheduled) tx.set(accountPath, { ...account, refundInProgress: null });
    const bill = billing?.bill as DocumentData | undefined;
    if (billing && bill && (bill.paymentId === id || ((isCurrent || wasScheduled) && bill.dueAtMillis === row.expiresAtMillis))) {
      const { bill: _bill, ...settings } = billing;
      tx.set(billingPath, settings);
    }
  };
}

export async function applyXenditRefund(store: DocumentStore, org: string, id: string, result: DocumentData, now: number) {
  return store.transact(async tx => {
    const path = ledger(org, id);
    const row = await tx.get(path);
    if (!row || row.provider !== 'xendit' || row.environment !== 'sandbox' ||
        row.refundReference !== xenditRefundReference(org, id) ||
        !['processing', 'uncertain', 'completed', 'failed'].includes(String(row.refundStatus))) throw failure();
    if (!refundId(result.refund_id) || result.reference_id !== row.refundReference ||
        result.payment_id !== row.refundPaymentId || result.currency !== 'MYR' ||
        result.amount !== Number(row.amountMinor) / 100 || (row.refundOrderId && row.refundOrderId !== result.refund_id) ||
        !['PENDING','SUCCEEDED','FAILED'].includes(String(result.status))) throw failure();
    if (row.refundStatus === 'completed' || row.refundStatus === 'failed') return;
    const status = result.status === 'SUCCEEDED' ? 'completed' : result.status === 'FAILED' ? 'failed' : 'processing';
    const membership = ['MembershipPurchase', 'MembershipRenewal'].includes(String(row.kind));
    const accountPath = 'orgs/' + org + '/membershipAccounts/' + row.memberId;
    const pendingAccount = membership && status !== 'processing' ? await tx.get(accountPath) : undefined;
    const reverse = status === 'completed' && membership ? await membershipRefundEffect(tx, org, id, row) : undefined;
    const bookingPath = 'orgs/' + org + '/bookings/' + id;
    const booking = status === 'completed' && !membership ? await tx.get(bookingPath) : undefined;
    if (booking && (booking.memberId !== row.memberId || !['cancelled','expired','refunded'].includes(String(booking.status)))) throw failure();
    if (pendingAccount?.refundInProgress === id && !reverse) tx.set(accountPath, { ...pendingAccount, refundInProgress: null });
    reverse?.();
    if (booking) tx.set(bookingPath, { ...booking, status: 'refunded' });
    tx.set(path, { ...row, refundStatus: status, refundOrderId: result.refund_id,
      refundProviderStatus: result.status, updatedAtMillis: now,
      ...(status === 'failed' ? { refundFailureCode: safeCode(result.failure_code) } : {}),
      ...(status === 'completed' && membership ? { invoiceStatus: 'refunded' } : {}) });
  });
}
