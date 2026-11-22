import {expect, test} from 'vitest';
import {readPublishedRoutineCovers} from '../src/modules/recommendation/published-routine-covers';
import {MemoryStore} from './memory-store';

test('only resolves routine-owned artwork for current publications in the member organization', async () => {
  const store = new MemoryStore();
  const published = {kind: 'routine_v2', status: 'published', sourceBlueprintId: 'template'};
  const explicit = 'https://cdn.example.com/published.png';
  const template = 'https://cdn.example.com/template.png';
  store.documents.set('orgs/a/routineBlueprintsV2/template', {imageUrl: template});
  store.documents.set('orgs/a/content/explicit', {...published, coverImageUrl: explicit});
  store.documents.set('orgs/a/content/linked', published);
  store.documents.set('orgs/a/content/archived', {...published, archived: true});
  store.documents.set('orgs/b/content/other', {...published, coverImageUrl: explicit});
  store.documents.set('orgs/a/content/exercise_only', {kind: 'routine', status: 'published',
    exercises: [{imageUrl: 'https://cdn.example.com/exercise.png'}]});

  const result = await store.transact(tx => readPublishedRoutineCovers(tx, 'a', {
    schemaVersion: 1, organizationId: 'a',
    routineIds: ['explicit', 'linked', 'archived', 'exercise_only', 'other'],
  }));
  expect(result).toEqual({explicit, linked: template});
});
