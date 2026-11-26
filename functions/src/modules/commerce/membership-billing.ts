import { keyOf } from '../../platform/idempotency';
import type { DocumentData, TransactionPort } from '../../platform/firestore/store';
import { membershipAccountAt, scheduledMembershipUpgrade } from './membership-entitlement';

const GRACE = 7 * 86_400_000;
export const membershipBillingPath = (org: string, uid: string) => 'orgs/' + org + '/membershipBilling/' + uid;

interface RenewalBill {
  id: string;
  planId: string;
  amountMinor: number;
  dueAtMillis: number;
  paymentId?: string;
}

export interface MembershipBilling {
  cancelled: boolean;
  bill?: RenewalBill;
  next?: Omit<RenewalBill, 'id' | 'paymentId'>;
}

export async function materializeMembershipBill(tx: TransactionPort, org: string, uid: string, now: number): Promise<MembershipBilling | undefined> {
  const path = membershipBillingPath(org, uid);
  const [stored, account] = await Promise.all([tx.get(path), tx.get('orgs/' + org + '/membershipAccounts/' + uid)]);
  const bill = stored?.bill as RenewalBill | undefined;
  if (stored?.cancelled === true) return { cancelled: true, bill };
  const current = membershipAccountAt(account, now);
  const expiry = Number(current?.expiresAtMillis);
  const planId = String(current?.planId);
  if (!Number.isSafeInteger(expiry) || expiry <= 0 || !['basic', 'premium'].includes(planId) ||
      current?.organizationId !== org || current.memberId !== uid) return undefined;
  const scheduled = scheduledMembershipUpgrade(account);
  if (scheduled && Number(scheduled.startsAtMillis) > now) return undefined;
  if (expiry <= now && bill?.dueAtMillis === expiry && bill.planId === planId) return { cancelled: false, bill };
  const plan = await tx.get('orgs/' + org + '/membershipPlans/' + planId);
  const amountMinor = Number(plan?.amountMinor);
  if (plan?.active !== true || plan.currency !== 'MYR' || plan.durationDays !== 30 ||
      !Number.isSafeInteger(amountMinor) || amountMinor < 1) return undefined;
  const next = { planId, amountMinor, dueAtMillis: expiry };
  if (expiry > now) return { cancelled: false, bill, next };
  const renewal = { ...next, id: keyOf('membership-bill', org, uid, planId, String(expiry)) };
  tx.set(path, { cancelled: false, bill: renewal });
  return { cancelled: false, bill: renewal };
}

export async function cancelMembershipBilling(tx: TransactionPort, org: string, uid: string, now: number) {
  const path = membershipBillingPath(org, uid);
  const current = await tx.get(path);
  tx.set(path, { ...current, cancelled: true, cancelledAtMillis: now });
  return { cancelled: true, bill: current?.bill as RenewalBill | undefined };
}

export function membershipBillingView(value: MembershipBilling | undefined, now: number) {
  if (!value) return null;
  const { bill, next } = value;
  if (value.cancelled) return { status: 'cancelled', nextRenewal: false };
  if (next) return { status: bill?.paymentId ? 'paid' : 'active', nextRenewal: true, ...next };
  if (!bill) return null;
  return { ...bill, status: bill.paymentId ? 'paid' : now >= bill.dueAtMillis + GRACE ? 'past_due' : 'payment_due',
    nextRenewal: true, graceEndsAtMillis: bill.dueAtMillis + GRACE };
}

export function pendingMembershipBill(data: DocumentData | undefined, billingId: unknown, planId: unknown, expiresAtMillis: unknown) {
  const bill = data?.bill as RenewalBill | undefined;
  if (!bill || data?.cancelled === true || bill.id !== billingId || bill.paymentId ||
      bill.planId !== planId || bill.dueAtMillis !== expiresAtMillis) return undefined;
  return bill;
}

export function paidMembershipBill(data: DocumentData | undefined, planId: unknown, previousExpiry: unknown, paymentId: string) {
  const bill = data?.bill as RenewalBill | undefined;
  if (!bill || bill.planId !== planId || bill.dueAtMillis !== previousExpiry || bill.paymentId) return undefined;
  return { ...data, bill: { ...bill, paymentId } };
}
