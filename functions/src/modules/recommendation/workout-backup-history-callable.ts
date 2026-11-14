import { FieldPath, getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { InputValidationError } from '../../platform/validation';
import { keys, object } from '../workouts/workout-backup-validation';
import { authorizeRecommendationSession, recommendationCommandError } from './recommendation-configuration';
import { requireRecommendationMember } from './recommendation-member-service';
import { evaluateSavedWorkout, workoutRecommendationDependencies } from './workout-backup-recommendation-events';
import type { InsightsRequest } from './exercise-insights-contracts';

// A member can replay only their own already-synced summaries. The trigger
// and replay share the same stable identities, consent checks and receipts.
export const module13ReplayWorkoutHistory = onCall({
  region: 'asia-southeast1', enforceAppCheck: true, timeoutSeconds: 120, maxInstances: 1,
}, async request => {
  try {
    const q = object(request.data);
    keys(q, ['schemaVersion', 'afterId']);
    const after = q.afterId === null ? null : q.afterId;
    if (q.schemaVersion !== 1 || (after !== null && (typeof after !== 'string' || !/^session-[A-Za-z0-9_-]{1,128}$/.test(after)))) {
      throw new InputValidationError('Invalid workout history cursor.');
    }
    const deps = workoutRecommendationDependencies();
    const auth = await authorizeRecommendationSession(request as unknown as InsightsRequest, deps);
    const org = 'gainpath';
    await deps.store.transact(tx => requireRecommendationMember(tx, auth, org));
    let query = getFirestore().collection(`orgs/${org}/members/${auth.uid}/workoutBackups`)
      .orderBy(FieldPath.documentId()).endAt('session-\uf8ff');
    query = after ? query.startAfter(after) : query.startAt('session-');
    const page = await query.limit(5).get();
    let delivered = 0;
    for (const row of page.docs) delivered += (await evaluateSavedWorkout(deps, org, auth.uid, row.id)).length;
    return {schemaVersion: 1, checked: page.size, delivered, nextAfterId: page.size === 5 ? page.docs[4].id : null};
  } catch (error) {
    throw recommendationCommandError(error);
  }
});
