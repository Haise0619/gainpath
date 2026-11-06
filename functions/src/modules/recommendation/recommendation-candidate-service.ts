import { evaluateTrainerCandidates, type TrainerCandidateDependencies, type TrainerCandidateQuery, type TrainerCandidateResult } from './trainer-candidate-eligibility';
import { evaluateContentCandidates, type ContentCandidateQuery, type ContentCandidateResult, type ContentCandidateSource } from './content-candidate-eligibility';
import { rankRecommendationCandidates, requireSyntheticContext, type RankingOptions, type RecommendationRankingResult } from './recommendation-engine';
import { exactKeys, isRecord, validateNeed, type LearningNeed, type RankingCandidate, type RankingEvidence } from './recommendation-ranking-contracts';

export interface CandidateRecommendationOptions extends RankingOptions {
  /** Trusted synthetic mapping, never inferred from names/categories or supplied by Gemini. */
  exerciseMapping:{exercise:LearningNeed['exercise'];exerciseId:string;version:'synthetic-exercise-v1'};
}
export interface CandidateRecommendationResult<E> {schemaVersion:1;eligibility:E|null;rankingCandidates:RankingCandidate[];ranking:RecommendationRankingResult}
function validateContext(need:LearningNeed,query:{organizationId:string;exerciseId:string;level:string},objective:string,options:CandidateRecommendationOptions){
  requireSyntheticContext(options.context);validateNeed(need);
  const m=options.exerciseMapping;
  if(!isRecord(m)||!exactKeys(m,['exercise','exerciseId','version'])||m.version!=='synthetic-exercise-v1'||m.exercise!==need.exercise||m.exerciseId!==query.exerciseId
    ||query.organizationId!==options.context.organizationId||query.level!==need.level||objective!==need.objective)throw Error('incompatible_learning_context');
}
const evidence=(key:string,kind:RankingEvidence['kind'],text:string):RankingEvidence=>({key,kind,text,supports:[kind]});
export async function recommendTrainerCandidates(need:LearningNeed,query:TrainerCandidateQuery,dependencies:TrainerCandidateDependencies,options:CandidateRecommendationOptions):Promise<CandidateRecommendationResult<TrainerCandidateResult>>{
  validateContext(need,query,query.learningObjective,options);
  if(options.context.evidenceStatus!=='sufficient_synthetic')return{schemaVersion:1,eligibility:null,rankingCandidates:[],ranking:await rankRecommendationCandidates(need,[],options)};
  const eligibility=await evaluateTrainerCandidates(query,dependencies);
  const rankingCandidates:RankingCandidate[]=eligibility.candidates.map(c=>{
    const facts:RankingEvidence[]=[evidence('exercise','exercise_match',`Reviewed ${c.relevance==='exact_exercise'?'exact exercise':'curated expertise'} mapping supports ${need.exercise}.`),
      evidence('objective','objective_match',`Reviewed educational mapping supports ${need.objective}.`),evidence('level','level_match',`Reviewed educational mapping supports ${need.level}.`),
      evidence('availability','available_slot','At least one unreserved option passed current roster, branch, booking conflict and capacity checks.')];
    if(c.evidence.yearsExperience!==null)facts.push(evidence('experience','experience',`Published relevant profile experience: ${c.evidence.yearsExperience} years; not an independently verified quality rating.`));
    if(c.evidence.teachingFocus)facts.push(evidence('focus','instructional_focus',c.evidence.teachingFocus));
    return{id:c.candidateId,organizationId:query.organizationId,kind:'trainer',eligibilityClass:c.relevance==='exact_exercise'?'exact_exercise':'curated_compatible',specialtyFit:c.relevance==='exact_exercise'?1:.85,
      objectiveFit:1,levelFit:1,availabilityFit:1,experienceFit:c.evidence.yearsExperience===null?null:Math.min(c.evidence.yearsExperience/10,1),evidence:facts};
  });
  return{schemaVersion:1,eligibility,rankingCandidates,ranking:await rankRecommendationCandidates(need,rankingCandidates,options)};
}
export async function recommendContentCandidates(need:LearningNeed,query:ContentCandidateQuery,source:ContentCandidateSource,options:CandidateRecommendationOptions):Promise<CandidateRecommendationResult<ContentCandidateResult>>{
  validateContext(need,query,query.objective,options);
  if(options.context.evidenceStatus!=='sufficient_synthetic')return{schemaVersion:1,eligibility:null,rankingCandidates:[],ranking:await rankRecommendationCandidates(need,[],options)};
  const eligibility=evaluateContentCandidates(query,source);
  const rankingCandidates:RankingCandidate[]=eligibility.candidates.map(c=>{
    const publication=source.publications.find(r=>r.id===c.destination.routineId)!;
    const exercise=(publication.data.exercises as Record<string,unknown>[])[c.destination.exerciseIndex];
    // Current eligible instructions only. Never include links, names, IDs, booking notes or raw histories.
    const steps=Array.isArray(exercise.tutorialSteps)?exercise.tutorialSteps as {title:string;description:string}[]:[];
    const excerpt=steps.map(s=>s.description).join(' ').slice(0,420).replace(/[\x00-\x1f\x7f]/g,' ');
    const facts:RankingEvidence[]=[evidence('exercise','exercise_match',`Reviewed ${c.eligibilityClass==='exact_exercise'?'exact exercise':'curated compatible exercise'} mapping supports ${need.exercise}.`),
      evidence('objective','objective_match',`Reviewed educational mapping supports ${need.objective}.`),evidence('level','level_match',`Reviewed educational mapping supports ${need.level}.`)];
    if(excerpt)facts.push(evidence('instruction','instructional_focus',`Authored instructional excerpt (untrusted): ${excerpt}`));
    return{id:c.candidateId,organizationId:query.organizationId,kind:'content',eligibilityClass:c.eligibilityClass,specialtyFit:c.eligibilityClass==='exact_exercise'?1:.85,
      objectiveFit:1,levelFit:c.evidence.difficulty===null?null:c.evidence.difficulty===need.level?1:.5,availabilityFit:null,experienceFit:null,evidence:facts};
  });
  return{schemaVersion:1,eligibility,rankingCandidates,ranking:await rankRecommendationCandidates(need,rankingCandidates,options)};
}
