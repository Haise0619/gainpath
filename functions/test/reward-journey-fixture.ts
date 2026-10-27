import {MemoryStore} from './memory-store';
export const org = 'gainpath', now = 1800000000000, DAY = 86400000;
export const auth = {uid: 'member', token: {email_verified: true, auth_time: now / 1000}}, adminAuth = {...auth, uid: 'admin'};
export const identity = async () => ({exists: true, disabled: false, emailVerified: true});
export const path = (kind: string, id: string) => `orgs/${org}/${kind}/${id}`;
export function seed() {
  const store = new MemoryStore(); store.documents.set('orgs/' + org, {status: 'active'});
  for (const uid of ['member', 'other', 'admin']) {
    store.documents.set('users/' + uid, {organizationId: org});
    store.documents.set(path('members', uid), {organizationId: org, userId: uid, role: uid === 'admin' ? 'admin' : 'member', status: 'active', branchIds: []});
  }
  store.documents.set(path('membershipAccounts', 'member'), {organizationId: org, memberId: 'member', planId: 'basic', expiresAtMillis: now + 30 * DAY, lastTransactionId: 'paid'});
  store.documents.set(path('transactions', 'paid'), {schemaVersion: 1, transactionId: 'paid', organizationId: org, memberId: 'member', planId: 'basic', kind: 'MembershipPurchase', environment: 'sandbox', provider: 'billplz', currency: 'MYR', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed', billId: 'test', collectionId: 'test', amountMinor: 8900, durationDays: 30, clearedAtMillis: now - 1, expiresAtMillis: now + 30 * DAY, planName: 'Synthetic Basic', benefits: []});
  store.documents.set(path('rewardBalances', 'member'), {schemaVersion: 1, organizationId: org, memberId: 'member', points: 1000, recentRedemptionIds: []});
  store.documents.set(path('rewardCatalog', 'item'), {schemaVersion: 1, revision: 1, title: 'Training bottle', description: 'A reusable training bottle', imageUrl: '', category: 'Merchandise', status: 'draft'});
  return store;
}
