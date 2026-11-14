import {FieldPath, type Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import {evaluateSavedWorkout} from './workout-backup-recommendation-events';
import type {CanonicalLifecycleDependencies} from './canonical-recommendation-lifecycle';

/** Owner authorization is performed by the Member API before this service.
 * Trigger and replay use identical consent, cooldown and delivery receipts. */
export async function replayWorkoutHistory(db: Firestore, deps: CanonicalLifecycleDependencies,
  org: string, member: string, after: unknown) {
  if (after !== null && (typeof after !== 'string' || !/^session-[A-Za-z0-9_-]{1,128}$/.test(after))) {
    throw new DomainError('invalid-argument', 'Invalid workout history cursor.');
  }
  let query = db.collection(`orgs/${org}/members/${member}/workoutBackups`)
    .orderBy(FieldPath.documentId()).endAt('session-\uf8ff');
  query = after ? query.startAfter(after) : query.startAt('session-');
  const page = await query.limit(5).get();
  let delivered = 0;
  for (const row of page.docs) delivered += (await evaluateSavedWorkout(deps, org, member, row.id)).length;
  return {schemaVersion: 1, checked: page.size, delivered, nextAfterId: page.size === 5 ? page.docs[4].id : null};
}
