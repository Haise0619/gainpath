import {FieldPath, type Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import type {EvidenceRow, ExerciseInsightsReader} from './exercise-insights-contracts';
import {EXERCISE_INSIGHTS_LIMITS} from './exercise-insights';
export interface LocalExerciseInsightsReview {readonly mode: 'local_reviewed_emulator'; readonly projectId: 'demo-gainpath-module13-a2'; readonly firestoreEmulatorHost: '127.0.0.1:18110'}
const identifier = (value: unknown): value is string => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const gateError = () => new DomainError('failed-precondition', 'Local reviewed exercise insight reader is disabled.');

/** Prepared local adapter only. Every read requires explicit review, the dedicated
 * loopback endpoint and the injected demo Firestore instance. No SDK bootstrap,
 * default app, production wrapper or collection-group history query is present.
 * Total scan/byte caps and fresh authority/consent checks remain in the handler.
 * Deliberately omits consentScopedBackups: legacy heads expose capture time only
 * inside payloadJson. V2 must fail closed before reading histories until reviewed
 * query metadata/index/migration work can enforce the boundary before reads. */
export function createFirestoreExerciseInsightsReader(options: {firestore: Firestore; organizationId: string; localReview?: LocalExerciseInsightsReview}): ExerciseInsightsReader {
  // Capture immutable bindings: mutating the caller's review object cannot enable a reader.
  const {firestore, organizationId} = options, review = options.localReview && {...options.localReview};
  const authorize = (requestedOrganization: string) => {
    if (!review || review.mode !== 'local_reviewed_emulator' || review.projectId !== 'demo-gainpath-module13-a2' ||
      review.firestoreEmulatorHost !== '127.0.0.1:18110' || process.env.FIRESTORE_EMULATOR_HOST !== review.firestoreEmulatorHost) throw gateError();
    if (!identifier(organizationId) || !identifier(requestedOrganization)) throw new DomainError('invalid-argument', 'Invalid exercise insight reader scope.');
    if (requestedOrganization !== organizationId) throw new DomainError('permission-denied', 'Exercise insight reader organization does not match.');
    // The installed Google Cloud SDK exposes this getter at runtime; the Admin
    // facade's bundled TypeScript declaration omits it. Missing binding fails closed.
    try {
      // Inspect the effective installed SDK transport, not only today's env: an
      // already-created client can retain a different endpoint. Unknown SDK
      // settings fail closed; an SDK upgrade must reverify this local adapter.
      const binding = firestore as unknown as {readonly projectId?: unknown;
        readonly _settings?: {readonly servicePath?: unknown; readonly port?: unknown; readonly ssl?: unknown}};
      if (binding.projectId !== review.projectId || binding._settings?.servicePath !== '127.0.0.1' ||
        binding._settings?.port !== 18110 || binding._settings?.ssl !== false) throw gateError();
    } catch {throw gateError();}
  };
  const page = async (path: string, after: string | undefined, limit: number, maximum: number): Promise<readonly EvidenceRow[]> => {
    if ((after !== undefined && !identifier(after)) || !Number.isSafeInteger(limit) || limit < 1 || limit > maximum) {
      throw new DomainError('invalid-argument', 'Invalid bounded exercise insight page.');
    }
    try {
      let query = firestore.collection(path).orderBy(FieldPath.documentId(), 'asc').limit(limit);
      if (after !== undefined) query = query.startAfter(after);
      const snapshot = await query.get();
      const rows = snapshot.docs.map(doc => ({id: doc.id, data: doc.data()}));
      let previous = after;
      if (rows.length > limit) throw Error('Invalid source page');
      for (const row of rows) {
        if (!identifier(row.id) || (previous !== undefined && row.id <= previous)) throw Error('Invalid source order');
        previous = row.id;
      }
      return rows;
    } catch {
      // Never propagate SDK resource paths, payloads, account IDs or provider details.
      throw new DomainError('unavailable', 'Exercise insights are temporarily unavailable.');
    }
  };
  return {
    members: async (requestedOrganization, after, limit) => {
      authorize(requestedOrganization);
      return page(`orgs/${organizationId}/members`, after, limit, EXERCISE_INSIGHTS_LIMITS.memberPage);
    },
    backups: async (scope, after, limit) => {
      authorize(scope.organizationId);
      if (!identifier(scope.memberId)) throw new DomainError('invalid-argument', 'Invalid exercise insight reader scope.');
      // Heads only. Revisions and unrelated Members/orgs are never scanned.
      return page(`orgs/${organizationId}/members/${scope.memberId}/workoutBackups`, after, limit, EXERCISE_INSIGHTS_LIMITS.backupPage);
    },
  };
}
