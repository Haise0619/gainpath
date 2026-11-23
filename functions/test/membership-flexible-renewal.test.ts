import { expect, it } from 'vitest';
import type { BillplzGateway, SandboxBill } from '../src/modules/commerce/billplz-sandbox';
import { createMembershipPayment, membershipQuote, readMembershipPayment, settleMembershipPayment } from '../src/modules/commerce/membership-payment-service';
import { resolveMembershipEntitlement } from '../src/modules/commerce/membership-entitlement';
import { keyOf } from '../src/platform/idempotency';
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
  async function existingLegacyUpgrade(at: number) {
    const account = store.documents.get(accountPath)!;
    const requestId = 'legacy-upgrade';
    const quoteId = 'legacy-price';
    const transactionId = `membership_${keyOf(auth.uid, requestId)}`;
    const bill = await gateway.create({ amountMinor: 2000, name: 'Fixture', email: 'fixture@example.invalid',
      reference: transactionId, organizationId, description: 'Legacy Basic to Premium' });
    const payment = { schemaVersion: 1, organizationId, memberId: auth.uid, transactionId, kind: 'MembershipPurchase',
      environment: 'sandbox', provider: 'billplz', planId: 'premium', planName: 'Premium', benefits: [], amountMinor: 2000,
      currency: 'MYR', durationDays: 30, paymentStatus: 'pending', fulfilmentStatus: 'awaiting_payment',
      billId: bill.id, collectionId: bill.collection_id, checkoutUrl: bill.url, createdAtMillis: at,
      checkoutExpiresAtMillis: Math.min(expiry, at + 30 * 60000),
      upgradeExpiresAtMillis: expiry, upgradeFromTransactionId: account.lastTransactionId,
      fingerprint: keyOf('premium', '', 'purchase', quoteId) };
    store.documents.set(`orgs/${organizationId}/transactions/${transactionId}`, payment);
    store.documents.set(accountPath, { ...account, pendingTransactionId: transactionId });
    return { payment, input: { ...scope, planId: 'premium', intent: 'purchase', requestId, quoteId } };
  }
  return { store, gateway, bills, reserve, clear, activate, existingLegacyUpgrade };
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

it('honors an existing prorated upgrade on its original terms and request ID', async () => {
  const { store, gateway, clear, activate, existingLegacyUpgrade } = fixture();
  await activate('basic');
  const at = expiry - 15 * day;
  const { payment, input } = await existingLegacyUpgrade(at);
  const upgrade = await createMembershipPayment(store, auth, input, gateway, () => at);
  expect(upgrade.transactionId).toBe(payment.transactionId);
  expect(upgrade).toMatchObject({ amountMinor: 2000, upgradeExpiresAtMillis: expiry, paymentStatus: 'pending' });
  expect(store.documents.get(accountPath)).toMatchObject({ planId: 'basic', expiresAtMillis: expiry });
  await clear(upgrade, at + 1000);
  await clear(upgrade, at + 2000);
  expect(store.documents.get(accountPath)).toMatchObject({ planId: 'premium', expiresAtMillis: expiry });
  const entitlement = await store.transact(tx => resolveMembershipEntitlement(tx, auth, organizationId, at + 2000));
  expect(entitlement).toMatchObject({ effectiveTier: 'premium', paidExpiresAtMillis: expiry });
});

it('sends a cleared legacy upgrade for review if the original Basic term expired', async () => {
  const { store, existingLegacyUpgrade, clear, activate } = fixture();
  await activate('basic');
  const { payment: upgrade } = await existingLegacyUpgrade(expiry - 1000);
  await expect(clear(upgrade, expiry + 1000)).resolves.toMatchObject({
    paymentStatus: 'cleared', fulfilmentStatus: 'reconciliation_required',
  });
  expect(store.documents.get(accountPath)).toMatchObject({ planId: 'basic', expiresAtMillis: expiry });
});

it('rejects Premium to Basic changes before billing', async () => {
  const { bills, reserve, activate } = fixture();
  await activate('premium');
  await expect(reserve('basic', 'purchase', 'downgrade', expiry - day))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  expect(bills.size).toBe(1);
});
it('requires a current upgrade option and blocks legacy checkout without an existing order', async () => {
  const { store, bills, gateway, activate } = fixture();
  await activate('basic');
  const at = expiry - 15 * day;
  const data = { ...scope, planId: 'premium' };
  const input = { ...data, requestId: 'upgrade', intent: 'purchase' };
  await expect(membershipQuote(store, auth, data, () => at)).rejects.toMatchObject({ reason: 'upgrade_unavailable' });
  await expect(createMembershipPayment(store, auth, input, gateway, () => at)).rejects.toMatchObject({ reason: 'upgrade_unavailable' });
  await expect(membershipQuote(store, auth, { ...data, upgradeMode: 'immediate', promoCode: 'PROMO' }, () => at))
    .rejects.toMatchObject({ reason: 'promo_invalid' });
  expect(bills.size).toBe(1);
});

it.each([['immediate', 13167], ['next_term', 12900]] as const)('quotes and settles a verified %s upgrade', async (upgradeMode, amountMinor) => {
  const { store, gateway, bills, activate, clear } = fixture();
  await activate('basic');
  const now = expiry - 2 * day;
  const data = { ...scope, planId: 'premium', upgradeMode };
  const quote = await membershipQuote(store, auth, data, () => now);
  expect(quote).toMatchObject({ upgradeMode, amountMinor, premiumTermAmountMinor: 12900,
    upgradeChargeMinor: amountMinor - 12900, basicExpiresAtMillis: expiry, expiresAtMillis: expiry + term });
  const request = { ...data, intent: 'purchase', requestId: 'upgrade', quoteId: quote.quoteId };
  const payment = await createMembershipPayment(store, auth, request, gateway, () => now + 1000);
  expect(payment).toMatchObject({ upgradeMode, amountMinor, paymentStatus: 'pending' });
  expect(bills.size).toBe(2);
  const at = (when: number) => store.transact(tx => resolveMembershipEntitlement(tx, auth, organizationId, when));
  await expect(at(now)).resolves.toMatchObject({ effectiveTier: 'basic' });
  const cleared = now + 2000;
  const startsAtMillis = upgradeMode === 'immediate' ? cleared : expiry;
  const result = await clear(payment, cleared);
  expect(result).toMatchObject({ paymentStatus: 'cleared', fulfilmentStatus: 'confirmed', startsAtMillis, expiresAtMillis: expiry + term });
  await expect(clear(payment, cleared + 1)).resolves.toEqual(result);
  await expect(at(expiry - 1)).resolves.toMatchObject({ effectiveTier: upgradeMode === 'immediate' ? 'premium' : 'basic' });
  await expect(at(expiry)).resolves.toMatchObject({ effectiveTier: 'premium', paidExpiresAtMillis: expiry + term });
  await expect(at(expiry + term)).resolves.toMatchObject({ effectiveTier: 'free' });
});

it('identifies a conflicting order when recovering an existing bill', async () => {
  const { gateway, store, bills, reserve, clear } = fixture();
  const initial = await reserve('basic', 'purchase', 'basic-order', activation);
  const q = await membershipQuote(store, auth, { ...scope, planId: 'premium' }, () => activation);
  const request = { ...scope, planId: 'premium', intent: 'purchase', requestId: 'premium-order', quoteId: q.quoteId };
  const other = await createMembershipPayment(store, auth, request, gateway, () => activation);
  expect(other).toMatchObject({ planId: 'basic', transactionId: initial.transactionId, recoveredPendingCheckout: true });
  await clear(initial, activation);
  await expect(createMembershipPayment(store, auth, request, gateway, () => activation + 1)).resolves.toMatchObject({
    planId: 'basic', transactionId: initial.transactionId, paymentStatus: 'cleared', recoveredPendingCheckout: true });
  await expect(createMembershipPayment(store, auth, { ...request, promoCode: 'CHANGED' }, gateway, () => activation + 1))
    .rejects.toMatchObject({ code: 'already-exists' });
  expect(bills.size).toBe(1);
});

it('rejects a stale upgrade quote and reviews a payment confirmed past the Basic expiry', async () => {
  const { store, gateway, bills, activate, clear } = fixture();
  await activate('basic');
  const now = expiry - 10_000;
  const data = { ...scope, planId: 'premium', upgradeMode: 'immediate' };
  const q = await membershipQuote(store, auth, data, () => now);
  const input = { ...data, intent: 'purchase', requestId: 'expiring-upgrade', quoteId: q.quoteId };
  const catalogPath = `orgs/${organizationId}/membershipPlans/basic`;
  const original = store.documents.get(catalogPath)!;
  store.documents.set(catalogPath, { ...original, version: 'updated' });
  await expect(createMembershipPayment(store, auth, input, gateway, () => now)).rejects.toMatchObject({ reason: 'quote_changed' });
  expect(bills.size).toBe(1);
  store.documents.set(catalogPath, original);
  const payment = await createMembershipPayment(store, auth, input, gateway, () => now);
  await expect(clear(payment, expiry)).resolves.toMatchObject({ paymentStatus: 'cleared', fulfilmentStatus: 'reconciliation_required' });
  expect(store.documents.get(accountPath)).toMatchObject({ planId: 'basic', expiresAtMillis: expiry });
});

it('protects a paid future Premium term and permits renewal after it begins', async () => {
  const { store, gateway, activate, clear, reserve } = fixture();
  await activate('basic');
  const now = expiry - day;
  const data = { ...scope, planId: 'premium', upgradeMode: 'next_term' };
  const q = await membershipQuote(store, auth, data, () => now);
  const scheduled = await createMembershipPayment(store, auth, { ...data, intent: 'purchase', requestId: 'schedule', quoteId: q.quoteId }, gateway, () => now);
  await clear(scheduled, now);
  await expect(reserve('basic', 'renewal', 'conflict', now + 1)).rejects.toMatchObject({ reason: 'upgrade_already_scheduled' });
  const renewal = await reserve('premium', 'renewal', 'premium-renewal', expiry);
  await expect(clear(renewal, expiry)).resolves.toMatchObject({ expiresAtMillis: expiry + 2 * term });
  expect(store.documents.get(accountPath)).toMatchObject({ planId: 'premium', expiresAtMillis: expiry + 2 * term });
});

it('requires the latest server-issued quote per mode and enforces its time limit', async () => {
  const { store, gateway, bills, activate } = fixture();
  await activate('basic');
  const now = expiry - day;
  const data = { ...scope, planId: 'premium', upgradeMode: 'immediate' };
  const request = (quoteId: string, at: number) => createMembershipPayment(store, auth,
    { ...data, intent: 'purchase', requestId: 'issue', quoteId }, gateway, () => at);
  await expect(request('a'.repeat(64), now)).rejects.toMatchObject({ reason: 'quote_changed' });
  const first = await membershipQuote(store, auth, data, () => now);
  const latest = await membershipQuote(store, auth, data, () => now + 1);
  await membershipQuote(store, auth, { ...data, upgradeMode: 'next_term' }, () => now + 2);
  await expect(request(first.quoteId, now + 3)).rejects.toMatchObject({ reason: 'quote_changed' });
  await expect(request(latest.quoteId, now + 5 * 60000 + 1)).rejects.toMatchObject({ reason: 'quote_expired' });
  expect(bills.size).toBe(1);
  await expect(request(latest.quoteId, now + 4)).resolves.toMatchObject({ upgradeMode: 'immediate' });
});

it('routes a paid upgrade to review if the original Basic receipt can no longer be verified', async () => {
  const { store, gateway, activate, clear } = fixture();
  const basic = await activate('basic');
  const now = expiry - 2 * day;
  const data = { ...scope, planId: 'premium', upgradeMode: 'immediate' };
  const { quoteId } = await membershipQuote(store, auth, data, () => now);
  const upgrade = await createMembershipPayment(store, auth, { ...data, intent: 'purchase', requestId: 'lost-evidence', quoteId }, gateway, () => now);
  store.documents.delete(`orgs/${organizationId}/transactions/${basic.transactionId}`);
  await expect(clear(upgrade, now + 1)).resolves.toMatchObject({ paymentStatus: 'cleared', fulfilmentStatus: 'reconciliation_required' });
  expect(store.documents.get(accountPath)).toMatchObject({ planId: 'basic', expiresAtMillis: expiry });
});
