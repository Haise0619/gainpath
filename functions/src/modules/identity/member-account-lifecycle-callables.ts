import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { defineBoolean } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { cancelMemberDeactivation, readMemberAccountLifecycle, requestMemberDeactivation, type LifecycleAuth } from './member-account-lifecycle';

// Explicitly opt in only after the retention/reactivation policy is approved.
// This parameter never enables data deletion; no purge worker is exported.
const grace30DaysApproved = defineBoolean('MEMBER_LIFECYCLE_GRACE30_DAYS_APPROVED', { default: false });
interface CurrentIdentity {
  uid: string; disabled: boolean; emailVerified: boolean; email?: string;
  tokensValidAfterTime?: string;
}
export async function requireCurrentLifecycleIdentity(auth: LifecycleAuth | undefined,
  readIdentity: (uid: string) => Promise<CurrentIdentity>): Promise<LifecycleAuth> {
  if (!auth || auth.token.email_verified !== true || typeof auth.token.email !== 'string'
    || !Number.isSafeInteger(auth.token.auth_time)) throw new DomainError('unauthenticated', 'Sign in with your verified account.');
  let identity: CurrentIdentity;
  try { identity = await readIdentity(auth.uid); }
  catch (error) {
    if (error && typeof error === 'object' && 'code' in error && error.code === 'auth/user-not-found') {
      throw new DomainError('unauthenticated', 'Your account session changed. Sign in again.');
    }
    throw new DomainError('unavailable', 'Account verification is temporarily unavailable. Retry shortly.');
  }
  const validAfter = identity.tokensValidAfterTime === undefined ? 0 : Date.parse(identity.tokensValidAfterTime);
  if (identity.uid !== auth.uid || identity.disabled || !identity.emailVerified || identity.email !== auth.token.email
    || !Number.isFinite(validAfter) || Number(auth.token.auth_time) * 1000 < validAfter) {
    throw new DomainError('unauthenticated', 'Your account session changed. Sign in again.');
  }
  return auth;
}
export function lifecycleCommandError(error: unknown): HttpsError {
  if (error instanceof DomainError) return new HttpsError(error.code, error.message);
  return new HttpsError('internal', 'The account operation could not be confirmed. Sign in again and reload account status before retrying.');
}
function dependencies() {
  return { grace30DaysApproved: grace30DaysApproved.value(), revokeRefreshTokens: (uid: string) => getAuth().revokeRefreshTokens(uid) };
}
const callableOptions = { enforceAppCheck: true, timeoutSeconds: 30 } as const;
export const getMemberAccountLifecycleCommand = onCall(callableOptions, async request => {
  try {
    const auth = await requireCurrentLifecycleIdentity(request.auth, uid => getAuth().getUser(uid));
    return await readMemberAccountLifecycle(new FirestoreStore(getFirestore()), auth, request.data, dependencies());
  } catch (error) { throw lifecycleCommandError(error); }
});
export const requestMemberDeactivationCommand = onCall(callableOptions, async request => {
  try {
    const auth = await requireCurrentLifecycleIdentity(request.auth, uid => getAuth().getUser(uid));
    return await requestMemberDeactivation(new FirestoreStore(getFirestore()), auth, request.data, dependencies());
  } catch (error) { throw lifecycleCommandError(error); }
});
export const cancelMemberDeactivationCommand = onCall(callableOptions, async request => {
  try {
    const auth = await requireCurrentLifecycleIdentity(request.auth, uid => getAuth().getUser(uid));
    return await cancelMemberDeactivation(new FirestoreStore(getFirestore()), auth, request.data, dependencies());
  } catch (error) { throw lifecycleCommandError(error); }
});
