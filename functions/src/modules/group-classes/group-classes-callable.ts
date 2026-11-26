import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { InputValidationError } from '../../platform/validation';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { uploadRewardCover } from '../gamification/reward-cover-upload';
import { FirebaseRewardCoverStore } from '../gamification/reward-cover-storage';
import { groupClasses, type ClassStore } from './group-classes';

export const groupClassesCommand = onCall({ region: 'asia-southeast1', enforceAppCheck: true }, async request => {
  try {
    const db = getFirestore();
    if (request.data?.action === 'uploadCover') {
      const media = new FirebaseRewardCoverStore();
      return await uploadRewardCover(new FirestoreStore(db), request.auth, request.data, {
        upload: (path, bytes, type, hash) =>
          media.upload(path.replace('/rewardImages/', '/groupClassImages/'), bytes, type, hash),
      });
    }
    return await groupClasses(firestoreGroupClassStore(db), request.auth, request.data);
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('internal', 'Could not complete the group class request.');
  }
});

export function firestoreGroupClassStore(db: Firestore): ClassStore {
  return {
      transact: work => db.runTransaction(tx => work({
        get: async path => (await tx.get(db.doc(path))).data(),
        getAll: async paths => paths.length ? (await tx.getAll(...paths.map(path => db.doc(path)))).map(row => row.data()) : [],
        list: async path => {
          const rows = (await tx.get(db.collection(path).limit(501))).docs;
          if (rows.length > 500) throw new DomainError('resource-exhausted', 'This class directory exceeds the current review limit.');
          return rows.map(row => ({ id: row.id, data: row.data() }));
        },
        create: (path, data) => { tx.create(db.doc(path), data); },
        set: (path, data) => { tx.set(db.doc(path), data); },
        remove: path => { tx.delete(db.doc(path)); },
      })),
  };
}
