import {digestOf} from '../workouts/workout-backup-validation';
import {LEVELS,validateNeed,type LearningNeed} from './recommendation-ranking-contracts';

/** Wire values from gainpath_domain FitnessGoal; no diagnosis or inferred preferences. */
export const MEMBER_FITNESS_GOALS=['loseWeight','buildMuscle','improveEndurance','increaseFlexibility','generalFitness','reduceStress'] as const;
export type MemberFitnessGoal=typeof MEMBER_FITNESS_GOALS[number];
export interface RecommendationPreferences {experience:LearningNeed['level']|null;goals:MemberFitnessGoal[]}
const GOAL_LABEL:Record<MemberFitnessGoal,string>={loseWeight:'lose weight',buildMuscle:'build muscle',improveEndurance:'improve endurance',increaseFlexibility:'increase flexibility',generalFitness:'general fitness',reduceStress:'reduce stress'};
/** Missing/unknown preferences remain unknown. Never inspect weight, age or other private measurements. */
export function recommendationPreferences(raw:unknown):RecommendationPreferences{
 const profile=raw&&typeof raw==='object'&&!Array.isArray(raw)?raw as Record<string,unknown>:{};
 const goals=Array.isArray(profile.goals)?profile.goals:[];
 return{experience:LEVELS.includes(profile.experience as any)?profile.experience as LearningNeed['level']:null,
  goals:MEMBER_FITNESS_GOALS.filter(g=>goals.includes(g))};
}
export interface ReviewedPersonalizationCandidate<T> {
 id:string;kind:'content'|'trainer';exercise:LearningNeed['exercise'];objectives:readonly LearningNeed['objective'][];
 levels:readonly LearningNeed['level'][];goals:readonly MemberFitnessGoal[];deterministicScore:number;target:T;
}
export interface PersonalizedRecommendation<T>{primary:ReviewedPersonalizationCandidate<T>;optionalCoach:ReviewedPersonalizationCandidate<T>|null;need:LearningNeed;profileFingerprint:string;explanations:string[]}
/** Applies only to candidates already authorized/published/available by the server.
 * Reviewed mappings describe suitability; goal labels cannot create movement faults,
 * change the measured learning objective or make an ineligible target eligible. */
export function selectPersonalizedRecommendation<T>(need:LearningNeed,rawProfile:unknown,candidates:readonly ReviewedPersonalizationCandidate<T>[]):PersonalizedRecommendation<T>|null{
 validateNeed(need);
 if(candidates.length>20||new Set(candidates.map(c=>c.id)).size!==candidates.length)throw Error('invalid_personalization_candidates');
 const preferences=recommendationPreferences(rawProfile),level=preferences.experience??need.level;
 const eligible=candidates.filter(c=>c.exercise===need.exercise&&c.objectives.includes(need.objective)&&c.levels.includes(level));
 if(eligible.some(c=>!['content','trainer'].includes(c.kind)||!Number.isFinite(c.deterministicScore)||c.deterministicScore<0||c.deterministicScore>100||c.goals.some(g=>!MEMBER_FITNESS_GOALS.includes(g))))throw Error('invalid_personalization_candidates');
 const goalMatches=(c:ReviewedPersonalizationCandidate<T>)=>preferences.goals.filter(g=>c.goals.includes(g));
 const ordered=[...eligible].sort((a,b)=>(a.kind==='content'?0:1)-(b.kind==='content'?0:1)||goalMatches(b).length-goalMatches(a).length||b.deterministicScore-a.deterministicScore||(a.id<b.id?-1:a.id>b.id?1:0));
 const primary=ordered[0];if(!primary)return null;
 const matched=goalMatches(primary);
 const explanations=[primary.kind==='content'?'A guide for the exercise you practised.':'Optional coaching for the exercise you practised.'];
 if(preferences.experience)explanations.push(`Suitable for your stated ${preferences.experience} experience level.`);
 if(matched.length)explanations.push(`Matches your stated ${matched.map(g=>GOAL_LABEL[g]).join(' and ')} ${matched.length===1?'goal':'goals'}.`);
 return{primary,optionalCoach:primary.kind==='content'?ordered.find(c=>c.kind==='trainer')??null:null,need:{...need,level},profileFingerprint:digestOf(preferences),explanations};
}
