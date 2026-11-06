import {expect, it} from 'vitest';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {evaluateContentCandidates, type ContentCandidateSource, type ContentCandidateQuery} from '../src/modules/recommendation/content-candidate-eligibility';

const query: ContentCandidateQuery = {organizationId: 'synthetic_org', exerciseId: 'squat', objective: 'movement_control', level: 'beginner'};
function fixture(): ContentCandidateSource {
  const publication = {id: 'routine_synthetic', data: {schemaVersion: 1, kind: 'routine', status: 'published',
    sourceBlueprintId: 'synthetic', title: 'Synthetic instructions', estimatedMinutes: 10,
    exercises: [{exerciseId: 'squat', name: 'Synthetic squat', dayNumber: 1, sets: 3, reps: 8,
      tutorialSteps: [{title: 'Control movement', description: 'Follow the authored instructions.'}]}]}};
  return {schemaVersion: 1, organizationId: 'synthetic_org', sourceVersion: 'synthetic-source-v1',
    memberAccess: 'organization_published_routines', curationVersion: 'synthetic-curation-v1',
    catalog: [{id: 'squat', data: {isActive: true, exerciseName: 'Synthetic squat', muscleCategory: 'Lower Body'}},
      {id: 'wall_squat', data: {isActive: true, exerciseName: 'Synthetic wall squat', muscleCategory: 'Lower Body'}}],
    publications: [publication], compatibleExercises: [], suitability: [{id: 'synthetic_mapping', publicationId: publication.id,
      exerciseIndex: 0, publicationDigest: digestOf(publication.data), objectives: ['movement_control'], levels: ['beginner']}]};
}
function changePublication(source: ContentCandidateSource, edit: (data: Record<string, unknown>) => void): ContentCandidateSource {
  const copy = structuredClone(source); edit(copy.publications[0].data);
  (copy.suitability[0] as {publicationDigest: string}).publicationDigest = digestOf(copy.publications[0].data);
  return copy;
}
it('admits an exact published instructional exercise with actual Member destination and unknown optional metadata', () => {
  const result = evaluateContentCandidates(query, fixture());
  expect(result.status).toBe('available'); expect(result.contentGap).toBe('none');
  expect(result.candidates).toHaveLength(1);
  expect(result.candidates[0]).toMatchObject({organizationId: 'synthetic_org', exerciseId: 'squat', eligibilityClass: 'exact_exercise',
    objective: 'movement_control', level: 'beginner', destination: {kind: 'published_routine_exercise_tutorial',
      organizationId: 'synthetic_org', routineId: 'routine_synthetic', exerciseIndex: 0, exerciseId: 'squat', dayNumber: 1},
    evidence: {instruction: 'steps', difficulty: null, equipment: null, exerciseDurationMinutes: null,
      routineEstimatedMinutes: 10, compatibilityMappingId: null, curationVersion: 'synthetic-curation-v1'}});
  expect(result.candidates[0].candidateId).toMatch(/^content_[a-f0-9]{32}$/);
  expect(JSON.stringify(result)).not.toContain('https://');
});
it('does not infer compatibility from shared category; requires explicit curated directed mapping', () => {
  const source = changePublication(fixture(), d => {(d.exercises as Record<string, unknown>[])[0].exerciseId = 'wall_squat';});
  expect(evaluateContentCandidates(query, source).candidates).toEqual([]);
  expect(evaluateContentCandidates(query, source).rejected).toContainEqual({publicationId: 'routine_synthetic', exerciseIndex: 0, reason: 'exercise_not_compatible'});
  const compatible = {...source, compatibleExercises: [{id: 'synthetic_compatible', fromExerciseId: 'squat', toExerciseId: 'wall_squat'}]};
  expect(evaluateContentCandidates(query, compatible).candidates[0]).toMatchObject({eligibilityClass: 'curated_compatible',
    evidence: {compatibilityMappingId: 'synthetic_compatible'}});
  expect(evaluateContentCandidates({...query, exerciseId: 'wall_squat'}, fixture()).candidates).toEqual([]);
});
it.each(['inactive', 'archived', 'missing'] as const)('rejects %s requested catalog exercise', mode => {
  const source = fixture();
  const catalog = mode === 'missing' ? source.catalog.slice(1) : source.catalog.map((r, i) => i ? r : {...r,
    data: {...r.data, ...(mode === 'archived' ? {archived: true} : {isActive: false})}});
  const result = evaluateContentCandidates(query, {...source, catalog});
  expect(result).toMatchObject({status: 'no_candidate', contentGap: 'no_eligible_published_instruction', candidates: []});
  expect(result.rejected.some(r => r.reason === 'catalog_unavailable')).toBe(true);
});
it.each(['draft', 'archived'])('rejects %s publications', status => {
  const result = evaluateContentCandidates(query, changePublication(fixture(), d => {d.status = status;}));
  expect(result.candidates).toEqual([]); expect(result.rejected[0].reason).toBe('publication_unavailable');
});
it('rejects archived published records and active=false records', () => {
  for (const field of [{archived: true}, {isActive: false}]) {
    expect(evaluateContentCandidates(query, changePublication(fixture(), d => Object.assign(d, field))).candidates).toEqual([]);
  }
});
it('requires an active target catalog record even for curated compatibility', () => {
  let source = changePublication(fixture(), d => {(d.exercises as Record<string, unknown>[])[0].exerciseId = 'wall_squat';});
  source = {...source, compatibleExercises: [{id: 'mapping', fromExerciseId: 'squat', toExerciseId: 'wall_squat'}],
    catalog: source.catalog.map(r => r.id === 'wall_squat' ? {...r, data: {...r.data, archived: true}} : r)};
  expect(evaluateContentCandidates(query, source).rejected[0].reason).toBe('catalog_unavailable');
});
it('rejects images and text descriptions without instructional steps or valid direct video', () => {
  const source = changePublication(fixture(), d => {Object.assign((d.exercises as Record<string, unknown>[])[0],
    {tutorialSteps: [], description: 'Overview', coverImageUrl: 'https://example.invalid/cover.jpg', videoUrl: 'https://example.invalid/cover.jpg'});});
  expect(evaluateContentCandidates(query, source).rejected[0].reason).toBe('instruction_missing');
});
it('accepts only a supplied valid video and reuses projection validation for malformed steps', () => {
  const video = changePublication(fixture(), d => {const e = (d.exercises as Record<string, unknown>[])[0]; delete e.tutorialSteps;
    e.videoUrl = 'https://example.invalid/synthetic.mp4'; e.equipment = 'Mat'; e.difficulty = 'Beginner';});
  expect(evaluateContentCandidates(query, video).candidates[0].evidence).toMatchObject({instruction: 'video', equipment: 'Mat', difficulty: 'beginner'});
  const invalid = changePublication(video, d => {(d.exercises as Record<string, unknown>[])[0].tutorialSteps = [{title: 'Missing description'}];});
  expect(evaluateContentCandidates(query, invalid).rejected[0].reason).toBe('invalid_instruction');
});
it.each(['sets', 'reps', 'dayNumber'] as const)('rejects malformed %s navigation/exercise essentials', field => {
  const source = changePublication(fixture(), d => {(d.exercises as Record<string, unknown>[])[0][field] = 0;});
  expect(evaluateContentCandidates(query, source).rejected[0].reason).toBe('invalid_publication');
});
it('does not infer suitability from catalog labels, published difficulty or arbitrary goal text', () => {
  const source = fixture();
  expect(evaluateContentCandidates(query, {...source, suitability: []}).rejected[0].reason).toBe('suitability_unknown');
  expect(evaluateContentCandidates({...query, objective: 'endurance'}, source).rejected[0].reason).toBe('objective_not_supported');
  expect(evaluateContentCandidates({...query, level: 'advanced'}, source).rejected[0].reason).toBe('level_not_supported');
});
it('binds curation to publication content so stale suitability fails closed', () => {
  const source = fixture(); source.publications[0].data.title = 'Changed instructions';
  expect(evaluateContentCandidates(query, source).rejected[0].reason).toBe('suitability_stale');
});
it('produces deterministic IDs/order with exact exercise protected before compatible alternatives', () => {
  const source = fixture();
  const alt = changePublication(fixture(), d => {(d.exercises as Record<string, unknown>[])[0].exerciseId = 'wall_squat';});
  const publication = {...alt.publications[0], id: 'a_compatible'};
  const combined = {...source, publications: [publication, ...source.publications],
    suitability: [{...alt.suitability[0], id: 'alt_mapping', publicationId: 'a_compatible'}, ...source.suitability],
    compatibleExercises: [{id: 'compatible', fromExerciseId: 'squat', toExerciseId: 'wall_squat'}]};
  const first = evaluateContentCandidates(query, combined);
  expect(first.candidates.map(c => c.eligibilityClass)).toEqual(['exact_exercise', 'curated_compatible']);
  const second = evaluateContentCandidates(query, {...combined, publications: [...combined.publications].reverse()});
  expect(second).toEqual(first);
});
it('returns explicit no candidate/content gap for an empty library', () => {
  expect(evaluateContentCandidates(query, {...fixture(), publications: [], suitability: []})).toMatchObject({status: 'no_candidate',
    contentGap: 'no_eligible_published_instruction', candidates: []});
});
it('rejects foreign source scopes without partial output', () => {
  expect(() => evaluateContentCandidates(query, {...fixture(), organizationId: 'foreign'})).toThrow();
  const source = fixture(); source.catalog[0].data.organizationId = 'foreign';
  expect(() => evaluateContentCandidates(query, source)).toThrow();
});
it.each([{objective: 'weight_loss'}, {objective: 'rehabilitation'}, {level: 'expert'}, {exerciseId: '../private'}])('rejects unsupported query %j', changes => {
  expect(() => evaluateContentCandidates({...query, ...changes} as ContentCandidateQuery, fixture())).toThrow();
});
it('bounds source size and rejects duplicate source identities and ambiguous curated mappings', () => {
  const source = fixture();
  expect(() => evaluateContentCandidates(query, {...source, catalog: Array.from({length: 1001}, (_, i) => ({...source.catalog[0], id: `e${i}`}))})).toThrow();
  expect(() => evaluateContentCandidates(query, {...source, publications: Array(501).fill(source.publications[0])})).toThrow();
  expect(() => evaluateContentCandidates(query, {...source, publications: [...source.publications, ...source.publications]})).toThrow();
  expect(() => evaluateContentCandidates(query, {...source, suitability: [...source.suitability, {...source.suitability[0], id: 'ambiguous'}]})).toThrow();
  expect(() => evaluateContentCandidates(query, {...source, compatibleExercises: [{id: 'a', fromExerciseId: 'squat', toExerciseId: 'wall_squat'},
    {id: 'b', fromExerciseId: 'squat', toExerciseId: 'wall_squat'}]})).toThrow();
});
it('sanitizes unsupported source failures rather than echoing private text', () => {
  const source = fixture(); source.catalog[0].data.exerciseName = 'x'.repeat(17 * 1024 * 1024);
  expect(() => evaluateContentCandidates(query, source)).toThrow('Content candidate source is unavailable.');
});
