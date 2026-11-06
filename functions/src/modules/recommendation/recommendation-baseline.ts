import { classOrder, isRecord, REASON_CODES, stableCompare, type BaselineEntry, type Components, type RankingCandidate } from './recommendation-ranking-contracts';

/** Experimental weights, not clinical evidence or measured recommendation accuracy. */
export const BASELINE_WEIGHTS = Object.freeze({
  trainer: { specialtyFit: 35, objectiveFit: 30, levelFit: 10, availabilityFit: 15, experienceFit: 10 },
  content: { specialtyFit: 50, objectiveFit: 30, levelFit: 20, availabilityFit: 0, experienceFit: 0 },
});
const components = ['specialtyFit', 'objectiveFit', 'levelFit', 'availabilityFit', 'experienceFit'] as const;
export function validateCandidates(candidates: readonly RankingCandidate[]): void {
  if (!Array.isArray(candidates) || candidates.length > 20 || new Set(candidates.map(c => c?.id)).size !== candidates.length) throw Error('invalid_candidate_set');
  const org = candidates[0]?.organizationId, kind = candidates[0]?.kind;
  for (const c of candidates) {
    if (!isRecord(c) || typeof c.id !== 'string' || !/^[\w:.-]{1,256}$/.test(c.id) || typeof c.organizationId !== 'string' || !/^[\w-]{1,128}$/.test(c.organizationId)
      || c.organizationId !== org || c.kind !== kind || typeof c.kind !== 'string' || !['trainer', 'content'].includes(c.kind) || typeof c.eligibilityClass !== 'string' || !['exact_exercise', 'curated_compatible'].includes(c.eligibilityClass)
      || components.some(k => c[k] !== null && (typeof c[k] !== 'number' || !Number.isFinite(c[k]) || c[k]! < 0 || c[k]! > 1))
      || !Array.isArray(c.evidence) || c.evidence.length < 1 || c.evidence.length > 12 || new Set(c.evidence.map(e => e?.key)).size !== c.evidence.length
      || c.evidence.some(e => !isRecord(e) || typeof e.key !== 'string' || !/^[\w.-]{1,64}$/.test(e.key) || !REASON_CODES.includes(e.kind as any)
        || typeof e.text !== 'string' || !e.text.trim() || e.text.length > 480 || /[\x00-\x08\x0b-\x1f]/.test(e.text)
        || !Array.isArray(e.supports) || !e.supports.length || e.supports.length > REASON_CODES.length || new Set(e.supports).size !== e.supports.length || e.supports.some(r => !REASON_CODES.includes(r)))) throw Error('invalid_candidate_set');
  }
}
export function baselineRankCandidates(candidates: readonly RankingCandidate[]): BaselineEntry[] {
  validateCandidates(candidates);
  return candidates.map(c => {
    const weights = BASELINE_WEIGHTS[c.kind], known = components.filter(k => c[k] !== null && weights[k] > 0);
    const denominator = known.reduce((sum, k) => sum + weights[k], 0);
    if (!denominator) throw Error('unsupported_candidate_evidence');
    const score = Math.round(10000 * known.reduce((sum, k) => sum + weights[k] * c[k]!, 0) / denominator) / 100;
    const values = Object.fromEntries(components.map(k => [k, c[k]])) as unknown as Components;
    return { id: c.id, eligibilityClass: c.eligibilityClass, score, components: values, evidenceKeys: c.evidence.map(e => e.key).sort(stableCompare) };
  }).sort((a,b) => classOrder(a.eligibilityClass) - classOrder(b.eligibilityClass) || b.score - a.score || stableCompare(a.id,b.id));
}
