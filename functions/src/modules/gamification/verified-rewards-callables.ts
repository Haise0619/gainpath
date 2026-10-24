import { getFirestore } from 'firebase-admin/firestore';
import { defineString } from 'firebase-functions/params';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { coachCommandError } from '../coaching/coach-profile-callables';
import { readCoachIdentity } from '../coaching/coach-identity-reader';
import { rewardsCommand } from './verified-rewards-service';

const organization = defineString('VERIFIED_REWARDS_ORGANIZATION_ID', { default: '' });
/** One scoped command surface; source production and policy publication are deliberately separate. */
export const verifiedRewardsCommand = onCall({ enforceAppCheck: true }, async request => {
  try {
    if (!request.app) throw new DomainError('unauthenticated', 'App verification required.');
    requireVerifiedEmail(request.auth);
    if (!organization.value() || request.data?.organizationId !== organization.value()) throw new DomainError('permission-denied', 'Rewards organization unavailable.');
    return await rewardsCommand(new FirestoreStore(getFirestore()), request.auth, request.data, readCoachIdentity);
  } catch (error) { throw coachCommandError(error); }
});
