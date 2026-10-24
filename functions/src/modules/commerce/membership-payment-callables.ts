import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { coachCommandError } from '../coaching/coach-profile-callables';
import { readCoachIdentity } from '../coaching/coach-identity-reader';
import { BillplzSandboxGateway } from './billplz-sandbox';
import { membershipOverview, membershipQuote, createMembershipPayment, readMembershipPayment, membershipRefund } from './membership-payment-service';

const apiKey = defineSecret('BILLPLZ_SANDBOX_API_KEY');
const collection = defineString('BILLPLZ_SANDBOX_COLLECTION_ID', { default: '' });
const organization = defineString('BILLPLZ_SANDBOX_ORGANIZATION_ID', { default: 'gainpath' });
const enabled = defineString('BILLPLZ_SANDBOX_ENABLED', { default: 'false' });
const store = () => new FirestoreStore(getFirestore());
function check(data: unknown) {
  if (!data || typeof data !== 'object' || (data as Record<string, unknown>).organizationId !== organization.value()) throw new DomainError('permission-denied', 'Organization unavailable.');
}
function gateway() {
  if (enabled.value() !== 'true') throw new DomainError('unavailable', 'Sandbox checkout disabled.');
  const project = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
  if (!project || !/^[a-z0-9-]+$/.test(project)) throw new DomainError('unavailable', 'Sandbox configuration unavailable.');
  return new BillplzSandboxGateway({ apiKey: apiKey.value(), collectionId: collection.value(), callbackUrl: `https://us-central1-${project}.cloudfunctions.net/paymentWebhook`, redirectUrl: `https://us-central1-${project}.cloudfunctions.net/billplzSandboxReturn` });
}
// Preserve the reviewed deployed runtime settings rather than emitting SDK
// reset-to-default fields during a selective source update.
export const getMembershipOverviewCommand = onCall({ enforceAppCheck: true, preserveExternalChanges: true }, async r => {
  try {
    check(r.data); const db = getFirestore();
    return await membershipOverview(store(), r.auth, r.data, {
      plans: async org => (await db.collection(`orgs/${org}/membershipPlans`).limit(100).get()).docs.map(d => ({ id: d.id, data: d.data() })),
      payments: async (org, uid) => (await db.collection(`orgs/${org}/transactions`).where('memberId', '==', uid).get()).docs.map(d => ({ id: d.id, data: d.data() })),
    }, Date.now, readCoachIdentity);
  } catch (e) { throw coachCommandError(e); }
});
export const getMembershipQuoteCommand = onCall({ enforceAppCheck: true }, async r => {
  try { check(r.data); return await membershipQuote(store(), r.auth, r.data); } catch (e) { throw coachCommandError(e); }
});
export const createMembershipPaymentCommand = onCall({ enforceAppCheck: true, secrets: [apiKey] }, async r => {
  try { check(r.data); return await createMembershipPayment(store(), r.auth, r.data, gateway()); } catch (e) { throw coachCommandError(e); }
});
export const getMembershipPaymentCommand = onCall({ enforceAppCheck: true, secrets: [apiKey] }, async r => {
  try { check(r.data); return await readMembershipPayment(store(), r.auth, r.data, gateway(), Date.now, readCoachIdentity); } catch (e) { throw coachCommandError(e); }
});
export const requestMembershipRefundCommand = onCall({ enforceAppCheck: true }, async r => {
  try { check(r.data); return await membershipRefund(store(), r.auth, r.data); } catch (e) { throw coachCommandError(e); }
});
