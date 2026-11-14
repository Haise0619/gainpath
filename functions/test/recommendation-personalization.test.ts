import {describe,it,expect} from 'vitest';
import {recommendationPreferences,selectPersonalizedRecommendation,type ReviewedPersonalizationCandidate} from '../src/modules/recommendation/recommendation-personalization';
const need={exercise:'squat',objective:'technique_foundations',level:'beginner'} as const;
const candidate=(id:string,kind:'content'|'trainer'='content'):ReviewedPersonalizationCandidate<string>=>({id,kind,exercise:'squat',objectives:['technique_foundations'],levels:['beginner','intermediate','advanced'],goals:[],deterministicScore:50,target:id});
describe('stated Member preferences and content-first recommendations',()=>{
 it('uses actual profile wire goals, preserves unknown and excludes other private profile fields',()=>{
  expect(recommendationPreferences({experience:'intermediate',goals:['buildMuscle','generalFitness','buildMuscle','muscleGain','weightLoss','strength'],weightKg:65})).toEqual({experience:'intermediate',goals:['buildMuscle','generalFitness']});
  expect(recommendationPreferences({experience:'expert',goals:'generalFitness'})).toEqual({experience:null,goals:[]});
 });
 it('prefers suitable educational content over higher-score coaching and exposes coaching as optional',()=>{
  const r=selectPersonalizedRecommendation(need,{experience:'beginner',goals:['generalFitness']},[{...candidate('coach','trainer'),deterministicScore:100,goals:['generalFitness']},candidate('guide')]);
  expect(r?.primary.id).toBe('guide');expect(r?.optionalCoach?.id).toBe('coach');expect(r?.explanations).toEqual(['A guide for the exercise you practised.','Suitable for your stated beginner experience level.']);
 });
 it('uses stated goal mapping and experience without changing an evidence-derived objective',()=>{
  const r=selectPersonalizedRecommendation(need,{experience:'advanced',goals:['buildMuscle']},[{...candidate('general'),deterministicScore:100},{...candidate('goal-guide'),goals:['buildMuscle']},{...candidate('beginner-only'),levels:['beginner'],goals:['buildMuscle'],deterministicScore:100}]);
  expect(r?.primary.id).toBe('goal-guide');expect(r?.need).toEqual({...need,level:'advanced'});expect(r?.explanations).toContain('Matches your stated build muscle goal.');expect(r?.explanations.join(' ')).not.toMatch(/fault|injury|control|repetitions/i);
 });
 it('never uses goal fit to admit a wrong exercise or objective, and abstains if no suitable candidate',()=>{
  const wrong={...candidate('wrong'),exercise:'single_arm_curl' as const,goals:['buildMuscle' as const]};
  expect(selectPersonalizedRecommendation(need,{goals:['buildMuscle']},[wrong])).toBeNull();
  expect(selectPersonalizedRecommendation(need,null,[{...candidate('wrong-objective'),objectives:['endurance']}])).toBeNull();
 });
 it('offers eligible coaching when no suitable guide exists, without claiming measured faults',()=>{
  const r=selectPersonalizedRecommendation(need,null,[candidate('coach','trainer')]);expect(r?.primary.id).toBe('coach');expect(r?.explanations).toEqual(['Optional coaching for the exercise you practised.']);
 });
 it('keeps preference identity stable across goal order, unknown aliases and unrelated measurements',()=>{
  const a=selectPersonalizedRecommendation(need,{experience:'beginner',goals:['buildMuscle','generalFitness'],weightKg:60},[candidate('guide')]);
  const b=selectPersonalizedRecommendation(need,{experience:'beginner',goals:['generalFitness','buildMuscle','muscleGain'],weightKg:90},[candidate('guide')]);expect(a?.profileFingerprint).toBe(b?.profileFingerprint);
 });
});
