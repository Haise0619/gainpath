import { getAuth } from 'firebase-admin/auth';
import { DomainError } from '../../platform/errors';
import type { CoachIdentityReader } from './coach-profile-service';

export const readCoachIdentity: CoachIdentityReader = async uid => {
  try {
    const user = await getAuth().getUser(uid);
    return { exists: true, disabled: user.disabled, emailVerified: user.emailVerified };
  } catch (error) {
    if ((error as { code?: string }).code === 'auth/user-not-found') return { exists: false, disabled: false, emailVerified: false };
    throw new DomainError('unavailable', 'Could not verify Coach account eligibility. Retry later.');
  }
};
