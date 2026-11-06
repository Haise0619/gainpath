import {expect, it} from 'vitest';
import {projectExerciseInsights} from '../src/modules/recommendation/exercise-insights-presentation';
import {defaultRecommendationConfiguration} from '../src/modules/recommendation/recommendation-configuration';
import type {ExerciseInsights} from '../src/modules/recommendation/exercise-insights-contracts';
import {now, query, modelVersion} from './exercise-insights-fixture';

const compatibility = {exerciseId: 'F3b8xIr8ynBDd3gEICKX', metricSchemaVersion: 1, scoringVersion: 'bodyweight-squat-side-v1',
  detectorId: 'blazepose-tflite', detectorVersion: modelVersion, cameraView: 'side', mode: 'not_applicable', scoreSupport: 'scored'} as const;
function source(members = 3): ExerciseInsights {
  return {...query, schemaVersion: 1, concept: 'Exercises Needing Attention', mode: 'descriptive_only', status: 'available',
    source: {classification: 'provisional_member_backup', validation: 'existing_workout_backup_validator', scanStartedAtMillis: now,
      capturedAtMillis: now, timezone: 'Asia/Kuala_Lumpur', scoreAggregation: 'equal_member_mean_of_session_means',
      snapshot: 'bounded_non_atomic_scan', recordsScanned: 6, bytesScanned: 6000},
    coverage: {membersScanned: 3, activeMembers: 3, consentedMembers: 3, membersWithoutConsent: 0,
      membersWithBackups: 3, membersWithSupportedEvidence: 3},
    exclusions: {duplicateRecords: 0, routineRecords: 0, futureSessions: 0, outOfWindowSessions: 0,
      unsupportedSessions: 0, unsupportedReasons: {}}, samplePolicy: null, attentionThreshold: null,
    groups: [{compatibility, sessions: 6, members, scoredSessions: 6, missingScoreSessions: 0, unscoredSessions: 0,
      assessedAttempts: 60, distinctSessionDays: 2, meanEstimatedFormScore: 65, trackedMicros: 48000000,
      rejectedMicros: 12000000, trackingCoverage: 0.8, membersMeetingProvisionalMinimums: null, evidenceState: 'policy_not_configured'}]};
}
const catalog = [
  {id: compatibility.exerciseId, data: {exerciseName: 'Squat', muscleCategory: 'Lower Body', isActive: true}},
  {id: 'wall-push-up-side-v1', data: {exerciseName: 'Wall push-up', muscleCategory: 'Upper Body', isActive: true}},
];
const published = [{id: 'routine_fixture', data: {schemaVersion: 1, kind: 'routine', status: 'published', sourceBlueprintId: 'fixture',
  title: 'Synthetic published routine', estimatedMinutes: 10, exercises: [{exerciseId: compatibility.exerciseId, name: 'Squat',
    category: 'Lower Body', muscleGroup: 'Lower Body', dayNumber: 1, sets: 3, reps: 8, videoUrl: 'https://example.invalid/squat.mp4'}]}}];
const configuration = defaultRecommendationConfiguration('gainpath');
const disclosure = {policyId: 'synthetic-cohort-three', reviewVersion: 'fixture-v1', minimumMembers: 3};

it('withholds all observed groups and source counts until a cohort policy is reviewed', () => {
  const result = projectExerciseInsights(source(), catalog, published, configuration);
  expect(result.privacy).toEqual({state: 'review_required', policyId: null});
  expect(result.groups).toEqual([]);
  expect(result.content).toHaveLength(2);
  expect(result).not.toHaveProperty('coverage');
  for (const key of ['exclusions', 'recordsScanned', 'bytesScanned', 'scoredSessions', 'meanEstimatedFormScore']) {
    expect(JSON.stringify(result)).not.toContain(`"${key}"`);
  }
});
it('applies a synthetic reviewed cohort boundary without publishing suppressed complements', () => {
  let result = projectExerciseInsights(source(2), catalog, published, configuration, disclosure);
  expect(result.groups).toEqual([]);
  expect(result).not.toHaveProperty('suppressedGroupCount');
  result = projectExerciseInsights(source(3), catalog, published, configuration, disclosure);
  expect(result.groups[0]).toMatchObject({name: 'Squat', category: 'Lower Body', metrics: {members: 3, meanEstimatedFormScore: 65}, attention: 'not_assessed'});
  expect(result.recommendationEligibility).toBe('not_evaluated');
});
it('cross-references actual published routine projections, not catalog video alone', () => {
  const result = projectExerciseInsights(source(), catalog, published, configuration, disclosure);
  expect(result.content).toEqual([
    {exerciseId: compatibility.exerciseId, name: 'Squat', category: 'Lower Body', publishedTutorials: 1, coverage: 'covered', attentionGap: null},
    {exerciseId: 'wall-push-up-side-v1', name: 'Wall push-up', category: 'Upper Body', publishedTutorials: 0, coverage: 'missing_published_tutorial', attentionGap: null},
  ]);
  expect(projectExerciseInsights(source(), catalog, [], configuration, disclosure).content[0].coverage).toBe('missing_published_tutorial');
});
it('does not count archived/inactive catalog or unpublished/empty/image-only content as instruction', () => {
  const draft = structuredClone(published); draft[0].data.status = 'draft';
  expect(projectExerciseInsights(source(), catalog, draft, configuration).content.every(c => c.publishedTutorials === 0)).toBe(true);
  const archived = structuredClone(catalog); archived[0].data.isActive = false;
  expect(projectExerciseInsights(source(), archived, published, configuration).content).toHaveLength(1);
  const image = structuredClone(published); image[0].data.exercises[0].videoUrl = 'https://example.invalid/cover.jpg';
  expect(projectExerciseInsights(source(), catalog, image, configuration).content[0].coverage).toBe('missing_published_tutorial');
});
it('requires a matching approved sample policy before applying an attention threshold', () => {
  const sample = {schemaVersion: 1 as const, revision: 'fixture-minimums', minimumScoredSessions: 2,
    minimumDistinctDays: 2, minimumAssessedAttempts: 15, minimumTrackingCoverage: 0.7};
  const config = {...configuration, revision: 1, policies: [{policyId: 'fixture-squat', reviewVersion: 'fixture-v1',
    compatibility, provisionalSamplePolicy: sample, attentionThreshold: {operator: 'score_below' as const, estimatedFormScorePercent: 68}, cohortEligibility: null}]};
  expect(projectExerciseInsights(source(), catalog, published, config, disclosure).groups[0].attention).toBe('not_assessed');
  const raw = source();
  const assessed: ExerciseInsights = {...raw, samplePolicy: sample, groups: [{...raw.groups[0],
    evidenceState: 'meets_provisional_minimums', membersMeetingProvisionalMinimums: 3}]};
  expect(projectExerciseInsights(assessed, catalog, [], config, disclosure).groups[0].attention).toBe('attention');
  expect(projectExerciseInsights(assessed, catalog, [], config, disclosure).content[0].attentionGap).toBe(true);
  const sparse = {...assessed, groups: [{...assessed.groups[0], membersMeetingProvisionalMinimums: 1}]};
  expect(projectExerciseInsights(sparse, catalog, [], config, disclosure).groups[0].attention).toBe('not_assessed');
  expect(projectExerciseInsights(assessed, catalog, [], config).groups).toEqual([]);
});
it('bounds catalog scans and rejects malformed publication contracts without partial output', () => {
  expect(() => projectExerciseInsights(source(), Array.from({length: 1001}, (_, i) => ({...catalog[0], id: `e${i}`})), [], configuration)).toThrow();
  const invalid = structuredClone(published); invalid[0].data.exercises[0].sets = 0;
  expect(() => projectExerciseInsights(source(), catalog, invalid, configuration)).toThrow('Published exercise coverage requires review.');
});
