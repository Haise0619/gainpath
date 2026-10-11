import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import type { AcknowledgeWorkoutConsentV1, RevokeWorkoutConsentV1, SubmitWorkoutSessionV2 } from './contracts';

export const WORKOUT_CONSENT_VERSION = 'pose-local-summary-v1';
const maximumTime = 8639999996400000;
const maximumDuration = 86400000;
function object(input: unknown, keys: readonly string[]): Record<string, unknown> {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new InputValidationError('Workout request must be an object.');
  }
  const value = input as Record<string, unknown>;
  if (Object.keys(value).length !== keys.length ||
      !keys.every(key => Object.prototype.hasOwnProperty.call(value, key))) {
    throw new InputValidationError('Unexpected or missing workout request fields.');
  }
  return value;
}
function integer(value: unknown, name: string, minimum: number, maximum: number): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new InputValidationError(`Invalid workout integer: ${name}`);
  }
  return value;
}
function consentEnvelope(value: Record<string, unknown>) {
  if (value.schemaVersion !== 1 || value.consentVersion !== WORKOUT_CONSENT_VERSION) {
    throw new InputValidationError('Unsupported workout consent version.');
  }
  return {
    schemaVersion: 1 as const, requestId: requiredIdentifier(value.requestId, 'requestId'),
    organizationId: requiredIdentifier(value.organizationId, 'organizationId'),
    memberId: requiredIdentifier(value.memberId, 'memberId'),
    consentVersion: WORKOUT_CONSENT_VERSION as typeof WORKOUT_CONSENT_VERSION,
  };
}
export function parseAcknowledgeWorkoutConsent(input: unknown): AcknowledgeWorkoutConsentV1 {
  const value = object(input, ['schemaVersion', 'requestId', 'organizationId', 'memberId', 'consentVersion', 'consented']);
  if (value.consented !== true) throw new InputValidationError('Explicit workout consent is required.');
  return { ...consentEnvelope(value), consented: true };
}
export function parseRevokeWorkoutConsent(input: unknown): RevokeWorkoutConsentV1 {
  const value = object(input, ['schemaVersion', 'requestId', 'organizationId', 'memberId', 'consentVersion', 'acknowledgementId']);
  return { ...consentEnvelope(value), acknowledgementId: requiredIdentifier(value.acknowledgementId, 'acknowledgementId') };
}
export function parseSubmitWorkoutSession(input: unknown): SubmitWorkoutSessionV2 {
  const value = object(input, ['schemaVersion', 'requestId', 'organizationId', 'memberId', 'sessionId',
    'exerciseId', 'startedAtMillis', 'endedAtMillis', 'repetitions', 'formScorePercent',
    'trackedDurationMillis', 'rejectedDurationMillis', 'scoringVersion', 'detectorVersion',
    'consentVersion', 'publishedRoutineId', 'detectorId', 'consentAcknowledgementId', 'provenance', 'cameraView']);
  if (value.schemaVersion !== 2 || value.provenance !== 'real_camera' || value.cameraView !== 'side' ||
      value.consentVersion !== WORKOUT_CONSENT_VERSION || value.memberId === 'demo-user' || value.organizationId === 'demo-org' ||
      ['simulated', 'demo', 'fixture', 'unknown', 'recorded_fixture'].includes(String(value.detectorId))) {
    throw new InputValidationError('Unsupported real workout identity/provenance/version.');
  }
  const startedAtMillis = integer(value.startedAtMillis, 'startedAtMillis', 1, maximumTime);
  const endedAtMillis = integer(value.endedAtMillis, 'endedAtMillis', 1, maximumTime);
  const repetitions = integer(value.repetitions, 'repetitions', 0, 10000);
  const trackedDurationMillis = integer(value.trackedDurationMillis, 'trackedDurationMillis', 0, maximumDuration);
  const rejectedDurationMillis = integer(value.rejectedDurationMillis, 'rejectedDurationMillis', 0, maximumDuration);
  const score = value.formScorePercent;
  if (endedAtMillis <= startedAtMillis || endedAtMillis - startedAtMillis > maximumDuration ||
      trackedDurationMillis + rejectedDurationMillis > endedAtMillis - startedAtMillis ||
      (score !== null && (typeof score !== 'number' || !Number.isFinite(score) || score < 0 || score > 100)) ||
      (trackedDurationMillis === 0 && (score !== null || repetitions !== 0))) {
    throw new InputValidationError('Invalid workout chronology or metrics.');
  }
  // Fixed construction order makes fingerprints independent of JSON key order.
  return {
    schemaVersion: 2, requestId: requiredIdentifier(value.requestId, 'requestId'),
    organizationId: requiredIdentifier(value.organizationId, 'organizationId'),
    memberId: requiredIdentifier(value.memberId, 'memberId'), sessionId: requiredIdentifier(value.sessionId, 'sessionId'),
    exerciseId: requiredIdentifier(value.exerciseId, 'exerciseId'), startedAtMillis, endedAtMillis, repetitions,
    formScorePercent: score as number | null, trackedDurationMillis, rejectedDurationMillis,
    scoringVersion: requiredIdentifier(value.scoringVersion, 'scoringVersion'),
    detectorVersion: requiredIdentifier(value.detectorVersion, 'detectorVersion'),
    consentVersion: WORKOUT_CONSENT_VERSION, publishedRoutineId: requiredIdentifier(value.publishedRoutineId, 'publishedRoutineId'),
    detectorId: requiredIdentifier(value.detectorId, 'detectorId'),
    consentAcknowledgementId: requiredIdentifier(value.consentAcknowledgementId, 'consentAcknowledgementId'),
    provenance: 'real_camera', cameraView: 'side',
  };
}
