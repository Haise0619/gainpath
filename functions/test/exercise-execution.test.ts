import {it,expect} from 'vitest';
import {AI_EXERCISE_IDS, resolveExerciseExecution, parseExercisePrescription} from '../src/modules/content/exercise-execution';

it('retains active tracking registrations and rejects copied or conflicting identities', () => {
 const ids = [
  'standing-lateral-raise-front-v1',
  'dumbbell-shoulder-press-front-v1',
  'F3b8xIr8ynBDd3gEICKX',
  'standing-single-arm-curl-side-v1',
  'standing-calf-raise-side-v1',
  'standard-floor-push-up-side-v1',
 ];
 for (const id of ids) {
  expect(resolveExerciseExecution('gainpath', id, {}), id).toBe('aiTracked');
  expect(() => resolveExerciseExecution('other', id, {executionMode: 'aiTracked'})).toThrow();
  expect(() => resolveExerciseExecution('gainpath', id, {executionMode: 'videoGuidedTimed'})).toThrow();
 }
 expect(resolveExerciseExecution('gainpath', 'custom', {})).toBe('legacyManual');
});

it.each([
 'bodyweight-reverse-lunge-side-v1',
 'wall-push-up-side-v1',
 'single-arm-dumbbell-row-side-v1',
])('keeps retired exercise %s compatible with backups and resolves its old catalog entry as manual', id => {
 expect(AI_EXERCISE_IDS).toContain(id);
 expect(resolveExerciseExecution('gainpath', id, {})).toBe('legacyManual');
 expect(resolveExerciseExecution('gainpath', id, {executionMode: 'aiTracked'})).toBe('legacyManual');
 expect(() => resolveExerciseExecution('other', id, {executionMode: 'aiTracked'})).toThrow();
 expect(() => resolveExerciseExecution('gainpath', id, {executionMode: 'videoGuidedTimed'})).toThrow();
});
it('bounds typed targets and forbids mixed targets and excessive duration',()=>{
 const timed={executionMode:'videoGuidedTimed',sets:3,durationSeconds:45,restSeconds:30};
 expect(parseExercisePrescription(timed)).toEqual(timed);
 for(const patch of [{reps:0},{durationSeconds:0},{sets:51},{sets:50,durationSeconds:3600},{restSeconds:601}]) expect(()=>parseExercisePrescription({...timed,...patch})).toThrow();
});
