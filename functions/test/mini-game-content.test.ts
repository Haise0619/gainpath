import {beforeEach, expect, it, vi} from 'vitest';
import {miniGameContent, type MiniGameMediaStore} from '../src/modules/content/mini-game-content';
import {MemoryStore} from './memory-store';

const org = 'gainpath', gameId = 'move-catch-v1', now = 1800000000000;
const admin = {uid: 'admin', token: {email_verified: true, email: 'admin@example.test', auth_time: now / 1000}};
const member = {...admin, uid: 'member'};
const path = (collection: string, id: string) => `orgs/${org}/${collection}/${id}`;
const content = {title: 'Move & Catch', introduction: 'A custom introduction.', instructions: ['Stand comfortably.'], coverUrl: '', previewVideoUrl: ''};
const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]);
const mp4 = Buffer.from([0, 0, 0, 24, 102, 116, 121, 112, 105, 115, 111, 109, 0, 0, 0, 0, 105, 115, 111, 109, 109, 112, 52, 50]);
let store: MemoryStore, freshAuth: ReturnType<typeof vi.fn>, media: MiniGameMediaStore;
const command = (action: string, fields = {}, who = admin) => miniGameContent(store, who, {schemaVersion: 1, organizationId: org, action, ...fields}, {media, freshAuth, clock: () => now});
const save = (fields = {}, who = admin) => command('save', {gameId, requestId: 'a'.repeat(32), baseRevision: 0, ...content, ...fields}, who);
const upload = (fields = {}, who = admin) => command('uploadMedia', {gameId, kind: 'cover', uploadId: 'b'.repeat(32), contentType: 'image/png', dataBase64: png.toString('base64'), ...fields}, who);
beforeEach(() => {
  store = new MemoryStore();
  store.documents.set(`orgs/${org}`, {status: 'active'});
  for (const [uid, role] of [['member', 'member'], ['admin', 'admin']]) {
    store.documents.set(`users/${uid}`, {organizationId: org, role});
    store.documents.set(path('members', uid), {organizationId: org, userId: uid, role, status: 'active', branchIds: []});
  }
  freshAuth = vi.fn(async () => undefined);
  media = {upload: vi.fn(async (objectPath: string) => `https://firebasestorage.googleapis.com/v0/b/gainpath-0619.firebasestorage.app/o/${encodeURIComponent(objectPath)}?alt=media&token=12345678-1234-1234-1234-123456789abc`)};
});

it('returns the real supported built-in guide at revision zero without any writes', async () => {
  const before = structuredClone([...store.documents]);
  expect(await command('list', {}, member)).toEqual({schemaVersion: 1, organizationId: org, games: [{schemaVersion: 1, organizationId: org, gameId, revision: 0,
    title: 'Move & Catch', introduction: 'Lean left and right to catch stars and avoid obstacles in a 40-second round.',
    instructions: ['Face the camera with your shoulders and hips visible.', 'Hold your starting position for calibration, then start the round.', 'Lean gently to catch stars and avoid diamonds. Return into view during the tracking warning.'],
    coverUrl: '', previewVideoUrl: '', updatedAtMillis: 0}]});
  expect([...store.documents]).toEqual(before);
  expect(freshAuth).toHaveBeenCalledTimes(2);
});
it('negotiates exact supported games in canonical order without seeding content', async () => {
  const before = structuredClone([...store.documents]);
  const result = await command('list', {supportedGameIds: ['reach-tap-v1', gameId]}, member);
  expect(result.games.map((game: any) => game.gameId)).toEqual([gameId, 'reach-tap-v1']);
  expect(result.games[1]).toMatchObject({title: 'Reach & Tap', revision: 0});
  expect([...store.documents]).toEqual(before);
});
it.each([[], [gameId, gameId], ['invented'], [gameId, 'reach-tap-v1', 'invented'], 'reach-tap-v1', null])('rejects invalid registry negotiation %j', async supportedGameIds => {
  await expect(command('list', {supportedGameIds})).rejects.toHaveProperty('name', 'InputValidationError');
});
it('saves Reach & Tap independently and rejects cross-game request reuse', async () => {
  const first = await save({gameId: 'reach-tap-v1', title: 'Reach guide'});
  expect(first.game).toMatchObject({gameId: 'reach-tap-v1', revision: 1});
  expect(await save({gameId: 'reach-tap-v1', title: 'Reach guide'})).toEqual(first);
  await expect(save()).rejects.toMatchObject({code: 'already-exists'});
  expect(store.documents.has(path('miniGameContent', gameId))).toBe(false);
});
it('isolates media receipts and object paths by game', async () => {
  const cover = await upload({gameId: 'reach-tap-v1'});
  expect(cover.gameId).toBe('reach-tap-v1');
  expect(media.upload).toHaveBeenCalledWith(expect.stringContaining('/reach-tap-v1/cover/'), png, 'image/png', expect.any(String));
  await expect(save({coverUrl: cover.url})).rejects.toMatchObject({code: 'permission-denied'});
  expect(await save({gameId: 'reach-tap-v1', coverUrl: cover.url})).toMatchObject({game: {gameId: 'reach-tap-v1', coverUrl: cover.url}});
});
it('rejects an upload adapter returning media for another game', async () => {
  const old = await upload();
  media.upload = vi.fn(async () => old.url);
  await expect(upload({gameId: 'reach-tap-v1'})).rejects.toMatchObject({code: 'failed-precondition'});
  expect([...store.documents.values()].filter(value => value.gameId === 'reach-tap-v1')).toHaveLength(0);
});
it('rejects stored media scoped to another game when listing', async () => {
  const old = await upload();
  await save({gameId: 'reach-tap-v1'});
  store.documents.get(path('miniGameContent', 'reach-tap-v1'))!.coverUrl = old.url;
  await expect(command('list', {supportedGameIds: ['reach-tap-v1']})).rejects.toMatchObject({code: 'failed-precondition'});
});
it('does not permit negotiation fields on writes or swapped stored identities', async () => {
  await expect(save({supportedGameIds: [gameId]})).rejects.toHaveProperty('name', 'InputValidationError');
  await save({gameId: 'reach-tap-v1'});
  store.documents.get(path('miniGameContent', 'reach-tap-v1'))!.gameId = gameId;
  await expect(command('list', {supportedGameIds: ['reach-tap-v1']})).rejects.toMatchObject({code: 'failed-precondition'});
});
it.each([['move-catch-v1'], ['reach-tap-v1'], null, 1, {}])('rejects non-string game identity %j', async gameId => {
  await expect(save({gameId})).rejects.toHaveProperty('name', 'InputValidationError');
  await expect(upload({gameId})).rejects.toHaveProperty('name', 'InputValidationError');
  expect(media.upload).not.toHaveBeenCalled();
});
it('saves an override and projects only public fields to Members', async () => {
  expect(await save()).toMatchObject({schemaVersion: 1, organizationId: org, confirmed: true, game: {...content, gameId, revision: 1, updatedAtMillis: now}});
  expect(store.documents.get(path('miniGameContent', gameId))).toMatchObject({updatedBy: admin.uid});
  const result = await command('list', {}, member);
  expect(result.games[0]).toMatchObject({...content, revision: 1});
  expect(result.games[0]).not.toHaveProperty('updatedBy');
  expect(result.games[0]).not.toHaveProperty('requestId');
});
it('serializes concurrent saves and recovers the original confirmed retry after later edits', async () => {
  const [first, retry] = await Promise.all([save(), save()]);
  expect(retry).toEqual(first);
  await save({baseRevision: 1, requestId: 'c'.repeat(32), title: 'Edited title'});
  expect(await save()).toEqual(first);
  expect(store.documents.get(path('miniGameContent', gameId))?.revision).toBe(2);
});
it('rejects reused request IDs with different content or base revisions', async () => {
  await save();
  await expect(save({title: 'Changed'})).rejects.toMatchObject({code: 'already-exists'});
  await expect(save({baseRevision: 1})).rejects.toMatchObject({code: 'already-exists'});
});
it('requires the current revision and leaves existing content unchanged on conflicts', async () => {
  await save();
  await expect(save({requestId: 'c'.repeat(32)})).rejects.toMatchObject({code: 'aborted'});
  expect(store.documents.get(path('miniGameContent', gameId))?.revision).toBe(1);
});
it.each(['save', 'uploadMedia'])('rejects Member %s authority', async action => {
  await expect(action === 'save' ? save({}, member) : upload({}, member)).rejects.toMatchObject({code: 'permission-denied'});
  expect(media.upload).not.toHaveBeenCalled();
});
it.each(['missing-user', 'wrong-user-org', 'wrong-user-role', 'inactive-org', 'inactive-member', 'wrong-member-org', 'wrong-member-id', 'lifecycle', 'stale-session', 'coach'])('rejects canonical authority failure %s', async mode => {
  const user = store.documents.get('users/member')!, membership = store.documents.get(path('members', 'member'))!;
  if (mode === 'missing-user') store.documents.delete('users/member');
  if (mode === 'wrong-user-org') user.organizationId = 'other';
  if (mode === 'wrong-user-role') user.role = 'admin';
  if (mode === 'inactive-org') store.documents.get(`orgs/${org}`)!.status = 'inactive';
  if (mode === 'inactive-member') membership.status = 'inactive';
  if (mode === 'wrong-member-org') membership.organizationId = 'other';
  if (mode === 'wrong-member-id') membership.userId = 'other';
  if (mode === 'lifecycle') user.accountLifecycle = {schemaVersion: 1, state: 'active', revocationPending: true, sessionNotBeforeSeconds: 0};
  if (mode === 'stale-session') user.accountLifecycle = {schemaVersion: 1, state: 'active', revocationPending: false, sessionNotBeforeSeconds: now / 1000 + 1};
  if (mode === 'coach') {user.role = 'coach'; membership.role = 'coach';}
  await expect(command('list', {}, member)).rejects.toMatchObject({code: 'permission-denied'});
});
it('requires verified Auth and fresh identity', async () => {
  await expect(miniGameContent(store, undefined, {}, {media, freshAuth})).rejects.toMatchObject({code: 'unauthenticated'});
  await expect(command('list', {}, {...member, token: {...member.token, email_verified: false}})).rejects.toMatchObject({code: 'permission-denied'});
  freshAuth.mockRejectedValueOnce(Object.assign(new Error(), {code: 'unauthenticated'}));
  await expect(command('list')).rejects.toMatchObject({code: 'unauthenticated'});
});
it('checks fresh identity and canonical authority again before returning a read', async () => {
  freshAuth.mockImplementationOnce(async () => undefined).mockImplementationOnce(async () => {store.documents.get(path('members', 'member'))!.status = 'inactive';});
  await expect(command('list', {}, member)).rejects.toMatchObject({code: 'permission-denied'});
});
it.each([{gameId: 'invented'}, {requestId: 'not-hex'}, {baseRevision: -1}, {baseRevision: 0.5}, {title: ''}, {title: 'x'.repeat(81)}, {introduction: ' '}, {introduction: 'x'.repeat(2001)}, {instructions: []}, {instructions: Array(9).fill('x')}, {instructions: ['x'.repeat(501)]}, {instructions: [1]}, {instructions: [' ']}, {points: 50}, {durationSeconds: 80}, {enabled: false}, {coverUrl: null}, {previewVideoUrl: 2}])('rejects invalid save payload %j', async fields => {
  await expect(save(fields)).rejects.toHaveProperty('name', 'InputValidationError');
  expect(store.documents.has(path('miniGameContent', gameId))).toBe(false);
});
it.each(['create', 'delete', 'engine', 'award'])('does not expose %s actions', async action => {
  await expect(command(action)).rejects.toHaveProperty('name', 'InputValidationError');
});
it('accepts exact maximum text lengths without altering the strings', async () => {
  const fields = {title: 'x'.repeat(80), introduction: 'x'.repeat(2000), instructions: Array(8).fill('x'.repeat(500))};
  expect(await save(fields)).toMatchObject({game: fields});
});
const prohibitedControls = [...Array.from({length: 9}, (_, i) => i), 11, 12, ...Array.from({length: 18}, (_, i) => i + 14), 127];
it.each(['title', 'introduction', 'instructions'])('rejects prohibited control characters in saved %s', async field => {
  for (const code of prohibitedControls) {
    const value = `Move${String.fromCharCode(code)}Catch`;
    await expect(save({[field]: field === 'instructions' ? [value] : value})).rejects.toHaveProperty('name', 'InputValidationError');
  }
  expect(store.documents.has(path('miniGameContent', gameId))).toBe(false);
});
it.each(['title', 'introduction', 'instructions'])('rejects prohibited control characters when reading stored %s', async field => {
  await save();
  for (const code of prohibitedControls) {
    const value = `Move${String.fromCharCode(code)}Catch`;
    store.documents.get(path('miniGameContent', gameId))![field] = field === 'instructions' ? [value] : value;
    await expect(command('list', {}, member)).rejects.toMatchObject({code: 'failed-precondition'});
  }
});
it('preserves permitted tabs, newlines and carriage returns in all editable text fields', async () => {
  const value = 'Move\t&\nCatch\rGuide';
  const fields = {title: value, introduction: value, instructions: [value]};
  expect(await save(fields)).toMatchObject({game: fields});
  expect(await command('list', {}, member)).toMatchObject({games: [fields]});
});
it('fails closed on corrupt saved content and never returns arbitrary stored fields', async () => {
  await save();
  store.documents.get(path('miniGameContent', gameId))!.organizationId = 'other';
  await expect(command('list', {}, member)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('uploads immutable media, binds receipts and accepts the uploaded URL on save', async () => {
  const cover = await upload();
  expect(cover).toMatchObject({schemaVersion: 1, organizationId: org, gameId, kind: 'cover'});
  expect(media.upload).toHaveBeenCalledWith(`orgs/${org}/miniGameMedia/${gameId}/cover/admin/${'b'.repeat(32)}`, png, 'image/png', expect.stringMatching(/^[a-f0-9]{64}$/));
  expect(await save({coverUrl: cover.url})).toMatchObject({game: {coverUrl: cover.url}});
  expect(await upload()).toEqual(cover);
});
it('accepts MP4 previews and enforces separate media kinds', async () => {
  const preview = await upload({kind: 'preview', contentType: 'video/mp4', dataBase64: mp4.toString('base64')});
  expect(await save({previewVideoUrl: preview.url})).toMatchObject({game: {previewVideoUrl: preview.url}});
  await expect(save({requestId: 'd'.repeat(32), baseRevision: 1, coverUrl: preview.url})).rejects.toMatchObject({code: 'permission-denied'});
});
it.each(['https://example.test/image.png', 'https://firebasestorage.googleapis.com/v0/b/other/o/file?alt=media&token=x'])('rejects an arbitrary URL %s without an upload receipt', async coverUrl => {
  await expect(save({coverUrl})).rejects.toMatchObject({code: 'permission-denied'});
});
it.each([{gameId: 'other'}, {kind: 'engine'}, {uploadId: 'x'}, {contentType: 'image/gif'}, {dataBase64: 'not-base64'}, {dataBase64: ''}, {dataBase64: png.toString('base64') + '\n'}, {dataBase64: 'AB=='}, {contentType: 'image/jpeg'}, {kind: 'preview'}, {contentType: 'video/mp4', dataBase64: mp4.toString('base64')}, {extra: 1}])('rejects malformed media %j', async fields => {
  await expect(upload(fields)).rejects.toHaveProperty('name', 'InputValidationError');
  expect(media.upload).not.toHaveBeenCalled();
});
it.each(['cover', 'preview'])('rejects oversize %s files before external upload', async kind => {
  const data = Buffer.alloc((kind === 'cover' ? 5 : 20) * 1024 * 1024 + 1);
  await expect(upload({kind, contentType: kind === 'cover' ? 'image/png' : 'video/mp4', dataBase64: data.toString('base64')})).rejects.toHaveProperty('name', 'InputValidationError');
  expect(media.upload).not.toHaveBeenCalled();
});
it('never creates a receipt or returns an upload after authority changes during external storage', async () => {
  media.upload = vi.fn(async () => {store.documents.get(path('members', admin.uid))!.status = 'inactive'; return 'https://example.test/orphan';});
  await expect(upload()).rejects.toMatchObject({code: 'permission-denied'});
  expect([...store.documents.keys()].some(k => k.includes('miniGameMediaReceipts'))).toBe(false);
});
it('checks fresh Auth after storage before creating a media receipt', async () => {
  freshAuth.mockResolvedValueOnce(undefined).mockRejectedValueOnce(Object.assign(new Error(), {code: 'unauthenticated'}));
  await expect(upload()).rejects.toMatchObject({code: 'unauthenticated'});
  expect([...store.documents.keys()].some(k => k.includes('miniGameMediaReceipts'))).toBe(false);
});
it('detects inconsistent saved idempotency snapshots', async () => {
  await save();
  const receipt = [...store.documents].find(([key]) => key.includes('miniGameContentRequests'))![1];
  (receipt.game as Record<string, unknown>).title = 'A mismatched snapshot';
  await expect(save()).rejects.toMatchObject({code: 'failed-precondition'});
});
it('rejects same-upload-reference changes even if a storage adapter returns the prior URL', async () => {
  await upload();
  await expect(upload({dataBase64: Buffer.concat([png, Buffer.from([1])]).toString('base64')})).rejects.toMatchObject({code: 'already-exists'});
});
it.each(['organizationId', 'gameId', 'kind', 'objectPath'])('rejects a media receipt with inconsistent %s', async field => {
  const cover = await upload();
  const receipt = [...store.documents].find(([key]) => key.includes('miniGameMediaReceipts'))![1];
  receipt[field] = 'other';
  await expect(save({coverUrl: cover.url})).rejects.toMatchObject({code: 'permission-denied'});
});
it('allows an Admin to remove previously uploaded media with empty strings', async () => {
  const cover = await upload(); await save({coverUrl: cover.url});
  expect(await save({requestId: 'd'.repeat(32), baseRevision: 1, coverUrl: ''})).toMatchObject({game: {coverUrl: '', revision: 2}});
});
it('recovers the committed save after a final freshness failure without another revision', async () => {
  freshAuth.mockResolvedValueOnce(undefined).mockRejectedValueOnce(Object.assign(new Error(), {code: 'unauthenticated'}));
  await expect(save()).rejects.toMatchObject({code: 'unauthenticated'});
  expect(await save()).toMatchObject({game: {revision: 1}});
  expect(store.documents.get(path('miniGameContent', gameId))?.revision).toBe(1);
});
it.each([
  ['image/jpeg', Buffer.from([255, 216, 255, 224, 0, 0])],
  ['image/webp', Buffer.from([82, 73, 70, 70, 4, 0, 0, 0, 87, 69, 66, 80])],
] as const)('accepts matching supported %s signatures', async (contentType, data) => {
  await expect(upload({contentType, dataBase64: data.toString('base64')})).resolves.toMatchObject({kind: 'cover'});
});
it.each(['cover', 'preview'])('accepts the exact %s byte limit with a callable body below 32 MB', async kind => {
  const data = Buffer.alloc((kind === 'cover' ? 5 : 20) * 1024 * 1024);
  (kind === 'cover' ? png : mp4).copy(data);
  const fields = {kind, contentType: kind === 'cover' ? 'image/png' : 'video/mp4', dataBase64: data.toString('base64')};
  expect(Buffer.byteLength(JSON.stringify({data: {schemaVersion: 1, organizationId: org, action: 'uploadMedia', gameId, uploadId: 'b'.repeat(32), ...fields}}))).toBeLessThan(32 * 1024 * 1024);
  await expect(upload(fields)).resolves.toMatchObject({kind});
});
it.each([Buffer.from('not an MP4'), Buffer.from([0, 0, 0, 99, ...mp4.subarray(4)]), Buffer.from([0, 0, 0, 16, 102, 116, 121, 112, 113, 116, 32, 32, 0, 0, 0, 0])])('rejects invalid or unsupported MP4 boxes', async bytes => {
  await expect(upload({kind: 'preview', contentType: 'video/mp4', dataBase64: bytes.toString('base64')})).rejects.toHaveProperty('name', 'InputValidationError');
});
it('uses current canonical Staff authority only for reads', async () => {
  store.documents.get('users/member')!.role = 'staff'; store.documents.get(path('members', 'member'))!.role = 'staff';
  await expect(command('list', {}, member)).resolves.toHaveProperty('games');
  await expect(save({}, member)).rejects.toMatchObject({code: 'permission-denied'});
});
it('fails closed when a mutation clock is invalid', async () => {
  await expect(miniGameContent(store, admin, {schemaVersion: 1, organizationId: org, action: 'save', gameId, requestId: 'a'.repeat(32), baseRevision: 0, ...content}, {media, freshAuth, clock: () => 0})).rejects.toMatchObject({code: 'failed-precondition'});
  expect(store.documents.has(path('miniGameContent', gameId))).toBe(false);
});
