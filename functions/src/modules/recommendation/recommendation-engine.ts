import { baselineRankCandidates } from './recommendation-baseline';
import { buildAnonymousRankingRequest, validateAiRanking } from './recommendation-ai-validation';
import { RecommendationProviderError } from './gemini-recommendation-ranker';
import { classOrder, exactKeys, isRecord, stableCompare, validateNeed, type AnonymousRankingRequest, type BaselineEntry, type LearningNeed, type ProviderUsage, type RankingCandidate, type RankingProvider, type ReasonCode, type ValidatedAiEntry } from './recommendation-ranking-contracts';

export interface SyntheticRecommendationContext {
  mode: 'synthetic_local'; datasetId: 'module13-batch-b-v1'; organizationId: 'synthetic-org'|'gainpath';
  /** Fixture assertion only: never evaluates or replaces production consent/policy. */
  evidenceStatus: 'sufficient_synthetic' | 'insufficient' | 'unsupported' | 'missing_consent';
}
export interface RankingOptions { context: SyntheticRecommendationContext; provider?: RankingProvider; clock?:()=>number }
export interface FinalRecommendationEntry {id:string;eligibilityClass:RankingCandidate['eligibilityClass'];score:number;explanations:string[];evidenceKeys:string[]}
export interface RecommendationRankingResult {
  schemaVersion:1; status:'ranked'|'abstained';
  origin:'ai_reranked'|'deterministic_fallback'|'deterministic_single_candidate'|'abstained';
  baseline:BaselineEntry[]; ai:ValidatedAiEntry[]|null; final:FinalRecommendationEntry[];
  provenance:{rankingPolicy:'experimental-40-baseline-60-semantic-v1';promptVersion:'module13-rank-v1';schemaVersion:1;
    model:string|null;validationStatus:'not_called'|'valid'|'invalid'|'provider_failed';fallbackReason:string|null;
    latencyMillis:number|null;usage:ProviderUsage;withheldEvidenceCount:number;source:'synthetic_local';datasetId:'module13-batch-b-v1'};
}
const unknownUsage=():ProviderUsage=>({inputTokens:null,outputTokens:null,thinkingTokens:null,totalTokens:null});
const REASON_TEMPLATES:Record<ReasonCode,string>={
  exercise_match:'Reviewed mapping supports this exercise.',
  objective_match:'Reviewed educational mapping supports the selected learning objective.',
  level_match:'Reviewed educational mapping supports the selected experience level.',
  available_slot:'An eligible unreserved coaching option was observed; availability must be checked again before booking.',
  experience:'The published profile supplies experience information; it is not a quality guarantee.',
  instructional_focus:'The supplied educational description provides context for this learning need.',
};
export function requireSyntheticContext(context:SyntheticRecommendationContext):void {
  if(!isRecord(context)||!exactKeys(context,['mode','datasetId','organizationId','evidenceStatus'])||context.mode!=='synthetic_local'||context.datasetId!=='module13-batch-b-v1'||!['synthetic-org','gainpath'].includes(context.organizationId)
    ||typeof context.evidenceStatus!=='string'||!['sufficient_synthetic','insufficient','unsupported','missing_consent'].includes(context.evidenceStatus))throw Error('synthetic_local_only');
}
function baselineFinal(baseline:BaselineEntry[],candidates:readonly RankingCandidate[]):FinalRecommendationEntry[]{
  return baseline.map(b=>{const c=candidates.find(c=>c.id===b.id)!;const reasons=[...new Set(c.evidence.flatMap(e=>e.supports))];
    return{id:b.id,eligibilityClass:b.eligibilityClass,score:b.score,explanations:reasons.map(r=>REASON_TEMPLATES[r]),evidenceKeys:b.evidenceKeys};});
}
/** Pure local composition; no Firebase, histories, consent writes, leads, notifications or bookings. */
export async function rankRecommendationCandidates(need:LearningNeed,candidates:readonly RankingCandidate[],options:RankingOptions):Promise<RecommendationRankingResult>{
  requireSyntheticContext(options.context);validateNeed(need);
  if(candidates.some(c=>c.organizationId!==options.context.organizationId))throw Error('foreign_candidate_scope');
  const result:RecommendationRankingResult={schemaVersion:1,status:'abstained',origin:'abstained',baseline:[],ai:null,final:[],provenance:{rankingPolicy:'experimental-40-baseline-60-semantic-v1',promptVersion:'module13-rank-v1',schemaVersion:1,model:null,validationStatus:'not_called',fallbackReason:null,latencyMillis:null,usage:unknownUsage(),withheldEvidenceCount:0,source:'synthetic_local',datasetId:options.context.datasetId}};
  if(options.context.evidenceStatus!=='sufficient_synthetic'){result.provenance.fallbackReason=options.context.evidenceStatus;return result;}
  result.baseline=baselineRankCandidates(candidates);
  if(!candidates.length){result.provenance.fallbackReason='no_eligible_candidates';return result;}
  result.status='ranked';result.final=baselineFinal(result.baseline,candidates);
  if(candidates.length===1){result.origin='deterministic_single_candidate';result.provenance.fallbackReason='single_eligible_candidate';return result;}
  result.origin='deterministic_fallback';
  if(!options.provider){result.provenance.fallbackReason='provider_not_configured';return result;}
  let request:AnonymousRankingRequest;
  try{request=buildAnonymousRankingRequest(need,candidates);}catch{result.provenance.fallbackReason='no_safe_semantic_evidence';return result;}
  const clock=options.clock??Date.now,start=clock();
  result.provenance.withheldEvidenceCount=request.withheldEvidenceCount;
  let inference;
  try{inference=await options.provider(request.payload);}
  catch(error){result.provenance.validationStatus='provider_failed';result.provenance.fallbackReason=error instanceof RecommendationProviderError?error.reason:'provider_unavailable';result.provenance.latencyMillis=Math.max(0,clock()-start);return result;}
  result.provenance.model=inference.model;result.provenance.usage=inference.usage;result.provenance.latencyMillis=inference.latencyMillis;
  try{result.ai=validateAiRanking(inference.text,request).entries;}
  catch{result.provenance.validationStatus='invalid';result.provenance.fallbackReason='invalid_ai_output';return result;}
  result.provenance.validationStatus='valid';
  result.final=result.ai.filter(a=>!a.abstain).map(a=>{const baseline=result.baseline.find(b=>b.id===a.candidateId)!;
    return{id:baseline.id,eligibilityClass:baseline.eligibilityClass,score:Math.round((.4*baseline.score+.6*a.relevance)*100)/100,explanations:a.reasonCodes.map(r=>REASON_TEMPLATES[r]),evidenceKeys:a.evidenceKeys};
  }).sort((a,b)=>classOrder(a.eligibilityClass)-classOrder(b.eligibilityClass)||b.score-a.score||stableCompare(a.id,b.id));
  if(!result.final.length){result.status='abstained';result.origin='abstained';result.provenance.fallbackReason='semantic_abstention';}
  else{result.origin='ai_reranked';}
  return result;
}
