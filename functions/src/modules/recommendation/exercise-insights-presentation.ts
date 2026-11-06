import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {digestOf, object} from '../workouts/workout-backup-validation';
import {exerciseTutorialProjection} from '../content/exercise-tutorial';
import {tutorialMediaUrl} from '../content/tutorial-media';
import type {EvidenceRow, ExerciseInsights, ExerciseCompatibility, ExerciseInsightGroup} from './exercise-insights-contracts';
import type {RecommendationConfiguration} from './recommendation-configuration';

export interface ReviewedCohortDisclosure {readonly policyId: string; readonly reviewVersion: string; readonly minimumMembers: number}
export interface ContentCoverageRow {
  exerciseId: string; name: string; category: string; publishedTutorials: number;
  coverage: 'covered' | 'missing_published_tutorial'; attentionGap: boolean | null;
}
export interface PresentedExerciseGroup {
  name: string; category: string; compatibility: ExerciseCompatibility;
  metrics: Pick<ExerciseInsightGroup, 'sessions' | 'members' | 'scoredSessions' | 'missingScoreSessions' | 'unscoredSessions'
    | 'assessedAttempts' | 'distinctSessionDays' | 'meanEstimatedFormScore' | 'trackingCoverage' | 'evidenceState'>;
  attention: 'attention' | 'within_policy' | 'not_assessed';
}
export interface ExerciseInsightsPresentation {
  schemaVersion: 1; organizationId: string; startAtMillis: number; endAtMillis: number; capturedAtMillis: number;
  mode: 'descriptive_only' | 'approved_group_attention'; recommendationEligibility: 'not_evaluated';
  privacy: {state: 'review_required' | 'applied'; policyId: string | null}; configurationRevision: number;
  groups: PresentedExerciseGroup[]; content: ContentCoverageRow[];
}
const failed = () => new DomainError('failed-precondition', 'Published exercise coverage requires review.');
const text = (v: unknown, max = 200): v is string => typeof v === 'string' && !!v.trim() && v.length <= max && !/[\x00-\x1f\x7f]/.test(v);
const integer = (v: unknown, min = 0, max = Number.MAX_SAFE_INTEGER): v is number => Number.isSafeInteger(v) && Number(v) >= min && Number(v) <= max;

/** Catalog-only projection: no membership/history dependency. Uses actual published routine fields and existing tutorial validators. */
function contentCoverage(catalog: readonly EvidenceRow[], publications: readonly EvidenceRow[]): ContentCoverageRow[] {
  if (catalog.length > 1000 || publications.length > 500 ||
    Buffer.byteLength(JSON.stringify([catalog, publications]), 'utf8') > 16 * 1024 * 1024) throw failed();
  const rows = new Map<string, ContentCoverageRow>(), ids = new Set<string>();
  for (const row of catalog) {
    requiredIdentifier(row.id, 'exercise');
    if (ids.has(row.id)) throw failed(); ids.add(row.id);
    const d = object(row.data);
    if (typeof d.isActive !== 'boolean' || (d.archived !== undefined && typeof d.archived !== 'boolean')) throw failed();
    if (!d.isActive || d.archived === true) continue;
    if (!text(d.exerciseName) || !text(d.muscleCategory, 100)) throw failed();
    rows.set(row.id, {exerciseId: row.id, name: d.exerciseName.trim(), category: d.muscleCategory.trim(),
      publishedTutorials: 0, coverage: 'missing_published_tutorial', attentionGap: null});
  }
  const publishedIds = new Set<string>();
  for (const row of publications) {
    requiredIdentifier(row.id, 'publication');
    if (publishedIds.has(row.id)) throw failed(); publishedIds.add(row.id);
    const d = object(row.data);
    if (d.status !== 'published' || d.kind !== 'routine' || d.archived === true || d.isActive === false) continue;
    if (d.schemaVersion !== 1 || !text(d.sourceBlueprintId, 128) || !text(d.title) ||
      !integer(d.estimatedMinutes, 1, 240) || !Array.isArray(d.exercises) || d.exercises.length < 1 || d.exercises.length > 50) throw failed();
    const seen = new Set<string>();
    for (const raw of d.exercises) {
      const e = object(raw), id = requiredIdentifier(e.exerciseId, 'exercise');
      if (!text(e.name) || !integer(e.sets, 1, 50) || !integer(e.reps, 1, 100) || !integer(e.dayNumber ?? 1, 1, 50)) throw failed();
      const projection = exerciseTutorialProjection(e);
      const instructions = Array.isArray(projection.tutorialSteps) && projection.tutorialSteps.length > 0;
      if (!tutorialMediaUrl(e.videoUrl) && !instructions) continue;
      const target = rows.get(id);
      if (target && !seen.has(id)) {target.publishedTutorials++; target.coverage = 'covered'; seen.add(id);}
    }
  }
  return [...rows.values()].sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : a.exerciseId.localeCompare(b.exerciseId));
}

/** Server-only disclosure boundary. Omitted reviewed policy withholds ALL observed groups; it does not pick a default cohort size. */
export function projectExerciseInsights(raw: ExerciseInsights, catalog: readonly EvidenceRow[], content: readonly EvidenceRow[], config: RecommendationConfiguration,
  disclosure?: ReviewedCohortDisclosure): ExerciseInsightsPresentation {
  try {
    if (config.schemaVersion !== 1 || config.organizationId !== raw.organizationId || !integer(config.revision)) throw failed();
    if (disclosure && (!text(disclosure.policyId, 128) || !text(disclosure.reviewVersion, 128) || !integer(disclosure.minimumMembers, 2, 200))) throw failed();
    const coverage = contentCoverage(catalog, content), byId = new Map(coverage.map(r => [r.exerciseId, r]));
    const groups: PresentedExerciseGroup[] = [];
    for (const g of disclosure ? raw.groups : []) {
      if (g.members < disclosure!.minimumMembers) continue;
      const metadata = byId.get(g.compatibility.exerciseId);
      if (!metadata) continue;
      const approved = config.policies.find(p => digestOf(p.compatibility) === digestOf(g.compatibility));
      let attention: PresentedExerciseGroup['attention'] = 'not_assessed';
      if (approved?.attentionThreshold && approved.provisionalSamplePolicy && raw.samplePolicy &&
        digestOf(approved.provisionalSamplePolicy) === digestOf(raw.samplePolicy) && g.evidenceState === 'meets_provisional_minimums' &&
        g.membersMeetingProvisionalMinimums === g.members &&
        (approved.cohortEligibility === null || g.membersMeetingProvisionalMinimums >= approved.cohortEligibility.minimumMembersMeetingProvisionalMinimums) &&
        g.compatibility.scoreSupport === 'scored' && g.meanEstimatedFormScore !== null) {
        attention = g.meanEstimatedFormScore < approved.attentionThreshold.estimatedFormScorePercent ? 'attention' : 'within_policy';
      }
      groups.push({name: metadata.name, category: metadata.category, compatibility: {...g.compatibility},
        metrics: {sessions: g.sessions, members: g.members, scoredSessions: g.scoredSessions,
          missingScoreSessions: g.missingScoreSessions, unscoredSessions: g.unscoredSessions,
          assessedAttempts: g.assessedAttempts, distinctSessionDays: g.distinctSessionDays,
          meanEstimatedFormScore: g.meanEstimatedFormScore, trackingCoverage: g.trackingCoverage, evidenceState: g.evidenceState}, attention});
    }
    for (const c of coverage) {
      const observed = groups.filter(g => g.compatibility.exerciseId === c.exerciseId && g.attention !== 'not_assessed');
      c.attentionGap = observed.length ? observed.some(g => g.attention === 'attention') && c.coverage !== 'covered' : null;
    }
    return {schemaVersion: 1, organizationId: raw.organizationId, startAtMillis: raw.startAtMillis, endAtMillis: raw.endAtMillis,
      capturedAtMillis: raw.source.capturedAtMillis, mode: groups.some(g => g.attention !== 'not_assessed') ? 'approved_group_attention' : 'descriptive_only',
      recommendationEligibility: 'not_evaluated', privacy: {state: disclosure ? 'applied' : 'review_required', policyId: disclosure?.policyId ?? null},
      configurationRevision: config.revision, groups, content: coverage};
  } catch {throw failed();}
}
