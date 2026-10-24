import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { expect, it } from 'vitest';
import { membershipPlan, membershipQuote } from '../src/modules/commerce/membership-payment-service';
import { MemoryStore } from './memory-store';
const proposal = JSON.parse(readFileSync(resolve(process.cwd(), '../docs/integration/module4-three-tier-catalogue-proposal.json'), 'utf8'));
it('records approved inactive staging while keeping activation and financial operations gated', () => {
  expect(proposal.approvalStatus).toBe('APPROVED_INACTIVE_STAGING_ONLY');
  expect(proposal.pricingAndDurationsApproved).toBe(true);
  expect(proposal.activationRequiresSeparateApproval).toBe(true);
  expect(proposal.free).toMatchObject({ derivedOnly: true, firestorePlanRecord: null, purchaseRequired: false, expiresAtMillis: null });
  expect(proposal.records.map((r: {path:string}) => r.path)).toEqual(['orgs/gainpath/membershipPlans/basic', 'orgs/gainpath/membershipPlans/premium']);
  expect(proposal.promoRecords).toEqual([]);
  expect(proposal.accountMutationsAuthorized).toBe(false);
  expect(proposal.financialUatAuthorized).toBe(false);
  expect(proposal.automaticRecurringBillingSupported).toBe(false);
});
it.each(['basic','premium'])('validates proposed inactive %s and quotes only a local active preview without writes', async id => {
  const record = proposal.records.find((r: {path:string}) => r.path.endsWith('/'+id)), data = record.data;
  expect(record.precondition).toEqual({ exists: false });
  expect(Object.keys(data).sort()).toEqual(['active','name','amountMinor','currency','durationDays','benefits','version'].sort());
  expect(data.active).toBe(false);
  expect(data.amountMinor).toBe(id === 'basic' ? 8900 : 12900);
  expect(data.durationDays).toBe(30);
  expect(() => membershipPlan(id,data)).toThrow();
  const store = new MemoryStore();
  store.documents.set('orgs/gainpath', {status:'active'});
  store.documents.set('users/fixture', {organizationId:'gainpath'});
  store.documents.set('orgs/gainpath/members/fixture', {organizationId:'gainpath',status:'active',role:'member',branchIds:[]});
  store.documents.set(record.path,{...data,active:true});
  const before = structuredClone([...store.documents]);
  expect(await membershipQuote(store,{uid:'fixture',token:{email_verified:true}},{schemaVersion:1,organizationId:'gainpath',planId:id},()=>1800000000000))
    .toMatchObject({amountMinor:data.amountMinor,currency:'MYR',durationDays:30,version:data.version});
  expect([...store.documents]).toEqual(before);
});
