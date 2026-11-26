import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { manageCompliance } from './compliance-service';

export const complianceCommand = onCall({
  region: 'asia-southeast1', enforceAppCheck: true,
}, async request => {
  try {
    return await manageCompliance(new FirestoreStore(getFirestore()), request.auth, request.data);
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    throw new HttpsError('internal', 'Could not complete the compliance request.');
  }
});
