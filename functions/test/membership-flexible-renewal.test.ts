import { expect, it } from 'vitest';
import type { BillplzGateway, SandboxBill } from '../src/modules/commerce/billplz-sandbox';
import { createMembershipPayment, membershipQuote, readMembershipPayment, settleMembershipPayment } from '../src/modules/commerce/membership-payment-service';
import { MemoryStore } from './memory-store';

const organizationId = 'gainpath';
const auth = { uid: 'fixture-member', token: { email_verified: true } };
const scope = { schemaVersion: 1, organizationId };
const day = 24 * 60 * 60 * 1000;
const term = 30 * day;
const expiry = Date.parse('2026-11-25T18:00:00+08:00');
const activation = expiry - term;
const accountPath = `orgs/${organizationId}/membershipAccounts/${auth.uid}`;
const amounts = { basic: 8900, premium: 12900 };
type Tier = keyof typeof amounts;

function fixture() {
  const store = new MemoryStore();
  store.documents.set(`orgs/${organizationId}`, { status: 'active' });
  store.documents.set(`users/${auth.uid}`, { organizationId, email: 'fixture@example.invalid' });
  store.documents.set(`orgs/${organizationId}/members/${auth.uid}`, { organizationId, role: 'member', status: 'active', branchIds: [] });
  for (const tier of ['basic', 'premium'] as const) {
    store.documents.set(`orgs/${organizationId}/membershipPlans/${tier}`, {
      active: true, name: tier, amountMinor: amounts[tier], currency: 'MYR', durationDays: 30, benefits: [], version: 'fixture-v1',
    });
  }

  const bills = new Map<string, SandboxBill>();
  const gateway: BillplzGateway = {
    async create(request) {
      const id = `fixture-${bills.size + 1}`;
      const bill: SandboxBill = {
        id, collection_id: 'fixture', amount: request.amountMinor, paid: false, paid_amount: 0, state: 'due',
        url: `https://www.billplz-sandbox.com/bills/${id}`, reference_1: request.reference, reference_2: request.organizationId,
      };
      bills.set(id, bill);
      return bill;
    },
    async get(id) { return bills.get(id)!; },
  };
  async function reserve(tier: Tier, intent: 'purchase' | 'renewal', requestId: string, at: number) {
    const quote = await membershipQuote(store, auth, { ...scope, planId: tier }, () => at);
    return createMembershipPayment(store, auth, { ...scope, planId: tier, intent, requestId, quoteId: quote.quoteId }, gateway, () => at);
  }
  async function clear(payment: Record<string, unknown>, at: number) {
    const bill = bills.get(String(payment.billId))!;
    return settleMembershipPayment(store, organizationId, String(payment.transactionId), {
      ...bill, paid: true, paid_amount: bill.amount, state: 'paid',
    }, () => at);
  }
  async function activate(tier: Tier) {
    return clear(await reserve(tier, 'purchase', 'initial', activation), activation);
  }
  return { store, gateway, bills, reserve, clear, activate };
}

it.each(['basic', 'premium'] as const)('Free can purchase %s at the authorized price', async tier => {
  const { store, reserve, clear } = fixture();
  const payment = await reserve(tier, 'purchase', 'initial', activation);
  expect(payment).toMatchObject({ kind: 'MembershipPurchase', amountMinor: amounts[tier], paymentStatus: 'pending' });
  expect(store.documents.get(accountPath)?.expiresAtMillis).toBeUndefined();
  await expect(clear(payment, activation)).resolves.toMatchObject({ paymentStatus: 'cleared', fulfilmentStatus: 'confirmed' });
  expect(store.documents.get(accountPath)).toMatchObject({ planId: tier, expiresAtMillis: expiry });
});

const cases = [
  ['basic', 'immediately after activation', activation, activation],
  ['basic', '20 days before expiry', expiry - 20 * day, expiry - 20 * day + 2000],
  ['premium', '13 days before expiry', expiry - 13 * day, expiry - 13 * day + 2000],
  ['premium', 'one day before expiry', expiry - day, expiry - day + 2000],
  ['basic', 'at the exact expiry', expiry, expiry],
  ['premium', 'after expiry', expiry + day, expiry + day + 2000],
  ['basic', 'just before expiry, with later clearance', expiry - 1000, expiry + 1000],
] as const;

it.each(cases)('%s renewal %s uses clearance and preserves any remaining time', async (tier, _, reservedAt, clearedAt) => {
  const { store, reserve, clear, activate } = fixture();
  await activate(tier);
  const renewal = await reserve(tier, 'renewal', 'renewal', reservedAt);
  expect(renewal).toMatchObject({ kind: 'MembershipRenewal', paymentStatus: 'pending' });
  expect(store.documents.get(accountPath)?.expiresAtMillis).toBe(expiry);
  const expectedExpiry = Math.max(expiry, clearedAt) + term;
  await expect(clear(renewal, clearedAt)).resolves.toMatchObject({ paymentStatus: 'cleared', expiresAtMillis: expectedExpiry });
  expect(store.documents.get(accountPath)).toMatchObject({ planId: tier, expiresAtMillis: expectedExpiry });
});

it('concurrent early renewal requests recover one bill and clearance extends it once', async () => {
  const { store, gateway, bills, reserve, clear, activate } = fixture();
  await activate('premium');
  const at = expiry - 13 * day;
  const requests = await Promise.all([
    reserve('premium', 'renewal', 'first', at), reserve('premium', 'renewal', 'second', at),
  ]);
  const first = await readMembershipPayment(store, auth, { ...scope, transactionId: requests[0].transactionId }, gateway, () => at);
  expect(first).toMatchObject({ paymentStatus: 'pending', fulfilmentStatus: 'awaiting_payment' });
  expect(requests[1].transactionId).toBe(first.transactionId);
  expect(bills.size).toBe(2);
  await Promise.all([clear(first, at), clear(first, at + 1000)]);
  expect(store.documents.get(accountPath)?.expiresAtMillis).toBe(expiry + term);
  await clear(await reserve('premium', 'renewal', 'third', at + 2000), at + 3000);
  expect(store.documents.get(accountPath)?.expiresAtMillis).toBe(expiry + 2 * term);
});

it.each([['basic', 'premium'], ['premium', 'basic']] as const)('rejects an active %s to %s conversion before billing', async (current, target) => {
  const { store, bills, reserve, activate } = fixture();
  await activate(current);
  const at = expiry - 13 * day;
  await expect(reserve(target, 'purchase', 'switch-purchase', at)).rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(reserve(target, 'renewal', 'switch-renewal', at)).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(bills.size).toBe(1);
  expect(store.documents.get(accountPath)).toMatchObject({ planId: current, expiresAtMillis: expiry });
});
