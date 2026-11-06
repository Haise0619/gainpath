import type {EvidenceRow} from './exercise-insights-contracts';
import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {digestOf, object} from '../workouts/workout-backup-validation';
import {exerciseTutorialProjection} from '../content/exercise-tutorial';
import {tutorialMediaUrl} from '../content/tutorial-media';

export type ContentObjective = 'technique_foundations' | 'movement_control' | 'progression' | 'endurance';
export type ContentLevel = 'beginner' | 'intermediate' | 'advanced';
export interface ContentCandidateQuery {
  readonly organizationId: string; readonly exerciseId: string;
  readonly objective: ContentObjective; readonly level: ContentLevel;
}
/** Trusted composition input, never a browser request. No production reader is registered. */
export interface ContentCandidateSource {
  readonly schemaVersion: 1; readonly organizationId: string; readonly sourceVersion: string;
  readonly memberAccess: 'organization_published_routines'; readonly curationVersion: string;
  readonly catalog: readonly EvidenceRow[]; readonly publications: readonly EvidenceRow[];
  readonly suitability: readonly CuratedContentSuitability[];
  readonly compatibleExercises: readonly CuratedCompatibleExercise[];
}
/** Explicit reviewed fixture metadata: catalog categories/description do not imply pedagogical suitability. */
export interface CuratedContentSuitability {
  readonly id: string; readonly publicationId: string; readonly exerciseIndex: number;
  readonly publicationDigest: string; readonly objectives: readonly ContentObjective[]; readonly levels: readonly ContentLevel[];
}
export interface CuratedCompatibleExercise {
  readonly id: string; readonly fromExerciseId: string; readonly toExerciseId: string;
}
/** Resolve current published Routine by ID, verify index/ID/day, then pass its exercise to ExerciseTutorialRoute.
 * This is an existing screen destination contract, not a registered deep link or new Mobile integration. */
export interface MemberContentDestination {
  readonly kind: 'published_routine_exercise_tutorial'; readonly organizationId: string;
  readonly routineId: string; readonly exerciseIndex: number; readonly exerciseId: string; readonly dayNumber: number;
}
export interface EligibleContentCandidate {
  readonly candidateId: string; readonly organizationId: string; readonly exerciseId: string; readonly title: string;
  readonly eligibilityClass: 'exact_exercise' | 'curated_compatible';
  readonly objective: ContentObjective; readonly level: ContentLevel; readonly destination: MemberContentDestination;
  readonly evidence: {readonly sourceVersion: string; readonly curationVersion: string; readonly suitabilityId: string;
    readonly publicationDigest: string; readonly compatibilityMappingId: string | null;
    readonly instruction: 'steps' | 'video' | 'steps_and_video'; readonly difficulty: ContentLevel | null;
    readonly equipment: string | null; readonly exerciseDurationMinutes: null; readonly routineEstimatedMinutes: number};
}
export type ContentRejectionReason = 'catalog_unavailable' | 'publication_unavailable' | 'invalid_publication'
  | 'instruction_missing' | 'invalid_instruction' | 'exercise_not_compatible' | 'suitability_unknown'
  | 'suitability_stale' | 'objective_not_supported' | 'level_not_supported';
export interface ContentCandidateRejection {
  readonly publicationId: string | null; readonly exerciseIndex: number | null; readonly reason: ContentRejectionReason;
}
export interface ContentCandidateResult {
  readonly schemaVersion: 1; readonly organizationId: string; readonly status: 'available' | 'no_candidate';
  readonly contentGap: 'none' | 'no_eligible_published_instruction';
  readonly candidates: readonly EligibleContentCandidate[]; readonly rejected: readonly ContentCandidateRejection[];
}

const objectives: readonly string[] = ['technique_foundations', 'movement_control', 'progression', 'endurance'];
const levels: readonly string[] = ['beginner', 'intermediate', 'advanced'];
const failed = () => new DomainError('failed-precondition', 'Content candidate source is unavailable.');
const text = (v: unknown, max = 200): v is string => typeof v === 'string' && !!v.trim() && v.length <= max && !/[\x00-\x1f\x7f]/.test(v);
const integer = (v: unknown, min: number, max: number): v is number => Number.isSafeInteger(v) && Number(v) >= min && Number(v) <= max;
const order = (a: string, b: string) => a < b ? -1 : a > b ? 1 : 0;
const positionKey = (id: string, index: number) => `${id}:${index}`;

function parseQuery(query: ContentCandidateQuery): void {
  try {
    const q = object(query);
    if (Object.keys(q).some(k => !['organizationId', 'exerciseId', 'objective', 'level'].includes(k)) ||
      !objectives.includes(q.objective as string) || !levels.includes(q.level as string)) throw failed();
    requiredIdentifier(q.organizationId, 'organization'); requiredIdentifier(q.exerciseId, 'exercise');
  } catch {throw new DomainError('invalid-argument', 'Choose a supported exercise, educational objective and level.');}
}

function sourceRows(rows: readonly EvidenceRow[], organizationId: string): Map<string, Record<string, unknown>> {
  const result = new Map<string, Record<string, unknown>>();
  for (const row of rows) {
    requiredIdentifier(row.id, 'source');
    if (result.has(row.id)) throw failed();
    const data = object(row.data);
    // A missing embedded organization is normal for org-scoped existing documents.
    if (data.organizationId !== undefined && data.organizationId !== organizationId) throw failed();
    result.set(row.id, data);
  }
  return result;
}

function activeCatalog(data: Record<string, unknown> | undefined): boolean {
  return !!data && data.isActive === true && data.archived !== true;
}

function validPublication(data: Record<string, unknown>): boolean {
  if (data.schemaVersion !== 1 || !text(data.sourceBlueprintId, 128) || !text(data.title) ||
    !integer(data.estimatedMinutes, 1, 240) || !Array.isArray(data.exercises) || data.exercises.length < 1 || data.exercises.length > 50 ||
    (data.difficulty !== undefined && !['Beginner', 'Intermediate', 'Advanced'].includes(data.difficulty as string))) return false;
  try {requiredIdentifier(data.sourceBlueprintId, 'blueprint');} catch {return false;}
  return data.exercises.every(raw => {
    try {
      const e = object(raw); requiredIdentifier(e.exerciseId, 'exercise');
      return text(e.name) && integer(e.sets, 1, 50) && integer(e.reps, 1, 100) &&
        integer(e.dayNumber ?? 1, 1, 50) && integer(e.restSeconds ?? 60, 0, 600);
    } catch {return false;}
  });
}

/** Bounded, read-only local eligibility. Trusted source composition supplies organization-scoped
 * catalog/publications and explicit pedagogical curation. No Member history, networking or writes.
 * Publication syntax indicates the existing Member access path; media reachability is not asserted.
 * Consumers must preserve eligibilityClass ahead of all soft ranking factors and re-resolve the
 * destination against current authorized published content before opening/delivering anything. */
export function evaluateContentCandidates(query: ContentCandidateQuery, source: ContentCandidateSource): ContentCandidateResult {
  parseQuery(query);
  try {
    if (source.schemaVersion !== 1 || source.organizationId !== query.organizationId ||
      source.memberAccess !== 'organization_published_routines' || !text(source.sourceVersion, 128) || !text(source.curationVersion, 128) ||
      !Array.isArray(source.catalog) || source.catalog.length > 1000 || !Array.isArray(source.publications) || source.publications.length > 500 ||
      !Array.isArray(source.suitability) || source.suitability.length > 2000 ||
      !Array.isArray(source.compatibleExercises) || source.compatibleExercises.length > 2000 ||
      Buffer.byteLength(JSON.stringify(source), 'utf8') > 16 * 1024 * 1024) throw failed();
    const catalog = sourceRows(source.catalog, query.organizationId), publications = sourceRows(source.publications, query.organizationId);
    for (const data of catalog.values()) {
      if (typeof data.isActive !== 'boolean' || (data.archived !== undefined && typeof data.archived !== 'boolean') ||
        !text(data.exerciseName) || !text(data.muscleCategory, 100)) throw failed();
    }
    const suitability = new Map<string, CuratedContentSuitability>(), curationIds = new Set<string>();
    for (const row of source.suitability) {
      requiredIdentifier(row.id, 'curation'); requiredIdentifier(row.publicationId, 'publication');
      if (!integer(row.exerciseIndex, 0, 49) || !/^[a-f0-9]{64}$/.test(row.publicationDigest) ||
        !Array.isArray(row.objectives) || !row.objectives.length || row.objectives.length > objectives.length ||
        row.objectives.some((v: unknown) => typeof v !== 'string' || !objectives.includes(v)) || new Set(row.objectives).size !== row.objectives.length ||
        !Array.isArray(row.levels) || !row.levels.length || row.levels.length > levels.length ||
        row.levels.some((v: unknown) => typeof v !== 'string' || !levels.includes(v)) || new Set(row.levels).size !== row.levels.length || curationIds.has(row.id) ||
        suitability.has(positionKey(row.publicationId, row.exerciseIndex))) throw failed();
      curationIds.add(row.id); suitability.set(positionKey(row.publicationId, row.exerciseIndex), row);
    }
    const compatible = new Map<string, CuratedCompatibleExercise>(), mappingIds = new Set<string>();
    for (const row of source.compatibleExercises) {
      requiredIdentifier(row.id, 'mapping'); requiredIdentifier(row.fromExerciseId, 'exercise'); requiredIdentifier(row.toExerciseId, 'exercise');
      const key = `${row.fromExerciseId}:${row.toExerciseId}`;
      if (row.fromExerciseId === row.toExerciseId || mappingIds.has(row.id) || compatible.has(key)) throw failed();
      mappingIds.add(row.id); compatible.set(key, row);
    }
    const candidates: EligibleContentCandidate[] = [], rejected: ContentCandidateRejection[] = [];
    const reject = (publicationId: string | null, exerciseIndex: number | null, reason: ContentRejectionReason) => {
      rejected.push({publicationId, exerciseIndex, reason});
    };
    if (!activeCatalog(catalog.get(query.exerciseId))) reject(null, null, 'catalog_unavailable');
    else for (const [routineId, data] of publications) {
      if (data.status !== 'published' || data.kind !== 'routine' || data.archived === true || data.isActive === false) {
        reject(routineId, null, 'publication_unavailable'); continue;
      }
      if (!validPublication(data)) {reject(routineId, null, 'invalid_publication'); continue;}
      const publicationDigest = digestOf(data);
      for (const [exerciseIndex, raw] of (data.exercises as Record<string, unknown>[]).entries()) {
        const exerciseId = raw.exerciseId as string;
        if (!activeCatalog(catalog.get(exerciseId))) {reject(routineId, exerciseIndex, 'catalog_unavailable'); continue;}
        const exact = exerciseId === query.exerciseId, mapping = compatible.get(`${query.exerciseId}:${exerciseId}`);
        if (!exact && !mapping) {reject(routineId, exerciseIndex, 'exercise_not_compatible'); continue;}
        let projected: Record<string, unknown>;
        try {projected = exerciseTutorialProjection(raw);} catch {reject(routineId, exerciseIndex, 'invalid_instruction'); continue;}
        const steps = Array.isArray(projected.tutorialSteps) && projected.tutorialSteps.length > 0, video = !!tutorialMediaUrl(raw.videoUrl);
        if (!steps && !video) {reject(routineId, exerciseIndex, 'instruction_missing'); continue;}
        const curated = suitability.get(positionKey(routineId, exerciseIndex));
        if (!curated) {reject(routineId, exerciseIndex, 'suitability_unknown'); continue;}
        if (curated.publicationDigest !== publicationDigest) {reject(routineId, exerciseIndex, 'suitability_stale'); continue;}
        if (!curated.objectives.includes(query.objective)) {reject(routineId, exerciseIndex, 'objective_not_supported'); continue;}
        if (!curated.levels.includes(query.level)) {reject(routineId, exerciseIndex, 'level_not_supported'); continue;}
        const destination: MemberContentDestination = {kind: 'published_routine_exercise_tutorial', organizationId: query.organizationId,
          routineId, exerciseIndex, exerciseId, dayNumber: (raw.dayNumber ?? 1) as number};
        candidates.push({candidateId: `content_${digestOf(destination).slice(0, 32)}`, organizationId: query.organizationId,
          exerciseId, title: (raw.name as string).trim(), eligibilityClass: exact ? 'exact_exercise' : 'curated_compatible',
          objective: query.objective, level: query.level, destination,
          evidence: {sourceVersion: source.sourceVersion, curationVersion: source.curationVersion, suitabilityId: curated.id,
            publicationDigest, compatibilityMappingId: exact ? null : mapping!.id,
            instruction: steps && video ? 'steps_and_video' : steps ? 'steps' : 'video',
            difficulty: projected.difficulty ? String(projected.difficulty).toLowerCase() as ContentLevel : null,
            equipment: projected.equipment as string ?? null, exerciseDurationMinutes: null, routineEstimatedMinutes: data.estimatedMinutes as number}});
      }
    }
    candidates.sort((a, b) => Number(a.eligibilityClass !== 'exact_exercise') - Number(b.eligibilityClass !== 'exact_exercise') || order(a.candidateId, b.candidateId));
    rejected.sort((a, b) => order(a.publicationId ?? '', b.publicationId ?? '') || (a.exerciseIndex ?? -1) - (b.exerciseIndex ?? -1) || order(a.reason, b.reason));
    return {schemaVersion: 1, organizationId: query.organizationId, status: candidates.length ? 'available' : 'no_candidate',
      contentGap: candidates.length ? 'none' : 'no_eligible_published_instruction', candidates, rejected};
  } catch {throw failed();}
}
