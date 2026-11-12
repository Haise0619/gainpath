import { expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { membershipQuote, createMembershipPayment, readMembershipPayment, membershipRefund, membershipOverview } from '../src/modules/commerce/membership-payment-service';
const now = 1800000000000, base = { schemaVersion: 1, organizationId: 'gainpath' }, auth = { uid: 'member', token: { email_verified: true, auth_time: 100 } };
function fixture() { const s = new MemoryStore(); s.documents.set('orgs/gainpath', { status: 'active' }); s.documents.set('users/member', { organizationId: 'gainpath', email: 'fixture@example.invalid', accountLifecycle: { schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: 101 } }); s.documents.set('orgs/gainpath/members/member', { organizationId: 'gainpath', role: 'member', status: 'active', branchIds: [] }); for (const id of ['basic', 'elite'])
    s.documents.set(`orgs/gainpath/membershipPlans/${id}`, { active: true, name: id, currency: 'MYR', amountMinor: 8900, durationDays: 30, benefits: [], version: 'v1' }); return s; }
const gateway = { create: async () => { throw Error('Must not create'); }, get: async () => { throw Error('Must not fetch'); } };
it.each(['quote', 'create', 'read', 'refund'])('rejects stale session before %s', async (action) => { const s = fixture(); const work = action === 'quote' ? membershipQuote(s, auth, { ...base, planId: 'basic' }, () => now) : action === 'create' ? createMembershipPayment(s, auth, { ...base, planId: 'basic', intent: 'purchase', requestId: 'r' }, gateway, () => now) : action === 'read' ? readMembershipPayment(s, auth, { ...base, transactionId: 't' }, gateway, () => now) : membershipRefund(s, auth, { ...base, transactionId: 't', reason: 'Fixture reason', notes: '' }, () => now); await expect(work).rejects.toMatchObject({ code: 'permission-denied' }); });
it('rejects unsupported configured plan before provider reservation', async () => { const s = fixture(); const fresh = { ...auth, token: { ...auth.token, auth_time: 101 } }; await expect(membershipQuote(s, fresh, { ...base, planId: 'elite' }, () => now)).rejects.toMatchObject({ code: 'failed-precondition' }); });
it.each([undefined, 100, 100.5])('denies absent/stale/noninteger auth_time %s at a lifecycle boundary', async (auth_time) => { const s = fixture(); await expect(membershipQuote(s, { ...auth, token: { email_verified: true, auth_time } }, { ...base, planId: 'basic' }, () => now)).rejects.toMatchObject({ code: 'permission-denied' }); });
it.each([101, 102])('permits fresh auth_time %s at or after lifecycle boundary', async (auth_time) => { await expect(membershipQuote(fixture(), { ...auth, token: { email_verified: true, auth_time } }, { ...base, planId: 'basic' }, () => now)).resolves.toMatchObject({ planId: 'basic' }); });
it('returns original checkout after reauthentication without another bill', async () => { const s = fixture(); let creates = 0; const fresh = { ...auth, token: { email_verified: true, auth_time: 101 } }; const g = { get: gateway.get, create: async (x: {
        amountMinor: number;
        reference: string;
        organizationId: string;
    }) => { creates++; return { id: 'bill', collection_id: 'collection', amount: x.amountMinor, paid: false, paid_amount: 0, state: 'due' as const, url: 'https://www.billplz-sandbox.com/bills/bill', reference_1: x.reference, reference_2: x.organizationId }; } }; const input = { ...base, planId: 'basic', intent: 'purchase', requestId: 'r' }; const p = await createMembershipPayment(s, fresh, input, g, () => now); await expect(createMembershipPayment(s, { ...fresh, token: { ...fresh.token, auth_time: 102 } }, input, g, () => now)).resolves.toMatchObject({ transactionId: p.transactionId, billId: 'bill' }); expect(creates).toBe(1); });
it('reports changed quotation as explicitly safe to requote without reservation', async () => { const s = fixture(); const fresh = { ...auth, token: { email_verified: true, auth_time: 101 } }; await expect(createMembershipPayment(s, fresh, { ...base, planId: 'basic', intent: 'purchase', requestId: 'r', quoteId: 'stale' }, gateway, () => now)).rejects.toMatchObject({ reason: 'quote_changed', checkoutCreated: false }); expect([...s.documents.keys()].some(p => p.includes('/transactions/'))).toBe(false); });

it('checks fresh session before overview source reads', async () => {
 const s=fixture(); let reads=0;
 const reader={plans:async()=>{reads++;return [];},payments:async()=>{reads++;return [];}};
 await expect(membershipOverview(s,auth,base,reader,()=>now)).rejects.toMatchObject({code:'permission-denied'});
 expect(reads).toBe(0);
 await expect(membershipOverview(s,{...auth,token:{email_verified:true,auth_time:101}},base,reader,()=>now)).resolves.toMatchObject({entitlement:{effectiveTier:'free'}});
});
