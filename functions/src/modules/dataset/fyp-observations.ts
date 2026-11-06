import {requiredIdentifier} from '../../platform/validation';
import {digestOf, object, validateFictionalSessionPayload} from '../workouts/workout-backup-validation';
import {insightSourceError, projectValidatedSessionEvidence} from '../recommendation/workout-evidence';
import type {EvidenceScope, ExtractedWorkoutEvidence} from '../recommendation/exercise-insights-contracts';
import {requireFypRuntimeCapability,requireFypObservationScope, type FypRuntimeCapability} from './fyp-scope';

/** Separate, capability-gated fictional wire contract. Never transforms provenance. */
export function extractFypObservationEvidence(scope: EvidenceScope, raw: unknown, now: number,
  capability: FypRuntimeCapability | undefined): ExtractedWorkoutEvidence {
  try {
    if (!requireFypRuntimeCapability(capability, scope.organizationId)) throw insightSourceError();
    requireFypObservationScope(capability,scope.organizationId,scope.memberId);
    requiredIdentifier(scope.organizationId, 'organization'); requiredIdentifier(scope.memberId, 'member');
    const row = object(raw), data = object(row.data);
    if (!Number.isSafeInteger(now) || now < 0 || data.schemaVersion !== 1 || data.classification !== 'fictional_synthetic_observation'
        || data.kind !== 'session' || typeof data.payloadJson !== 'string' || !Number.isSafeInteger(data.updatedAtMillis)
        || Number(data.updatedAtMillis) < 0 || Number(data.updatedAtMillis) > now || typeof data.digest !== 'string' || !/^[a-f0-9]{64}$/.test(data.digest)) throw insightSourceError();
    const id = requiredIdentifier(data.id, 'observation');
    if (data.key !== `session-${id}`) throw insightSourceError();
    const payload = validateFictionalSessionPayload(id, scope.organizationId, scope.memberId, JSON.parse(data.payloadJson));
    if (digestOf(payload) !== data.digest) throw insightSourceError();
    const evidence = projectValidatedSessionEvidence(scope, payload, {recordKey: String(data.key), digest: data.digest, updatedAtMillis: Number(data.updatedAtMillis)});
    if (evidence.kind !== 'session' || evidence.endedAtMillis > now || evidence.endedAtMillis !== data.updatedAtMillis) throw insightSourceError();
    return evidence;
  } catch {throw insightSourceError();}
}
