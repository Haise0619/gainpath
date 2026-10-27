import { getAuth } from 'firebase-admin/auth';
import { FieldPath, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { InputValidationError } from '../../platform/validation';
import { backupWorkout, listWorkoutBackups, type BackupStore } from './workout-backup';
// Prepared selectively; no accepted-workout policy or reward producer is enabled.
export const workoutBackupCommand = onCall({ region: 'asia-southeast1', enforceAppCheck: true, timeoutSeconds: 60, maxInstances: 5 }, async (request) => {
    try {
        const auth = request.auth ? { uid: request.auth.uid, token: request.auth.token } : undefined;
        if (!auth || auth.token.email_verified !== true || typeof auth.token.email !== 'string' || !Number.isSafeInteger(auth.token.auth_time))
            throw new DomainError('unauthenticated', 'Sign in with a verified account.');
        const identity = await getAuth().getUser(auth.uid);
        const validAfter = identity.tokensValidAfterTime ? Date.parse(identity.tokensValidAfterTime) : 0;
        if (identity.disabled || !identity.emailVerified || identity.email !== auth.token.email || !Number.isFinite(validAfter) || Number(auth.token.auth_time) * 1000 < validAfter)
            throw new DomainError('unauthenticated', 'Your account session changed.');
        const db = getFirestore(), base = new FirestoreStore(db);
        const store: BackupStore = { transact: work => base.transact(work), list: async (prefix, after, limit, kind) => {
                let query = db.collection(prefix).orderBy(FieldPath.documentId()).endAt(kind+'-\uf8ff').limit(limit);
                if (after)
                    query = query.startAfter(after);
                else query = query.startAt(kind+'-');
                return (await query.get()).docs.map(d => d.data());
            } };
        const data = request.data as {
            action?: unknown;
            command?: unknown;
        };
        if (!data || typeof data !== 'object' || Object.keys(data).length !== 2 || !('command' in data))
            throw new InputValidationError('Invalid backup envelope.');
        if (data.action === 'save')
            return await backupWorkout(store, auth, data.command);
        if (data.action === 'list')
            return await listWorkoutBackups(store, auth, data.command);
        throw new InputValidationError('Invalid backup action.');
    }
    catch (error) {
        if (error instanceof DomainError)
            throw new HttpsError(error.code, error.message);
        if (error instanceof InputValidationError)
            throw new HttpsError('invalid-argument', error.message);
        throw new HttpsError('unavailable', 'Backup unavailable. Your local results are retained.');
    }
});
