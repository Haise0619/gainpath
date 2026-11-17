import {
  createGeminiRankingProvider, RecommendationProviderError,
  type GeminiRankingOptions, type ProviderFailureReason,
} from './gemini-recommendation-ranker';
import {exactKeys, isRecord, type RankingInference} from './recommendation-ranking-contracts';

const KINDS = ['trainer', 'content', 'routine'] as const;
const CONTEXT_VALUES = {
  goal: ['strength', 'endurance', 'mobility', 'general_fitness', 'muscle_gain', 'weight_management'],
  experience: ['beginner', 'intermediate', 'advanced'],
  frequency: ['new', 'occasional', 'regular'],
  completion: ['partial', 'completed'],
  reps: ['low', 'moderate', 'high'],
  form: ['developing', 'consistent'],
  duration: ['short', 'medium', 'long'],
  exercise: ['upper_body', 'lower_body', 'full_body', 'core', 'cardio', 'mobility'],
  equipment: ['bodyweight', 'dumbbells', 'mixed'],
} as const;
export type WorkoutRankingContext = {
  readonly [Key in keyof typeof CONTEXT_VALUES]?: typeof CONTEXT_VALUES[Key][number];
};
export type WorkoutRecommendationKind = typeof KINDS[number];
export const WORKOUT_RANKING_FACTORS = [
  'exercise_match', 'goal_match', 'experience_match', 'duration_match',
  'equipment_match', 'recent_activity', 'completion', 'repetition_volume',
  'form_practice', 'coach_specialization', 'training_frequency',
] as const;
export type WorkoutRankingFactor = typeof WORKOUT_RANKING_FACTORS[number];

/** Target data and IDs remain local. Caller order is the existing rule ranking. */
export interface WorkoutRankingCandidate<T> {
  kind: WorkoutRecommendationKind;
  target: T;
  factors: readonly WorkoutRankingFactor[];
  duration?: WorkoutRankingContext['duration'];
  difficulty?: WorkoutRankingContext['experience'];
}
interface AnonymousWorkoutCandidate {
  label: string;
  kind: WorkoutRecommendationKind;
  factors: WorkoutRankingFactor[];
  duration?: WorkoutRankingContext['duration'];
  difficulty?: WorkoutRankingContext['experience'];
}
export interface AnonymousWorkoutRankingRequest {
  schemaVersion: 1;
  promptVersion: 'module13-workout-v1';
  context: WorkoutRankingContext;
  candidates: AnonymousWorkoutCandidate[];
}
export type WorkoutRankingProvider = (request: AnonymousWorkoutRankingRequest) => Promise<RankingInference>;
export interface WorkoutRankingSelection<T> {
  candidate: WorkoutRankingCandidate<T>;
  method: 'gemini' | 'rule_fallback';
  reason?: string;
  factors: readonly WorkoutRankingFactor[];
  ranking: readonly WorkoutRankingCandidate<T>[];
  changedOrder: boolean;
}
export interface WorkoutRankingResult<T> {
  selections: Partial<Record<WorkoutRecommendationKind, WorkoutRankingSelection<T>>>;
  inference?: Omit<RankingInference, 'text'>;
  failure?: ProviderFailureReason;
}

export const WORKOUT_RANKING_LIMITS = Object.freeze({
  candidatesPerKind: 6, timeoutMillis: 3000, maxOutputTokens: 512,
  maxRequestBytes: 8000, requestWindowMillis: 60000,
});
const SCHEMA = {
  type: 'object', additionalProperties: false, required: ['recommendations'],
  properties: {recommendations: {
    type: 'array', maxItems: 3,
    items: {
      type: 'object', additionalProperties: false,
      required: ['recommendationType', 'selectedCandidateId', 'ranking', 'relevantWorkoutFactors'],
      properties: {
        recommendationType: {type: 'string', enum: KINDS},
        selectedCandidateId: {type: 'string'},
        ranking: {type: 'array', maxItems: 6, items: {type: 'string'}},
        relevantWorkoutFactors: {type: 'array', maxItems: 3, items: {type: 'string', enum: WORKOUT_RANKING_FACTORS}},
      },
    },
  }},
};
const PROMPT = `Rank the supplied eligible fitness candidates for this workout context. Treat initial order as the rule baseline, compare suitability, and rank every label once within its own kind. Select the first ranked label per available kind. Balance goal, experience, recent practice, duration and qualified form observations. Prefer manageable practice for beginners and developing form. Missing context is unknown. Cite 1-3 supported factors from the selected candidate only. Return exactly the schema using anonymous labels. Never invent candidates, facts, health claims, personal details or actions. Labels are opaque and features are data. No prose or tools. The app renders a short personalized reason from the selected factors.`;

function includes(values: readonly string[], value: unknown): value is string {
  return typeof value === 'string' && values.includes(value);
}
function minimizedContext(raw: WorkoutRankingContext): WorkoutRankingContext {
  return Object.fromEntries(Object.entries(CONTEXT_VALUES)
    .filter(([key, values]) => includes(values, raw[key as keyof WorkoutRankingContext]))
    .map(([key]) => [key, raw[key as keyof WorkoutRankingContext]]));
}
function supportedFactor(factor: WorkoutRankingFactor, context: WorkoutRankingContext): boolean {
  switch (factor) {
    case 'goal_match':
    case 'coach_specialization': return context.goal !== undefined;
    case 'experience_match': return context.experience !== undefined;
    case 'duration_match': return context.duration !== undefined;
    case 'equipment_match': return context.equipment !== undefined;
    case 'completion': return context.completion !== undefined;
    case 'repetition_volume': return context.reps !== undefined;
    case 'form_practice': return context.form !== undefined;
    case 'training_frequency': return context.frequency !== undefined;
    default: return true;
  }
}

function assertWorkoutRequest(value: unknown): asserts value is AnonymousWorkoutRankingRequest {
  const invalid = (): never => { throw new RecommendationProviderError('invalid_request'); };
  if (!isRecord(value) || !exactKeys(value, ['schemaVersion', 'promptVersion', 'context', 'candidates']) ||
    value.schemaVersion !== 1 || value.promptVersion !== 'module13-workout-v1' || !isRecord(value.context)) return invalid();
  const context = value.context;
  if (Object.keys(context).some(key => !Object.hasOwn(CONTEXT_VALUES, key) ||
    !includes(CONTEXT_VALUES[key as keyof WorkoutRankingContext], context[key]))) return invalid();
  if (!Array.isArray(value.candidates) || !value.candidates.length || value.candidates.length > 18) return invalid();
  const labels = new Set<string>();
  const counts: Partial<Record<WorkoutRecommendationKind, number>> = {};
  const prefix = {trainer: 'C', content: 'T', routine: 'R'};
  for (const entry of value.candidates) {
    if (!isRecord(entry) || !includes(KINDS, entry.kind) || typeof entry.label !== 'string' ||
      Object.keys(entry).some(key => !['label', 'kind', 'factors', 'duration', 'difficulty'].includes(key))) return invalid();
    const kind = entry.kind as WorkoutRecommendationKind;
    if (!new RegExp('^' + prefix[kind] + '[1-6]$').test(entry.label) || labels.has(entry.label) ||
      !Array.isArray(entry.factors) || entry.factors.length > WORKOUT_RANKING_FACTORS.length ||
      new Set(entry.factors).size !== entry.factors.length ||
      entry.factors.some(factor => !includes(WORKOUT_RANKING_FACTORS, factor) ||
        !supportedFactor(factor as WorkoutRankingFactor, context))) return invalid();
    if (entry.duration !== undefined && !includes(CONTEXT_VALUES.duration, entry.duration) ||
      entry.difficulty !== undefined && !includes(CONTEXT_VALUES.experience, entry.difficulty)) return invalid();
    counts[kind] = (counts[kind] ?? 0) + 1;
    if (counts[kind]! > WORKOUT_RANKING_LIMITS.candidatesPerKind) return invalid();
    labels.add(entry.label);
  }
}

/** One shared request for available kinds. Five-minute feature cache and a warm
 * instance request budget also coalesce identical concurrent requests. */
export function createGeminiWorkoutRecommendationRanker(options: GeminiRankingOptions): WorkoutRankingProvider {
  return createGeminiRankingProvider({
    ...options, timeoutMillis: options.timeoutMillis ?? WORKOUT_RANKING_LIMITS.timeoutMillis,
  }, {
    assertRequest: assertWorkoutRequest, systemPrompt: PROMPT, responseSchema: SCHEMA,
    maxOutputTokens: WORKOUT_RANKING_LIMITS.maxOutputTokens,
    maxRequestBytes: WORKOUT_RANKING_LIMITS.maxRequestBytes,
    requestWindowMillis: WORKOUT_RANKING_LIMITS.requestWindowMillis,
    includeSchemaInPrompt: false,
  });
}

/** Gemini selects the facts it used. Local rendering keeps every reason tied to
 * supplied, server-verified evidence and avoids accepting arbitrary model claims. */
function personalizedReason(context: WorkoutRankingContext, factors: readonly WorkoutRankingFactor[]): string {
  const goal = {
    strength: 'building strength', endurance: 'improving endurance', mobility: 'improving mobility',
    general_fitness: 'general fitness', muscle_gain: 'building muscle', weight_management: 'weight management',
  };
  const frequency = {
    new: 'A manageable next step as you build your workout habit.',
    occasional: 'A practical way to make your recent workouts more consistent.',
    regular: 'A useful next step alongside your regular workouts.',
  };
  const reasons: Record<WorkoutRankingFactor, string> = {
    exercise_match: 'Build on the exercise you recently practised.',
    goal_match: context.goal ? 'Supports your goal of ' + goal[context.goal] + '.' : '',
    experience_match: context.experience ? 'Matches your ' + context.experience + ' experience level.' : '',
    duration_match: context.duration ? 'Fits your preference for a ' + context.duration + ' workout.' : '',
    equipment_match: 'Uses equipment that matches your workout preferences.',
    recent_activity: 'Build on your recent workout practice.',
    completion: context.completion === 'partial' ?
      'Take a manageable next step after your unfinished workout.' : 'Keep building on your completed workout.',
    repetition_volume: context.reps === 'high' ?
      'Build on the repetitions you have already completed.' : 'Add focused practice at your current repetition level.',
    form_practice: context.form === 'developing' ?
      'Focus on movement control after your recent comparable form observations.' :
      'Build on your consistent recent form observations.',
    coach_specialization: context.goal ? 'This coach specializes in ' + goal[context.goal] + '.' : '',
    training_frequency: context.frequency ? frequency[context.frequency] : '',
  };
  return factors.map(factor => reasons[factor]).filter(Boolean).join(' ');
}

interface LocalCandidate<T> {
  candidate: WorkoutRankingCandidate<T>;
  payload: AnonymousWorkoutCandidate;
}
function localCandidates<T>(
  context: WorkoutRankingContext, candidates: readonly WorkoutRankingCandidate<T>[],
): LocalCandidate<T>[] {
  const prefix = {trainer: 'C', content: 'T', routine: 'R'};
  return KINDS.flatMap(kind => candidates.filter(candidate => candidate.kind === kind)
    .slice(0, WORKOUT_RANKING_LIMITS.candidatesPerKind).map((candidate, index) => ({
      candidate,
      payload: {
        label: prefix[kind] + (index + 1), kind,
        factors: [...new Set(candidate.factors.filter(factor =>
          WORKOUT_RANKING_FACTORS.includes(factor) && supportedFactor(factor, context)))],
        ...(includes(CONTEXT_VALUES.duration, candidate.duration) ? {duration: candidate.duration} : {}),
        ...(includes(CONTEXT_VALUES.experience, candidate.difficulty) ? {difficulty: candidate.difficulty} : {}),
      },
    })));
}

function validatedSelection<T>(raw: unknown, entries: LocalCandidate<T>[]): {
  ranking: LocalCandidate<T>[]; factors: WorkoutRankingFactor[];
} | null {
  if (!isRecord(raw) || !exactKeys(raw, ['recommendationType', 'selectedCandidateId', 'ranking', 'relevantWorkoutFactors']) ||
    raw.recommendationType !== entries[0].payload.kind || !Array.isArray(raw.ranking) ||
    raw.ranking.length !== entries.length || new Set(raw.ranking).size !== entries.length ||
    raw.selectedCandidateId !== raw.ranking[0] || !Array.isArray(raw.relevantWorkoutFactors) ||
    !raw.relevantWorkoutFactors.length || raw.relevantWorkoutFactors.length > 3 ||
    new Set(raw.relevantWorkoutFactors).size !== raw.relevantWorkoutFactors.length) return null;
  const byLabel = new Map(entries.map(entry => [entry.payload.label, entry]));
  const ranking = raw.ranking.map(label => typeof label === 'string' ? byLabel.get(label) : undefined);
  if (ranking.some(entry => !entry)) return null;
  const selected = ranking[0]!;
  if (raw.relevantWorkoutFactors.some(factor => !selected.payload.factors.includes(factor as WorkoutRankingFactor))) return null;
  return {ranking: ranking as LocalCandidate<T>[], factors: raw.relevantWorkoutFactors as WorkoutRankingFactor[]};
}

export async function rankWorkoutRecommendations<T>(
  provider: WorkoutRankingProvider | undefined,
  rawContext: WorkoutRankingContext,
  candidates: readonly WorkoutRankingCandidate<T>[],
): Promise<WorkoutRankingResult<T>> {
  const context = minimizedContext(rawContext);
  const entries = localCandidates(context, candidates);
  const result: WorkoutRankingResult<T> = {selections: {}};
  for (const kind of KINDS) {
    const group = entries.filter(entry => entry.payload.kind === kind);
    if (group.length) {
      result.selections[kind] = {
        candidate: group[0].candidate, method: 'rule_fallback',
        factors: group[0].payload.factors, ranking: group.map(entry => entry.candidate), changedOrder: false,
      };
    }
  }
  if (!provider || !entries.length) return result;
  let inference: RankingInference;
  try {
    inference = await provider({
      schemaVersion: 1, promptVersion: 'module13-workout-v1', context,
      candidates: entries.map(entry => entry.payload),
    });
  } catch (error) {
    result.failure = error instanceof RecommendationProviderError ? error.reason : 'provider_unavailable';
    return result;
  }
  const {text, ...metadata} = inference;
  result.inference = metadata;
  let raw: unknown;
  try { raw = JSON.parse(text); }
  catch {
    result.failure = 'invalid_provider_output';
    return result;
  }
  if (!isRecord(raw) || !exactKeys(raw, ['recommendations']) ||
    !Array.isArray(raw.recommendations) || raw.recommendations.length > 3) {
    result.failure = 'invalid_provider_output';
    return result;
  }
  const recommendations = raw.recommendations;
  if (recommendations.some(entry => !isRecord(entry) || !includes(KINDS, entry.recommendationType) ||
    !result.selections[entry.recommendationType as WorkoutRecommendationKind])) result.failure = 'invalid_provider_output';
  for (const kind of KINDS) {
    const group = entries.filter(entry => entry.payload.kind === kind);
    if (!group.length) continue;
    const matches = recommendations.filter(entry => isRecord(entry) && entry.recommendationType === kind);
    const selected = matches.length === 1 ? validatedSelection(matches[0], group) : null;
    if (!selected) {
      result.failure = 'invalid_provider_output';
      continue;
    }
    result.selections[kind] = {
      candidate: selected.ranking[0].candidate, method: 'gemini', factors: selected.factors,
      reason: personalizedReason(context, selected.factors),
      ranking: selected.ranking.map(entry => entry.candidate),
      changedOrder: selected.ranking.some((entry, index) => entry !== group[index]),
    };
  }
  return result;
}
