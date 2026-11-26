import { expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { materializeMembershipBill, membershipBillingView, cancelMembershipBilling } from '../src/modules/commerce/membership-billing';

it('creates one bill per expired term, ages it without accumulating debt, and honors cancellation', async () => {
  const store = new MemoryStore();
  const account = 'orgs/gainpath/membershipAccounts/member';
  const now = 1_800_000_000_000;
  const day = 86_400_000;
  store.documents.set(account, { organizationId:'gainpath', memberId:'member', planId:'basic', expiresAtMillis:now });
  store.documents.set('orgs/gainpath/membershipPlans/basic', { active:true, currency:'MYR', amountMinor:8900, durationDays:30 });
  const generate = (at:number) => store.transact(tx => materializeMembershipBill(tx, 'gainpath', 'member', at));
  const [first, duplicate] = await Promise.all([generate(now), generate(now)]);
  expect(first?.bill).toEqual(duplicate?.bill);
  expect(membershipBillingView(first, now)?.status).toBe('payment_due');
  expect(membershipBillingView(await generate(now + 60 * day), now + 60 * day)?.status).toBe('past_due');
  expect((await generate(now + 60 * day))?.bill).toEqual(first?.bill);
  await store.transact(tx => cancelMembershipBilling(tx, 'gainpath', 'member', now + day));
  store.documents.set(account, { organizationId:'gainpath', memberId:'member', planId:'basic', expiresAtMillis:now + 30 * day });
  expect((await generate(now + 31 * day))?.bill).toEqual(first?.bill);
  expect(store.documents.get(account)?.expiresAtMillis).toBe(now + 30 * day);
});
