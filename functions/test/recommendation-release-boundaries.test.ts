import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {describe, expect, it} from 'vitest';
import {projectExerciseInsights} from '../src/modules/recommendation/exercise-insights-presentation';
import {defaultRecommendationConfiguration} from '../src/modules/recommendation/recommendation-configuration';
import type {ExerciseInsights} from '../src/modules/recommendation/exercise-insights-contracts';
import {now, query} from './exercise-insights-fixture';

// Fixture catalog only; deliberately no observed Member groups or network adapter.
const emptyInsights: ExerciseInsights = {...query, schemaVersion: 1, concept: 'Exercises Needing Attention',
  mode: 'descriptive_only', status: 'no_supported_evidence',
  source: {classification: 'provisional_member_backup', validation: 'existing_workout_backup_validator',
    scanStartedAtMillis: now, capturedAtMillis: now, timezone: 'Asia/Kuala_Lumpur',
    scoreAggregation: 'equal_member_mean_of_session_means', snapshot: 'bounded_non_atomic_scan', recordsScanned: 0, bytesScanned: 0},
  coverage: {membersScanned: 0, activeMembers: 0, consentedMembers: 0, membersWithoutConsent: 0,
    membersWithBackups: 0, membersWithSupportedEvidence: 0},
  exclusions: {duplicateRecords: 0, routineRecords: 0, futureSessions: 0, outOfWindowSessions: 0,
    unsupportedSessions: 0, unsupportedReasons: {}}, samplePolicy: null, attentionThreshold: null, groups: []};
const catalog = [{id: 'synthetic-squat', data: {exerciseName: 'Synthetic squat', muscleCategory: 'Lower Body', isActive: true}}];
const config = defaultRecommendationConfiguration(query.organizationId);
function publication(extra: Record<string, unknown> = {}, dayNumber: number | undefined = 1) {
  return [{id: 'synthetic-routine', data: {schemaVersion: 1, kind: 'routine', status: 'published',
    sourceBlueprintId: 'synthetic-blueprint', title: 'Synthetic instructional routine', estimatedMinutes: 10, ...extra,
    exercises: [{exerciseId: 'synthetic-squat', name: 'Synthetic squat', sets: 3, reps: 8,
      ...(dayNumber === undefined ? {} : {dayNumber}),
      tutorialSteps: [{title: 'Movement', description: 'Follow the authored movement instructions.'}]}]}}];
}

describe('Module 13 release boundaries and truthful catalog coverage', () => {
  it('keeps all production activation controls off with no invented approved policy', () => {
    expect(config).toMatchObject({revision: 0, policies: [],
      activation: {generation: false, externalAi: false, matching: false, delivery: false}});
    const projected = projectExerciseInsights(emptyInsights, catalog, publication(), config);
    expect(projected).toMatchObject({mode: 'descriptive_only', recommendationEligibility: 'not_evaluated',
      privacy: {state: 'review_required', policyId: null}, groups: []});
  });

  it.each([{archived: true}, {isActive: false}])('does not report withdrawn publication %j as tutorial coverage', flags => {
    const projected = projectExerciseInsights(emptyInsights, catalog, publication(flags), config);
    expect(projected.content[0]).toMatchObject({publishedTutorials: 0, coverage: 'missing_published_tutorial', attentionGap: null});
  });

  it('accepts the existing tutorial day-one default consistently with current target eligibility', () => {
    const rows = publication();
    delete (rows[0].data.exercises[0] as {dayNumber?: number}).dayNumber;
    const projected = projectExerciseInsights(emptyInsights, catalog, rows, config);
    expect(projected.content[0]).toMatchObject({publishedTutorials: 1, coverage: 'covered'});
  });

  it('rejects an explicit invalid day instead of using the legacy default', () => {
    expect(() => projectExerciseInsights(emptyInsights, catalog, publication({}, 0), config)).toThrow();
  });

  it('does not register local recommendation services in the deployable Functions entry point', () => {
    const entry = readFileSync(resolve(process.cwd(), 'src/index.ts'), 'utf8');
    expect(entry).not.toMatch(/(?:from\s*|import\s*\()\s*['"][^'"]*modules\/recommendation\//);
    expect(entry).not.toMatch(/export\s+(?:const|function)\s+(?:recommendation|exerciseInsights)/i);
  });
});
