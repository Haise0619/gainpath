import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { provisionMember } from './member-provisioning';

function displayNameFrom(data: unknown): string {
  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    throw new HttpsError('invalid-argument', 'request data must be an object.');
  }
  const value = data as Record<string, unknown>;
  if (value.schemaVersion !== 1 || Object.keys(value).some(key => !['schemaVersion', 'displayName'].includes(key))) {
    throw new HttpsError('invalid-argument', 'Only schemaVersion and displayName are accepted.');
  }
  if (typeof value.displayName !== 'string') {
    throw new HttpsError('invalid-argument', 'displayName is required.');
  }
  return value.displayName;
}

export const provisionMemberRegistration = onCall(async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const email = request.auth.token.email;
  if (typeof email !== 'string' || !email) {
    throw new HttpsError('failed-precondition', 'The authenticated account must have an email address.');
  }
  try {
    return await provisionMember(new FirestoreStore(getFirestore()), {
      userId: request.auth.uid,
      email,
      displayName: displayNameFrom(request.data),
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    throw new HttpsError('internal', 'The member account could not be provisioned.');
  }
});
