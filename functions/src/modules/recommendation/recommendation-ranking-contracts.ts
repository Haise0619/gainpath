/** Internal local-development contracts. No callable, datastore or consent authority. */
export const OBJECTIVES = ['technique_foundations', 'movement_control', 'progression', 'endurance'] as const;
export const LEVELS = ['beginner', 'intermediate', 'advanced'] as const;
export const EXERCISES = ['squat', 'wall_push_up', 'reverse_lunge', 'shoulder_press', 'single_arm_row', 'calf_raise', 'single_arm_curl'] as const;
export type LearningNeed = { exercise: typeof EXERCISES[number]; objective: typeof OBJECTIVES[number]; level: typeof LEVELS[number] };
export const REASON_CODES = ['exercise_match', 'objective_match', 'level_match', 'available_slot', 'experience', 'instructional_focus'] as const;
export type ReasonCode = typeof REASON_CODES[number];
export interface RankingEvidence { key: string; kind: ReasonCode; text: string; supports: ReasonCode[] }
export interface RankingCandidate {
  id: string; organizationId: string; kind: 'trainer' | 'content'; eligibilityClass: 'exact_exercise' | 'curated_compatible';
  specialtyFit: number | null; objectiveFit: number | null; levelFit: number | null;
  availabilityFit: number | null; experienceFit: number | null;
  evidence: RankingEvidence[];
}
export type Components = Pick<RankingCandidate, 'specialtyFit' | 'objectiveFit' | 'levelFit' | 'availabilityFit' | 'experienceFit'>;
export interface BaselineEntry { id: string; eligibilityClass: RankingCandidate['eligibilityClass']; score: number; components: Components; evidenceKeys: string[] }
export interface AnonymousRankingRequest {
  withheldEvidenceCount:number;
  payload: { schemaVersion: 1; promptVersion: 'module13-rank-v1'; kind: RankingCandidate['kind']; learningNeed: LearningNeed;
    candidates: { label: string; evidence: { ref: string; kind: ReasonCode; text: string; supports: ReasonCode[] }[] }[] };
  /** Server-side only. Never serialize this wrapper to the provider. */
  labels: ReadonlyMap<string, { candidateId: string; evidence: ReadonlyMap<string, RankingEvidence> }>;
}
export interface ValidatedAiEntry { candidateId: string; relevance: number; reasonCodes: ReasonCode[]; evidenceKeys: string[]; abstain: boolean }
export interface ProviderUsage { inputTokens: number | null; outputTokens: number | null; thinkingTokens: number | null; totalTokens: number | null }
export interface RankingInference { text: string; model: string; latencyMillis: number; usage: ProviderUsage }
export type RankingProvider = (request: AnonymousRankingRequest['payload']) => Promise<RankingInference>;
export const classOrder = (value: RankingCandidate['eligibilityClass']): number => value === 'exact_exercise' ? 0 : 1;
export const stableCompare = (a: string, b: string): number => a < b ? -1 : a > b ? 1 : 0;
export const isRecord = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
export const exactKeys = (v: Record<string, unknown>, keys: readonly string[]): boolean => Object.keys(v).length === keys.length && Object.keys(v).every(k => keys.includes(k));
export function validateNeed(value: unknown): asserts value is LearningNeed {
  if (!isRecord(value) || !exactKeys(value, ['exercise', 'objective', 'level']) || !EXERCISES.includes(value.exercise as any)
    || !OBJECTIVES.includes(value.objective as any) || !LEVELS.includes(value.level as any)) throw Error('unsupported_learning_need');
}
