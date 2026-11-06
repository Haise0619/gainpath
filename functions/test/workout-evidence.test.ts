import {expect, it} from 'vitest';
import {extractWorkoutEvidence} from '../src/modules/recommendation/workout-evidence';
import {evaluateRecommendationConsent} from '../src/modules/recommendation/recommendation-consent';
import {consent, curl, metrics, modelVersion, now, routine, row, scope, session} from './exercise-insights-fixture';

it('extracts a typed, provisional measured summary and its actual coverage', () => {
  expect(extractWorkoutEvidence(scope, row(), now)).toMatchObject({kind: 'session',
    endedAtMillis: Date.UTC(2026, 9, 30, 16), localDate: '2026-10-31',
    formScorePercent: 80, assessedAttempts: 10, trackingCoverage: 0.8,
    trackedMicros: 8000000, rejectedMicros: 2000000,
    compatibility: {exerciseId: 'F3b8xIr8ynBDd3gEICKX', metricSchemaVersion: 1,
      scoringVersion: 'bodyweight-squat-side-v1', detectorId: 'blazepose-tflite',
      detectorVersion: modelVersion, cameraView: 'side', mode: 'not_applicable', scoreSupport: 'scored'}});
});
it('preserves null form and unknown coverage instead of legacy accuracy zero', () => {
  const p = session('null', null); p.repetitions = 0;
  Object.assign(metrics(p), {partialRepetitions: 0, trackedDurationMicros: 0, rejectedDurationMicros: 0});
  expect(extractWorkoutEvidence(scope, row(p), now)).toMatchObject({formScorePercent: null,
    trackingCoverage: null, assessedAttempts: 0});
});
it('fails safely when a score field is missing rather than manufacturing a zero', () => {
  const p = session(); delete metrics(p).formScorePercent;
  expect(() => extractWorkoutEvidence(scope, row(p), now)).toThrow('Exercise insight sources require review.');
});
it.each([
  ['single-arm-dumbbell-row-side-v1', 'single-arm-row-side-v1', 3, 'side', 'rowSide'],
  ['bodyweight-reverse-lunge-side-v1', 'reverse-lunge-side-v1', 5, 'side', 'lungeSide'],
  ['dumbbell-shoulder-press-front-v1', 'dumbbell-shoulder-press-front-v1', 4, 'front', null],
  ['standing-lateral-raise-front-v1', 'standing-lateral-raise-front-v1', 6, 'front', null],
] as const)('retains %s as deliberately unscored', (exerciseId, scoringVersion, schemaVersion, cameraView, side) => {
  const p = session('unscored', null); p.exerciseId = exerciseId;
  Object.assign(metrics(p), {scoringVersion, schemaVersion, cameraView, ...(side ? {[side]: 'left'} : {})});
  expect(extractWorkoutEvidence(scope, row(p), now)).toMatchObject({formScorePercent: null,
    compatibility: {exerciseId, scoringVersion, scoreSupport: 'unscored', mode: side ? 'left' : 'both'}});
});
it.each(['both', 'leftOnly', 'rightOnly'] as const)('preserves curl %s compatibility', mode => {
  expect(extractWorkoutEvidence(scope, row(curl('curl', mode)), now)).toMatchObject({compatibility: {mode}});
});
it.each([
  ['exerciseId', 'private-arbitrary-exercise', 'unsupported_exercise'],
  ['scoringVersion', 'bodyweight-squat-side-v2', 'unsupported_scoring_version'],
  ['cameraView', 'front', 'incompatible_camera_view'],
  ['detectorVersion', 'private-arbitrary-version', 'unsupported_detector'],
] as const)('classifies incompatible %s without exposing the untrusted value', (key, value, reason) => {
  const p = session(); (key === 'exerciseId' ? p : metrics(p))[key] = value;
  const extracted = extractWorkoutEvidence(scope, row(p), now);
  expect(extracted).toMatchObject({compatibility: null, unsupportedReason: reason});
  expect(JSON.stringify(extracted)).not.toContain(value);
});
it('keeps schema-one legacy curls with unknown arm mode unsupported', () => {
  const p = session(); p.exerciseId = 'standing-single-arm-curl-side-v1';
  metrics(p).scoringVersion = 'single-arm-curl-side-v1';
  expect(extractWorkoutEvidence(scope, row(p), now)).toMatchObject({compatibility: null,
    unsupportedReason: 'unknown_exercise_mode'});
});
it('does not project coercible non-string curl modes as typed compatibility', () => {
  const p = curl('curl', 'leftOnly');
  ((metrics(p).curlArms as Record<string, unknown>)).mode = ['leftOnly'];
  expect(extractWorkoutEvidence(scope, row(p), now)).toMatchObject({compatibility: null,
    unsupportedReason: 'unknown_exercise_mode'});
});
it('rejects scored summaries with no tracked time, even when a partial count survives legacy validation', () => {
  const p = session(); p.repetitions = 0;
  Object.assign(metrics(p), {trackedDurationMicros: 0, rejectedDurationMicros: 2000000});
  expect(() => extractWorkoutEvidence(scope, row(p), now)).toThrow('Exercise insight sources require review.');
});
it('rejects rolled calendar dates even when the legacy parser accepts the consistent interval', () => {
  const p = session(); p.startedAt = '2026-02-30T15:59:50.000Z'; p.endedAt = '2026-02-30T16:00:00.000Z';
  metrics(p).consentedAt = p.startedAt;
  expect(() => extractWorkoutEvidence(scope, row(p), now)).toThrow('Exercise insight sources require review.');
});
it('validates routine backups without interpreting checkpoints or manual sets as form samples', () => {
  expect(extractWorkoutEvidence(scope, routine(), now)).toMatchObject({kind: 'routine'});
  expect(extractWorkoutEvidence(scope, routine(), now)).not.toHaveProperty('formScorePercent');
});
it.each(['2026-02-30T16:00:00.000Z', 'not-a-date', '2026-10-30'])('rejects invalid/noncanonical date %s', endedAt => {
  const p = session(); p.endedAt = endedAt;
  expect(() => extractWorkoutEvidence(scope, row(p), now)).toThrow('Exercise insight sources require review.');
});
it('accepts microsecond UTC serialization without rounding into a different day', () => {
  const p = session(); p.endedAt = '2026-10-30T16:00:00.000123Z';
  expect(extractWorkoutEvidence(scope, row(p), now)).toMatchObject({localDate: '2026-10-31'});
});
it('uses the existing digest and ownership validator and sanitizes errors', () => {
  const altered = row(); altered.data.digest = 'a'.repeat(64);
  expect(() => extractWorkoutEvidence(scope, altered, now)).toThrow('Exercise insight sources require review.');
  expect(() => extractWorkoutEvidence({...scope, memberId: 'foreign'}, row(), now)).toThrow('Exercise insight sources require review.');
});
it.each(['session', 'routine'] as const)('rejects coercible nonliteral %s envelope kinds', kind => {
  const r = kind === 'session' ? row() : routine();
  (r.data as Record<string, unknown>).kind = [kind];
  expect(() => extractWorkoutEvidence(scope, r, now)).toThrow('Exercise insight sources require review.');
});
it.each([undefined, null, {}, {consented: true}, {consentVersion: 'pose-local-summary-v1'}])(
  'defaults missing/legacy consent off (%j)', raw => {
    expect(evaluateRecommendationConsent(raw, scope, now)).toMatchObject({allowed: false});
  });
it('grants only the separately versioned insights purpose', () => {
  expect(evaluateRecommendationConsent(consent(), scope, now)).toMatchObject({allowed: true, revision: 1});
  const c = consent(); (c.purposes as Record<string, unknown>).exerciseInsights = false;
  expect(evaluateRecommendationConsent(c, scope, now)).toMatchObject({allowed: false});
});
it.each([
  {revokedAtMillis: now - 1}, {grantedAtMillis: now + 1}, {memberId: 'foreign'},
  {organizationId: 'foreign'}, {schemaVersion: 2}, {policyVersion: 'camera-consent'},
  {revision: 0}, {updatedAtMillis: now + 1}, {purposes: {exerciseInsights: true}},
])('fails closed on invalid/revoked/future consent %j', patch => {
  expect(evaluateRecommendationConsent({...consent(), ...patch}, scope, now)).toMatchObject({allowed: false});
});
