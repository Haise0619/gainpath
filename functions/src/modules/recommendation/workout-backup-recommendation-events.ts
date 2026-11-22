import {cloudEvent} from '@google-cloud/functions-framework';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import {defineSecret} from 'firebase-functions/params';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { createCanonicalRecommendationLifecycle, type CanonicalLifecycleDependencies } from './canonical-recommendation-lifecycle';
import { getWorkoutBackupRuntime } from './workout-backup-recommendation-runtime';
export const workoutRecommendationGeminiKey=defineSecret('GEMINI_API_KEY');

export async function evaluateSavedWorkout(deps: CanonicalLifecycleDependencies, org: string, member: string, key: string) {
  if (org !== 'gainpath' || !/^session-[A-Za-z0-9_-]{1,128}$/.test(key)) {
    console.info('module13_workout_event_rejected', {
      organizationMatches: org === 'gainpath',
      keyMatches: /^session-[A-Za-z0-9_-]{1,128}$/.test(key),
    });
    return [];
  }
  try {
    const delivered = await createCanonicalRecommendationLifecycle(deps).backup(org, member, key);
    console.info('module13_workout_event_completed', {delivered: delivered.length});
    return delivered;
  } catch (error) {
    // Missing consent, stale membership, and deleted identities are terminal
    // for this event. Infrastructure failures remain eligible for retry.
    if (error instanceof DomainError && ['failed-precondition', 'permission-denied'].includes(error.code) ||
      (error as {code?: string}).code === 'auth/user-not-found') {
      console.info('module13_workout_event_ineligible', {code: (error as {code?: string}).code});
      return [];
    }
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

/** Resolve the actual trigger document. Eventarc may omit SDK wildcard params. */
export function workoutEventPath(path: string | undefined, params: Record<string,string>) {
  const match = path?.match(new RegExp('^orgs/([A-Za-z0-9_-]{1,128})/members/([A-Za-z0-9_-]{1,128})/workoutBackups/(session-[A-Za-z0-9_-]{1,128})$'));
  if (!match) return null;
  const values = {organizationId:match[1],memberId:match[2],key:match[3]};
  if (Object.entries(values).some(([key,value])=>params[key]!==undefined && params[key]!==value)) return null;
  return values;
}

export const module13WorkoutBackupCreated = onDocumentCreated({
  region: 'asia-southeast1', document: 'orgs/{organizationId}/members/{memberId}/workoutBackups/{key}',
  retry: true, maxInstances: 2, timeoutSeconds: 120,
  secrets:[workoutRecommendationGeminiKey],
}, async event => {
  const resolved = workoutEventPath(event.data?.ref.path, event.params);
  if (!resolved) {
    console.info('module13_workout_event_path_unavailable', {
      hasSnapshot: !!event.data, hasDocumentPath: !!event.data?.ref.path,
      hasSubject: !!event.subject,
    });
    return;
  }
  const {organizationId, memberId, key} = resolved;
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
  secrets:[workoutRecommendationGeminiKey],
}, async event => {
  if (event.params.organizationId !== 'gainpath' ||
    !workoutSummaryConsentReady(event.data?.after.data()) || workoutSummaryConsentReady(event.data?.before.data())) return;
  const deps = workoutRecommendationDependencies();
  const root = `orgs/gainpath/members/${event.params.memberId}/workoutBackups`;
  const rows = await getFirestore().collection(root).orderBy('updatedAtMillis', 'desc').limit(20).get();
  for (const row of rows.docs) await evaluateSavedWorkout(deps, 'gainpath', event.params.memberId, row.id);
});

// Declare CloudEvent transport explicitly for Functions Framework production startup.
cloudEvent('module13WorkoutBackupCreated', (raw: unknown) => module13WorkoutBackupCreated(raw as Parameters<typeof module13WorkoutBackupCreated>[0]));
cloudEvent('module13WorkoutConsentChanged', (raw: unknown) => module13WorkoutConsentChanged(raw as Parameters<typeof module13WorkoutConsentChanged>[0]));
