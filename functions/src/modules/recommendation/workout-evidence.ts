import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {digestOf, object, validateBackupPayload} from '../workouts/workout-backup-validation';
import type {EvidenceScope, ExtractedWorkoutEvidence, ExerciseCompatibility, UnsupportedReason} from './exercise-insights-contracts';

export const insightSourceError = () => new DomainError('failed-precondition', 'Exercise insight sources require review.');
const MODEL = 'mediapipe-full-e9a5c5cb-det-9ba9dd3d';
type Capability = {rule: string; schema: number; view: 'side' | 'front'; score: 'scored' | 'unscored'; mode: 'none' | 'curl' | 'row' | 'lunge' | 'both'};
// Interpretation of the exact existing analyzer registry, not workout acceptance or a risk policy.
const CAPABILITIES: Readonly<Record<string, Capability>> = Object.freeze({
  F3b8xIr8ynBDd3gEICKX: {rule: 'bodyweight-squat-side-v1', schema: 1, view: 'side', score: 'scored', mode: 'none'},
  'standing-single-arm-curl-side-v1': {rule: 'single-arm-curl-side-v1', schema: 2, view: 'side', score: 'scored', mode: 'curl'},
  'standing-calf-raise-side-v1': {rule: 'standing-calf-raise-side-v1', schema: 1, view: 'side', score: 'scored', mode: 'none'},
  'wall-push-up-side-v1': {rule: 'wall-push-up-side-v1', schema: 1, view: 'side', score: 'scored', mode: 'none'},
  'single-arm-dumbbell-row-side-v1': {rule: 'single-arm-row-side-v1', schema: 3, view: 'side', score: 'unscored', mode: 'row'},
  'bodyweight-reverse-lunge-side-v1': {rule: 'reverse-lunge-side-v1', schema: 5, view: 'side', score: 'unscored', mode: 'lunge'},
  'dumbbell-shoulder-press-front-v1': {rule: 'dumbbell-shoulder-press-front-v1', schema: 4, view: 'front', score: 'unscored', mode: 'both'},
  'standing-lateral-raise-front-v1': {rule: 'standing-lateral-raise-front-v1', schema: 6, view: 'front', score: 'unscored', mode: 'both'},
});
function compatibility(org: string, id: string, m: Record<string, unknown>):
  {compatibility: ExerciseCompatibility | null; unsupportedReason: UnsupportedReason | null} {
  const unsupported = (unsupportedReason: UnsupportedReason) => ({compatibility: null, unsupportedReason});
  // Floor push-up v1 is descriptive only. Its source/threshold/policy evidence
  // requires a separate review; never alias it to Wall Push-Up compatibility.
  if (id === 'standard-floor-push-up-side-v1') return unsupported('unsupported_exercise');
  const c = Object.hasOwn(CAPABILITIES, id) ? CAPABILITIES[id] : undefined;
  if (org !== 'gainpath' || !c) return unsupported('unsupported_exercise');
  if (m.scoringVersion !== c.rule) return unsupported('unsupported_scoring_version');
  if (c.mode === 'curl' && m.schemaVersion === 1) return unsupported('unknown_exercise_mode');
  if (m.schemaVersion !== c.schema) return unsupported('unsupported_metric_schema');
  if (m.cameraView !== c.view) return unsupported('incompatible_camera_view');
  if (m.detectorId !== 'blazepose-tflite' || m.detectorVersion !== MODEL) return unsupported('unsupported_detector');
  const mode = c.mode === 'curl' ? object(m.curlArms).mode : c.mode === 'row' ? m.rowSide
    : c.mode === 'lunge' ? m.lungeSide : c.mode === 'both' ? 'both' : 'not_applicable';
  if (typeof mode !== 'string' || !['both', 'leftOnly', 'rightOnly', 'left', 'right', 'not_applicable'].includes(mode)) {
    return unsupported('unknown_exercise_mode');
  }
  return {compatibility: {exerciseId: id, metricSchemaVersion: c.schema, scoringVersion: c.rule,
    detectorId: 'blazepose-tflite', detectorVersion: MODEL, cameraView: c.view,
    mode: mode as ExerciseCompatibility['mode'], scoreSupport: c.score}, unsupportedReason: null};
}
function utcDate(value: unknown): number {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/.test(value)) throw insightSourceError();
  const at = Date.parse(value);
  if (!Number.isFinite(at) || at < 0 || new Date(at).toISOString().slice(0, 19) !== value.slice(0, 19)) throw insightSourceError();
  return at;
}

/** Shared measurement projection; callers must validate the complete source contract first. */
export function projectValidatedSessionEvidence(scope: EvidenceScope, p: Record<string, unknown>,
  identity: {recordKey: string; digest: string; updatedAtMillis: number}): ExtractedWorkoutEvidence {
  const end = utcDate(p.endedAt), start = utcDate(p.startedAt), m = object(p.poseMetrics);
  if (utcDate(m.consentedAt) > start) throw insightSourceError();
  const tracked = Number(m.trackedDurationMicros), rejected = Number(m.rejectedDurationMicros);
  if (m.formScorePercent !== null && tracked === 0) throw insightSourceError();
  return {...identity, kind: 'session', endedAtMillis: end,
    localDate: new Date(end + 8 * 3600000).toISOString().slice(0, 10),
    ...compatibility(scope.organizationId, String(p.exerciseId), m),
    formScorePercent: m.formScorePercent as number | null,
    assessedAttempts: Number(p.repetitions) + Number(m.partialRepetitions),
    trackedMicros: tracked, rejectedMicros: rejected,
    trackingCoverage: tracked + rejected === 0 ? null : tracked / (tracked + rejected)};
}

/** Internal typed projection after the existing full payload/digest/owner validation. No source mutation. */
export function extractWorkoutEvidence(scope: EvidenceScope, raw: unknown, now: number): ExtractedWorkoutEvidence {
  try {
    requiredIdentifier(scope.organizationId, 'organization'); requiredIdentifier(scope.memberId, 'member');
    const data = object(object(raw).data);
    if (!Number.isSafeInteger(now) || now < 0 || data.schemaVersion !== 1 ||
      data.classification !== 'provisional_member_backup' || (data.kind !== 'session' && data.kind !== 'routine') ||
      typeof data.payloadJson !== 'string' || !Number.isSafeInteger(data.updatedAtMillis) ||
      Number(data.updatedAtMillis) < 0 || Number(data.updatedAtMillis) > now ||
      typeof data.digest !== 'string' || !/^[a-f0-9]{64}$/.test(data.digest)) throw insightSourceError();
    const id = requiredIdentifier(data.id, 'backup'), kind = data.kind;
    if (data.key !== `${kind}-${id}`) throw insightSourceError();
    const p = validateBackupPayload(kind, id, scope.organizationId, scope.memberId, JSON.parse(data.payloadJson));
    if(kind==='routine' && p.schemaVersion===2) throw insightSourceError();
    if (digestOf(p) !== data.digest) throw insightSourceError();
    const identity = {recordKey: String(data.key), digest: data.digest, updatedAtMillis: Number(data.updatedAtMillis)};
    if (kind === 'routine') return {...identity, kind: 'routine'};
    return projectValidatedSessionEvidence(scope, p, identity);
  } catch {
    // Never include row IDs, Member IDs, JSON parse text, payloads or source errors.
    throw insightSourceError();
  }
}
