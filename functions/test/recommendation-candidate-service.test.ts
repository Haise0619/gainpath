import { expect, it, vi } from 'vitest';
import { recommendContentCandidates, recommendTrainerCandidates } from '../src/modules/recommendation/recommendation-candidate-service';
import { trainerFixture, trainerQuery, expertise } from './trainer-candidate.fixture';
import { digestOf } from '../src/modules/workouts/workout-backup-validation';
import type { ContentCandidateSource } from '../src/modules/recommendation/content-candidate-eligibility';
const need={exercise:'squat',objective:'technique_foundations',level:'beginner'} as const;
const context={mode:'synthetic_local',datasetId:'module13-batch-b-v1',organizationId:'synthetic-org',evidenceStatus:'sufficient_synthetic'} as const;
function content():ContentCandidateSource{
  const data={schemaVersion:1,kind:'routine',status:'published',sourceBlueprintId:'fictional-blueprint',title:'Fictional practice',estimatedMinutes:10,exercises:[{exerciseId:'fixture-squat',name:'Fictional squat',sets:2,reps:5,dayNumber:1,tutorialSteps:[{title:'Stance',description:'Practice foundational squat stance with controlled depth.'}]}]};
  return{schemaVersion:1,organizationId:'synthetic-org',sourceVersion:'fixture-v1',curationVersion:'curation-v1',memberAccess:'organization_published_routines',catalog:[{id:'fixture-squat',data:{isActive:true,exerciseName:'Fictional squat',muscleCategory:'Lower Body'}}],publications:[{id:'fixture-routine',data}],suitability:[{id:'fixture-curation',publicationId:'fixture-routine',exerciseIndex:0,publicationDigest:digestOf(data),objectives:['technique_foundations'],levels:['beginner']}],compatibleExercises:[]};
}
it('composes real publication eligibility into ranking and retains the resolvable destination',async()=>{
  const source=content();const result=await recommendContentCandidates(need,{organizationId:'synthetic-org',exerciseId:'fixture-squat',objective:need.objective,level:need.level},source,{context,exerciseMapping:{exercise:'squat',exerciseId:'fixture-squat',version:'synthetic-exercise-v1'}});
  expect(result.eligibility!.candidates).toHaveLength(1);expect(result.ranking.origin).toBe('deterministic_single_candidate');expect(result.eligibility!.candidates[0].destination.routineId).toBe('fixture-routine');
  expect(result.rankingCandidates[0].evidence.find(e=>e.kind==='instructional_focus')!.text).toContain('foundational squat');
});
it('composes current booking and credential eligibility with unknown-aware experience',async()=>{
  const {store,dependencies}=trainerFixture();
  const renamed=[...store.documents].map(([p,d])=>[p.replaceAll('org-1','synthetic-org'),JSON.parse(JSON.stringify(d).replaceAll('org-1','synthetic-org'))] as const);store.documents.clear();renamed.forEach(([p,d])=>store.documents.set(p,d));
  dependencies.trustedExpertise=[{...expertise,organizationId:'synthetic-org',teachingFocus:'Beginner squat foundations.'}];
  const query={...trainerQuery,organizationId:'synthetic-org'};
  const result=await recommendTrainerCandidates(need,query,dependencies,{context,exerciseMapping:{exercise:'squat',exerciseId:query.exerciseId,version:'synthetic-exercise-v1'}});
  expect(result.eligibility!.candidates).toHaveLength(1);expect(result.rankingCandidates[0].experienceFit).toBe(.3);expect(result.ranking.final).toHaveLength(1);
});
it('does not access candidate sources when evidence permission is missing',async()=>{
  const {dependencies}=trainerFixture();const spy=vi.fn(dependencies.repository.listCoachIds);dependencies.repository.listCoachIds=spy;
  const result=await recommendTrainerCandidates(need,{...trainerQuery,organizationId:'synthetic-org'},dependencies,{context:{...context,evidenceStatus:'missing_consent'},exerciseMapping:{exercise:'squat',exerciseId:trainerQuery.exerciseId,version:'synthetic-exercise-v1'}});
  expect(result.ranking.status).toBe('abstained');expect(spy).not.toHaveBeenCalled();expect(result.eligibility).toBeNull();
});
it('refuses mismatched exercise mapping or objective before source access',async()=>{
  await expect(recommendContentCandidates(need,{organizationId:'synthetic-org',exerciseId:'foreign',objective:need.objective,level:need.level},content(),{context,exerciseMapping:{exercise:'squat',exerciseId:'fixture-squat',version:'synthetic-exercise-v1'}})).rejects.toThrow();
});
