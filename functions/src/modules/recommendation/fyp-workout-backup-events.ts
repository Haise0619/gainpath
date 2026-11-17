import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { workoutSummaryConsentReady,workoutRecommendationGeminiKey } from './workout-backup-recommendation-events';
import { DomainError } from '../../platform/errors';
import { createFypDatasetBackend } from '../dataset/fyp-backend';
import { resolveFypRuntimeRelease, type FypRuntimeReleaseGrant } from '../dataset/fyp-runtime-release';

/** The trusted event reconstructs current server identity. The existing backend
 * verifies the assignment, Auth creation binding and release/seed ownership. */
async function eventContext(options: {
  db: Firestore; auth: Pick<Auth, 'getUser'>; release?: FypRuntimeReleaseGrant;
}, memberId: string) {
  const user = await options.auth.getUser(memberId);
  if (!user.emailVerified || user.disabled) return null;
  const incoming = {
    app: {appId: 'server-workout-backup-event'}, data: {schemaVersion: 1},
    auth: {uid: memberId, token: {email: user.email, email_verified: true,
      auth_time: Math.floor(Date.now() / 1000), fypAuthCreatedAtMillis: user.customClaims?.fypAuthCreatedAtMillis}},
  };
  return {backend: createFypDatasetBackend(options), incoming};
}

type EventOptions = Parameters<typeof eventContext>[0];
export async function processFypWorkoutBackup(options: EventOptions, memberId: string, key: string) {
  const context = await eventContext(options, memberId);
  return context ? context.backend.workoutSaved(context.incoming, key) : [];
}

export async function processFypWorkoutHistory(options: EventOptions, memberId: string) {
  const context = await eventContext(options, memberId);
  if (!context) return;
  let afterId: string|null = null;
  for (let page = 0; page < 20; page++) {
    const result = await context.backend.command({...context.incoming, data: {
      schemaVersion: 1, operation: 'workout.member.history.replay',
      data: {schemaVersion: 1, organizationId: 'gainpath', afterId},
    }}) as {nextAfterId: string|null};
    afterId = result.nextAfterId;
    if (afterId === null) return;
  }
}

async function handleEvent(work: () => Promise<unknown>) {
  try { await work(); }
  catch (error) {
    if (error instanceof DomainError && ['permission-denied','failed-precondition'].includes(error.code) ||
      (error as {code?:string}).code === 'auth/user-not-found') return;
    throw error;
  }
}

export const module13FypWorkoutBackupCreated = onDocumentCreated({
  region: 'asia-southeast1',
  document: 'orgs/{organizationId}/cohorts/{cohortId}/members/{memberId}/workoutBackups/{key}',
  retry: true, maxInstances: 2, timeoutSeconds: 120,
  secrets:[workoutRecommendationGeminiKey],
}, async event => {
  const {organizationId, cohortId, memberId, key} = event.params;
  if (organizationId !== 'gainpath' || cohortId !== 'fyp-v1' || !key.startsWith('session-')) return;
  await handleEvent(async () => {
    const db = getFirestore(), release = await resolveFypRuntimeRelease(db);
    return processFypWorkoutBackup({db, auth: getAuth(), release}, memberId, key);
  });
});

export const module13FypWorkoutConsentChanged = onDocumentWritten({
  region: 'asia-southeast1', document: 'orgs/{organizationId}/cohorts/{cohortId}/recommendationConsent/{memberId}',
  retry: true, maxInstances: 1, timeoutSeconds: 120,
  secrets:[workoutRecommendationGeminiKey],
}, async event => {
  if (event.params.organizationId !== 'gainpath' || event.params.cohortId !== 'fyp-v1' ||
    !workoutSummaryConsentReady(event.data?.after.data()) || workoutSummaryConsentReady(event.data?.before.data())) return;
  await handleEvent(async () => {
    const db = getFirestore(), release = await resolveFypRuntimeRelease(db);
    await processFypWorkoutHistory({db, auth: getAuth(), release}, event.params.memberId);
  });
});
