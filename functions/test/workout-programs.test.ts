import {beforeEach, expect, it, vi} from 'vitest';
import {workoutPrograms} from '../src/modules/content/workout-programs';
import {MemoryStore} from './memory-store';

const org = 'gainpath', now = 1800000000000;
const admin = {uid: 'admin', token: {email_verified: true, email: 'admin@example.test', auth_time: now / 1000}};
const member = {...admin, uid: 'member'};
const p = (collection: string, id: string) => `orgs/${org}/${collection}/${id}`;
const routine = () => ({schemaVersion: 1, kind: 'routine', status: 'published', sourceBlueprintId: 'basic', title: 'Real full body', estimatedMinutes: 20,
  exercises: [{exerciseId: 'squat', name: 'Squat', category: 'Legs', muscleGroup: 'Legs', sets: 2, reps: 8, dayNumber: 1},
    {exerciseId: 'manual-row', name: 'Manual row', category: 'Back', muscleGroup: 'Back', sets: 3, reps: 10, dayNumber: 2}]});
function program(): Record<string, any> {
  return {schemaVersion: 1, id: 'beginner', version: 0, title: 'Beginner four weeks', level: 'Beginner', weeks: 4,
    days: Array.from({length: 28}, (_, i) => {
      const workout = [1, 3, 5].includes(i % 7 + 1);
      return {week: Math.floor(i / 7) + 1, weekday: i % 7 + 1, kind: workout ? 'workout' : 'rest', category: workout ? 'Full Body' : 'Rest',
        routineId: workout ? 'routine_basic' : null, routineDay: 1, muscleGroups: workout ? ['upperPush', 'upperPull', 'lower'] : [], restSeconds: 75};
    })};
}
let store: MemoryStore, freshAuth: ReturnType<typeof vi.fn>;
const command = (action: string, fields = {}, who = admin) => workoutPrograms(store, who, {schemaVersion: 1, organizationId: org, action, ...fields}, {freshAuth, clock: () => now});
const save = (fields = {}, who = admin) => command('saveDraft', {requestId: 'save1', expectedRevision: 0, program: program(), ...fields}, who);
const publish = (fields = {}) => command('publish', {requestId: 'publish1', programId: 'beginner', expectedRevision: 1, ...fields});
beforeEach(() => {
  store = new MemoryStore(); freshAuth = vi.fn(async () => undefined);
  store.documents.set(`orgs/${org}`, {status: 'active'});
  for (const [uid, role] of [['admin', 'admin'], ['member', 'member'], ['staff', 'staff']]) {
    store.documents.set(`users/${uid}`, {organizationId: org, role});
    store.documents.set(p('members', uid), {organizationId: org, userId: uid, role, status: 'active', branchIds: []});
  }
  store.documents.set(p('content', 'routine_basic'), routine());
});

it('returns empty lists before setup without seeding content or policies', async () => {
  const before = structuredClone([...store.documents]);
  expect(await command('list', {}, member)).toEqual({programs: [], drafts: []});
  expect([...store.documents]).toEqual(before);
  expect(freshAuth).toHaveBeenCalledTimes(2);
});

it.each(['admin', 'staff'])('supports canonical %s membership when the legacy global role is absent', async uid => {
  delete store.documents.get(`users/${uid}`)!.role;
  const actor = {...admin, uid};
  await expect(save({}, actor)).resolves.toEqual({revision: 1});
  await expect(command('publish', {requestId: 'publish-legacy', programId: 'beginner', expectedRevision: 1}, actor))
    .resolves.toMatchObject({revision: 2, program: {version: 1}});
});
it('supports legacy Member discovery without granting authoring authority', async () => {
  delete store.documents.get('users/member')!.role;
  await expect(command('list', {}, member)).resolves.toEqual({programs: [], drafts: []});
  await expect(command('adminList', {}, member)).rejects.toMatchObject({code: 'permission-denied'});
  await expect(save({}, member)).rejects.toMatchObject({code: 'permission-denied'});
});
it.each(['member', 'coach', null])('still rejects conflicting explicit global Admin role %s', async role => {
  store.documents.get('users/admin')!.role = role;
  await expect(command('adminList')).rejects.toMatchObject({code: 'permission-denied'});
  await expect(save()).rejects.toMatchObject({code: 'permission-denied'});
});
it('saves a draft then publishes a version with only real selected routine-day targets and rest', async () => {
  expect(await save()).toEqual({revision: 1});
  const result = await publish();
  expect(result.revision).toBe(2);
  expect(result.program).toMatchObject({id: 'beginner', version: 1, weeks: 4});
  expect(result.program.days[0].routineSnapshot.exercises).toEqual([{...routine().exercises[0], restSeconds: 75}]);
  expect(result.program.days[1]).not.toHaveProperty('routineSnapshot');
  const listing = await command('list', {}, member);
  expect(listing.programs).toEqual([result.program]); expect(listing.drafts).toEqual([]);
  expect(JSON.stringify(listing)).not.toContain('updatedBy');
  const adminListing = await command('adminList');
  expect(adminListing.drafts).toEqual([{program: program(), revision: 2}]);
});
it('preserves published versions after editing source routine and publishing the next version', async () => {
  await save(); const first = await publish();
  const prior = structuredClone(store.documents.get(p('workoutProgramVersions', 'beginner_v1')));
  store.documents.get(p('content', 'routine_basic'))!.title = 'Later title';
  store.documents.get(p('content', 'routine_basic'))!.exercises = [{...routine().exercises[0], reps: 15}];
  await save({expectedRevision: 2, requestId: 'save2'});
  const second = await publish({expectedRevision: 3, requestId: 'publish2'});
  expect(second.program.version).toBe(2);
  expect(first.program.days[0].routineSnapshot.exercises[0].reps).toBe(8);
  expect(second.program.days[0].routineSnapshot.exercises[0].reps).toBe(15);
  expect(store.documents.get(p('workoutProgramVersions', 'beginner_v1'))).toEqual(prior);
});
it('serializes retries and returns the original publish result after later draft edits', async () => {
  expect(await Promise.all([save(), save()])).toEqual([{revision: 1}, {revision: 1}]);
  const first = await publish();
  await save({expectedRevision: 2, requestId: 'save2'});
  expect(await publish()).toEqual(first);
});
it('rejects stale revisions and reused request IDs with different commands', async () => {
  await save();
  await expect(save({requestId: 'save2'})).rejects.toMatchObject({code: 'aborted'});
  await expect(save({expectedRevision: 1})).rejects.toMatchObject({code: 'already-exists'});
});
it.each(['saveDraft', 'publish', 'adminList'])('denies Member %s authority', async action => {
  await expect(command(action, action === 'saveDraft' ? {requestId: 'save1', expectedRevision: 0, program: program()} : action === 'publish' ? {requestId: 'p1', programId: 'beginner', expectedRevision: 0} : {}, member)).rejects.toMatchObject({code: 'permission-denied'});
});
it('allows active canonical Staff to author while refusing noncanonical claims', async () => {
  expect(await save({}, {...admin, uid: 'staff'})).toEqual({revision: 1});
  store.documents.get('users/staff')!.role = 'member';
  await expect(command('adminList', {}, {...admin, uid: 'staff'})).rejects.toMatchObject({code: 'permission-denied'});
});
it.each(['missing-user', 'inactive-member', 'foreign-member', 'inactive-org', 'lifecycle', 'stale-session'])('fails closed on %s', async mode => {
  if (mode === 'missing-user') store.documents.delete('users/member');
  if (mode === 'inactive-member') store.documents.get(p('members', 'member'))!.status = 'inactive';
  if (mode === 'foreign-member') store.documents.get(p('members', 'member'))!.organizationId = 'foreign';
  if (mode === 'inactive-org') store.documents.get(`orgs/${org}`)!.status = 'inactive';
  if (mode === 'lifecycle') store.documents.get('users/member')!.accountLifecycle = {schemaVersion: 1, state: 'deactivating', revocationPending: true, sessionNotBeforeSeconds: 0};
  if (mode === 'stale-session') store.documents.get('users/member')!.accountLifecycle = {schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: now / 1000 + 1};
  await expect(command('list', {}, member)).rejects.toMatchObject({code: 'permission-denied'});
});
it('rechecks fresh Auth and canonical authority before disclosing any result', async () => {
  freshAuth.mockImplementationOnce(async () => undefined).mockImplementationOnce(async () => {store.documents.get(p('members', 'member'))!.status = 'inactive';});
  await expect(command('list', {}, member)).rejects.toMatchObject({code: 'permission-denied'});
});
it('requires verified Auth and never consults data for malformed input', async () => {
  await expect(workoutPrograms(store, undefined, {}, {freshAuth})).rejects.toMatchObject({code: 'unauthenticated'});
  await expect(command('list', {}, {...member, token: {...member.token, email_verified: false}})).rejects.toMatchObject({code: 'permission-denied'});
  await expect(command('list', {points: 100})).rejects.toHaveProperty('name', 'InputValidationError');
});
it.each(['missing-day', 'duplicate-day', 'invalid-level', 'rest-target', 'recovery-target', 'fake-snapshot', 'bad-rest', 'unknown-field', 'missing-muscle', 'extra-muscle', 'consecutive-muscle'])('rejects unsafe draft %s', async mode => {
  const value = program();
  if (mode === 'missing-day') value.days.pop();
  if (mode === 'duplicate-day') value.days[1] = {...value.days[0]};
  if (mode === 'invalid-level') value.level = 'Expert';
  if (mode === 'rest-target') value.days[1].routineId = 'routine_basic';
  if (mode === 'recovery-target') value.days[1] = {...value.days[1], kind: 'activeRecovery', category: 'Active Recovery', routineId: 'routine_basic'};
  if (mode === 'fake-snapshot') value.days[0].routineSnapshot = routine();
  if (mode === 'bad-rest') value.days[0].restSeconds = 601;
  if (mode === 'unknown-field') value.days[0].aiSupported = true;
  if (mode === 'missing-muscle') value.days[0].muscleGroups = [];
  if (mode === 'extra-muscle') value.days[0] = {...value.days[0], category: 'Push'};
  if (mode === 'consecutive-muscle') value.days[1] = {...value.days[0], weekday: 2};
  await expect(save({program: value})).rejects.toHaveProperty('name', 'InputValidationError');
});
it('permits unassigned draft workout days but refuses publication until assigned', async () => {
  const value = program(); value.days[0].routineId = null;
  await save({program: value});
  await expect(publish()).rejects.toMatchObject({code: 'failed-precondition'});
});
it.each(['missing', 'unpublished', 'missing-day', 'bad-target', 'huge-content'])('refuses %s routine references without changing versions', async mode => {
  await save();
  const source = store.documents.get(p('content', 'routine_basic'))!;
  if (mode === 'missing') store.documents.delete(p('content', 'routine_basic'));
  if (mode === 'unpublished') source.status = 'draft';
  if (mode === 'missing-day') source.exercises = [routine().exercises[1]];
  if (mode === 'bad-target') (source.exercises as any[])[0].sets = 0;
  if (mode === 'huge-content') (source.exercises as any[])[0].cue = 'x'.repeat(800000);
  await expect(publish()).rejects.toMatchObject({code: 'failed-precondition'});
  expect(store.documents.has(p('workoutProgramVersions', 'beginner_v1'))).toBe(false);
});
it('refuses missing/corrupt indexed records instead of returning partial lists', async () => {
  await save(); await publish();
  store.documents.delete(p('workoutProgramVersions', 'beginner_v1'));
  await expect(command('list', {}, member)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('checks recovery across the boundary between Program weeks', async () => {
  const value = program(); value.days[6] = {...value.days[0], weekday: 7};
  await expect(save({program: value})).rejects.toHaveProperty('name', 'InputValidationError');
});
it('projects only public routine fields and refuses corrupt optional tutorial metadata', async () => {
  store.documents.get(p('content', 'routine_basic'))!.privateOwnerEmail = 'private@example.test';
  await save();
  const first = await publish();
  expect(JSON.stringify(first)).not.toContain('privateOwnerEmail');
  store.documents.get(p('content', 'routine_basic'))!.exercises = [{...routine().exercises[0], description: {private: 'secret'}}];
  await save({expectedRevision: 2, requestId: 'save2'});
  await expect(publish({expectedRevision: 3, requestId: 'publish2'})).rejects.toMatchObject({code: 'failed-precondition'});
});
it('fails closed when a stored published exercise target is corrupted', async () => {
  await save(); await publish();
  (store.documents.get(p('workoutProgramVersions', 'beginner_v1'))!.program as any).days[0].routineSnapshot.exercises[0].sets = -1;
  await expect(command('list', {}, member)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('refuses a full or malformed catalog rather than dropping Programs', async () => {
  store.documents.set(p('workoutProgramCatalog', 'index'), {schemaVersion: 1, organizationId: org,
    entries: Array.from({length: 40}, (_, i) => ({id: `old${i}`, revision: 1, version: 0}))});
  await expect(save()).rejects.toMatchObject({code: 'resource-exhausted'});
  store.documents.get(p('workoutProgramCatalog', 'index'))!.entries = [{id: '../escape', revision: 1, version: 0}];
  await expect(command('list', {}, member)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('permits unfinished draft weeks but refuses publishing an unusable training-day count', async () => {
  const value = program(); value.days[0] = {...value.days[1], weekday: 1};
  await save({program: value});
  await expect(publish()).rejects.toMatchObject({code: 'failed-precondition'});
});
function pushPullProgram(crossWeek = false): Record<string, any> {
  const value = program();
  for (const day of value.days) {
    const category = crossWeek ? ({1: 'Pull', 3: 'Full Body', 7: 'Push'} as Record<number, string>)[day.weekday]
      : ({1: 'Push', 2: 'Pull', 5: 'Full Body'} as Record<number, string>)[day.weekday];
    day.kind = category ? 'workout' : 'rest'; day.category = category ?? 'Rest'; day.routineId = category ? 'routine_basic' : null;
    day.muscleGroups = category === 'Push' ? ['upperPush'] : category === 'Pull' ? ['upperPull'] : category === 'Full Body' ? ['upperPush', 'upperPull', 'lower'] : [];
  }
  return value;
}
function genericUpperRoutine(exerciseId = 'manual-upper') {
  return {...routine(), exercises: [{...routine().exercises[0], exerciseId, category: 'Compound Upper-Body', muscleGroup: 'Upper Body'}]};
}
it.each([false, true])('rejects the same exercise on adjacent disjoint-category days, crossWeek=%s', async crossWeek => {
  store.documents.set(p('content', 'routine_basic'), genericUpperRoutine());
  await save({program: pushPullProgram(crossWeek)});
  await expect(publish()).rejects.toMatchObject({code: 'failed-precondition'});
  expect(store.documents.has(p('workoutProgramVersions', 'beginner_v1'))).toBe(false);
});
it('leaves Push/Pull distinction to Admin for broad upper-body metadata with different exercises', async () => {
  const value = pushPullProgram();
  for (const day of value.days) if (day.category === 'Pull') day.routineId = 'routine_pull';
  store.documents.set(p('content', 'routine_basic'), genericUpperRoutine('manual-press'));
  store.documents.set(p('content', 'routine_pull'), genericUpperRoutine('manual-row'));
  await save({program: value});
  const result = await publish();
  expect(result.program.version).toBe(1);
  const snapshot = store.documents.get(p('workoutProgramVersions', 'beginner_v1'))!.program as any;
  snapshot.days[1].routineSnapshot.exercises[0].exerciseId = 'manual-press';
  await expect(command('list', {}, member)).rejects.toMatchObject({code: 'failed-precondition'});
});
it.each([
  ['Push', 'Lower Body', ['upperPush']], ['Pull', 'Legs', ['upperPull']], ['Upper Body', 'Quads', ['upperPush', 'upperPull']],
  ['Push', 'Glutes', ['upperPush']], ['Pull', 'Calves', ['upperPull']], ['Upper Body', 'Hamstrings', ['upperPush', 'upperPull']],
  ['Lower Body', 'Chest', ['lower']], ['Legs', 'Compound Upper-Body', ['lower']],
])('rejects clear category mismatch %s with routine muscle metadata %s', async (category, muscleGroup, muscleGroups) => {
  const value = program();
  for (const day of value.days) if (day.kind === 'workout') {day.category = category; day.muscleGroups = muscleGroups;}
  store.documents.set(p('content', 'routine_basic'), {...routine(), exercises: [{...routine().exercises[0], category: muscleGroup, muscleGroup}]});
  await save({program: value});
  await expect(publish()).rejects.toMatchObject({code: 'failed-precondition'});
});
