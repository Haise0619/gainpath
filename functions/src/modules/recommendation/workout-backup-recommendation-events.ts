import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { createCanonicalRecommendationLifecycle, type CanonicalLifecycleDependencies } from './canonical-recommendation-lifecycle';
import { getWorkoutBackupRuntime } from './workout-backup-recommendation-runtime';

export async function evaluateSavedWorkout(deps: CanonicalLifecycleDependencies, org: string, member: string, key: string) {
  if (org !== 'gainpath' || !/^session-[A-Za-z0-9_-]{1,128}$/.test(key)) return [];
  try {
    return await createCanonicalRecommendationLifecycle(deps).backup(org, member, key);
  } catch (error) {
    // Missing consent, stale membership, and deleted identities are terminal
    // for this event. Infrastructure failures remain eligible for retry.
    if (error instanceof DomainError && ['failed-precondition', 'permission-denied'].includes(error.code) ||
      (error as {code?: string}).code === 'auth/user-not-found') return [];
    throw error;
  }
}

export function workoutRecommendationDependencies(): CanonicalLifecycleDependencies {
  const db = getFirestore();
  return {
    store: new FirestoreStore(db), runtime: getWorkoutBackupRuntime(),
    readAuthIdentity: async uid => {
      const user = await getAuth().getUser(uid);
      return {uid, email: user.email ?? '', emailVerified: user.emailVerified, disabled: user.disabled,
        tokensValidAfterMillis: user.tokensValidAfterTime ? Date.parse(user.tokensValidAfterTime) : 0};
    },
  };
}

export const module13WorkoutBackupCreated = onDocumentCreated({
  region: 'asia-southeast1', document: 'orgs/{organizationId}/members/{memberId}/workoutBackups/{key}',
  retry: true, maxInstances: 2, timeoutSeconds: 120,
}, async event => {
  const {organizationId, memberId, key} = event.params;
  await evaluateSavedWorkout(workoutRecommendationDependencies(), organizationId, memberId, key);
});

export function workoutSummaryConsentReady(raw: unknown) {
  const purposes = (raw as {purposes?: Record<string, {granted?: boolean; noticePolicyId?: string}>}|undefined)?.purposes;
  return ['exerciseInsights','recommendationGeneration','recommendationDelivery'].every(purpose =>
    purposes?.[purpose]?.granted === true && purposes[purpose].noticePolicyId === 'workout-backup-guidance-v1');
}

export const module13WorkoutConsentChanged = onDocumentWritten({
  region: 'asia-southeast1', document: 'orgs/{organizationId}/recommendationConsent/{memberId}',
  retry: true, maxInstances: 1, timeoutSeconds: 120,
}, async event => {
  if (event.params.organizationId !== 'gainpath' ||
    !workoutSummaryConsentReady(event.data?.after.data()) || workoutSummaryConsentReady(event.data?.before.data())) return;
  const deps = workoutRecommendationDependencies();
  const root = `orgs/gainpath/members/${event.params.memberId}/workoutBackups`;
  const rows = await getFirestore().collection(root).orderBy('updatedAtMillis', 'desc').limit(20).get();
  for (const row of rows.docs) await evaluateSavedWorkout(deps, 'gainpath', event.params.memberId, row.id);
});
