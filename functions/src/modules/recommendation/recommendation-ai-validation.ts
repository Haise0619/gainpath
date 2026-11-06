import { validateCandidates } from './recommendation-baseline';
import { exactKeys, isRecord, REASON_CODES, stableCompare, validateNeed, type AnonymousRankingRequest, type LearningNeed, type RankingCandidate, type ValidatedAiEntry } from './recommendation-ranking-contracts';

export const RANKING_RESPONSE_SCHEMA = {
  type: 'object', additionalProperties: false, properties: { schemaVersion: { type: 'integer', enum: [1] }, rankings: {
    type: 'array', minItems: 1, maxItems: 20, items: { type: 'object', additionalProperties: false,
      properties: { label: { type: 'string' }, relevance: { type: 'number', minimum: 0, maximum: 100 },
        reasonCodes: { type: 'array', maxItems: 6, items: { type: 'string', enum: [...REASON_CODES] } },
        evidenceRefs: { type: 'array', maxItems: 12, items: { type: 'string' } }, abstain: { type: 'boolean' } },
      required: ['label', 'relevance', 'reasonCodes', 'evidenceRefs', 'abstain'] },
  } }, required: ['schemaVersion', 'rankings'],
};
export function buildAnonymousRankingRequest(need: LearningNeed, candidates: readonly RankingCandidate[]): AnonymousRankingRequest {
  validateNeed(need); validateCandidates(candidates);
  if (!candidates.length) throw Error('empty_candidate_set');
  const labels: AnonymousRankingRequest['labels'] = new Map();
  let withheldEvidenceCount=0;
  const projected = [...candidates].sort((a,b) => stableCompare(a.id,b.id)).map((c,i) => {
    // Defense in depth, not a complete prompt-injection detector. Withheld text is
    // unknown; candidate eligibility and baseline features are never downgraded.
    const safeEvidence=c.evidence.filter(e=>{
      const directives=/\b(?:system|developer|assistant)\s*:|\bignore\b.{0,80}\b(?:instructions?|rules?|objective|prompt)\b|\brank\s+C\d|\b(?:invent|new)\b.{0,30}\b(?:coach|tutorial|url|id)\b|\b(?:diagnos\w*|prescri\w*|cure\w*|treatments?)\b/i.test(e.text);
      if(directives)withheldEvidenceCount++;return !directives;
    }).sort((a,b)=>stableCompare(a.key,b.key));
    if(!safeEvidence.length)throw Error('no_safe_semantic_evidence');
    const label = `C${i+1}`, evidence = safeEvidence.map((e,j) => ({ ref: `E${i+1}_${j+1}`, kind: e.kind, text: e.text, supports: [...e.supports] }));
    (labels as Map<string, any>).set(label, { candidateId: c.id, evidence: new Map(evidence.map((e,j) => [e.ref, safeEvidence[j]])) });
    return { label, evidence };
  });
  return { payload: { schemaVersion: 1, promptVersion: 'module13-rank-v1', kind: candidates[0].kind, learningNeed: { ...need }, candidates: projected }, labels,withheldEvidenceCount };
}
export function validateAiRanking(text: string, request: AnonymousRankingRequest): { entries: ValidatedAiEntry[] } {
  const bad = (): never => { throw Error('invalid_ai_output'); };
  if (typeof text !== 'string' || Buffer.byteLength(text, 'utf8') > 32768) return bad();
  let raw: unknown; try { raw = JSON.parse(text); } catch { return bad(); }
  if (!isRecord(raw) || !exactKeys(raw, ['schemaVersion', 'rankings']) || raw.schemaVersion !== 1 || !Array.isArray(raw.rankings)
    || raw.rankings.length !== request.labels.size || new Set(raw.rankings.map(r => r?.label)).size !== request.labels.size) return bad();
  const entries = raw.rankings.map((r): ValidatedAiEntry => {
    if (!isRecord(r) || !exactKeys(r, ['label', 'relevance', 'reasonCodes', 'evidenceRefs', 'abstain']) || typeof r.label !== 'string'
      || !request.labels.has(r.label) || typeof r.relevance !== 'number' || !Number.isFinite(r.relevance) || r.relevance < 0 || r.relevance > 100 || typeof r.abstain !== 'boolean'
      || !Array.isArray(r.reasonCodes) || r.reasonCodes.length > 6 || new Set(r.reasonCodes).size !== r.reasonCodes.length || r.reasonCodes.some(code => !REASON_CODES.includes(code))
      || !Array.isArray(r.evidenceRefs) || r.evidenceRefs.length > 12 || new Set(r.evidenceRefs).size !== r.evidenceRefs.length) return bad();
    const binding = request.labels.get(r.label)!;
    if (r.evidenceRefs.some(ref => typeof ref !== 'string' || !binding.evidence.has(ref))) return bad();
    const evidence = r.evidenceRefs.map(ref => binding.evidence.get(ref)!);
    if (r.abstain ? r.relevance !== 0 || r.reasonCodes.length !== 0 || evidence.length !== 0
      : r.reasonCodes.length === 0 || evidence.length === 0 || r.reasonCodes.some(code => !evidence.some(e => e.supports.includes(code)))) return bad();
    return { candidateId: binding.candidateId, relevance: r.relevance, reasonCodes: r.reasonCodes, evidenceKeys: evidence.map(e => e.key), abstain: r.abstain };
  });
  return { entries };
}
