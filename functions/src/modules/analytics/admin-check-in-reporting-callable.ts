import {getAuth} from 'firebase-admin/auth';
import {getFirestore, FieldPath} from 'firebase-admin/firestore';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {DomainError} from '../../platform/errors';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {adminCheckInReport} from './admin-check-in-reporting';

// Prepared read-only aggregates; no producer/policy/reward changes or deployment.
export const adminCheckInReportingCommand = onCall({region: 'asia-southeast1', enforceAppCheck: true,
  timeoutSeconds: 60, maxInstances: 5}, async request => {
  try {
    const auth = request.auth ? {uid: request.auth.uid, token: request.auth.token} : undefined;
    if (!auth || auth.token.email_verified !== true || typeof auth.token.email !== 'string' || !Number.isSafeInteger(auth.token.auth_time)) throw new DomainError('unauthenticated', 'Sign in with a verified account.');
    const fresh = async () => {
      const user = await getAuth().getUser(auth.uid), validAfter = user.tokensValidAfterTime ? Date.parse(user.tokensValidAfterTime) : 0;
      if (user.disabled || !user.emailVerified || user.email !== auth.token.email || !Number.isFinite(validAfter) || Number(auth.token.auth_time) * 1000 < validAfter) throw new DomainError('unauthenticated', 'Your account session changed.');
    };
    await fresh();
    const org = requiredIdentifier(request.data?.organizationId, 'organizationId'), db = getFirestore();
    const page = async (path: string, after: string | undefined, limit: number) => {
      let q = db.collection(path).orderBy(FieldPath.documentId()).limit(limit); if (after) q = q.startAfter(after);
      return (await q.get()).docs.map(d => ({id: d.id, data: d.data()}));
    };
    const result = await adminCheckInReport(new FirestoreStore(db), auth, request.data, {
      members: (after, limit) => page(`orgs/${org}/members`, after, limit),
      claims: (uid, after, limit) => page(`orgs/${org}/appCheckInProfiles/${uid}/claims`, after, limit),
    });
    await fresh(); return result;
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('unavailable', 'Check-in analytics could not be loaded. No partial totals were returned.');
  }
});
