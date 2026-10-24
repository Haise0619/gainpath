import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { defineString } from 'firebase-functions/params';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { coachCommandError } from '../coaching/coach-profile-callables';
import { readCoachIdentity } from '../coaching/coach-identity-reader';
import { membershipAccess, verifyMemberMembership } from './membership-access-service';
const organization = defineString('BILLPLZ_SANDBOX_ORGANIZATION_ID', { default: 'gainpath' });
function check(data: unknown) {
  if (!data || typeof data !== 'object' || (data as Record<string, unknown>).organizationId !== organization.value()) throw new DomainError('permission-denied', 'Organization unavailable.');
}
export const getMembershipAccessCommand = onCall({ enforceAppCheck: true }, async r => {
  try { check(r.data); return await membershipAccess(new FirestoreStore(getFirestore()), r.auth, r.data, readCoachIdentity); }
  catch (e) { throw coachCommandError(e); }
});
export const verifyMemberMembershipCommand = onCall({ enforceAppCheck: true }, async r => {
  try { check(r.data); return await verifyMemberMembership(new FirestoreStore(getFirestore()), r.auth, r.data, readCoachIdentity); }
  catch (e) { throw coachCommandError(e); }
});
