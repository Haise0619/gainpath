import {Firestore} from 'firebase-admin/firestore';
import {afterEach, beforeEach, expect, it, vi} from 'vitest';
import {assertFypRuntimeRelease, resolveFypRuntimeRelease, revalidateFypRuntimeRelease} from '../src/modules/dataset/fyp-runtime-release';

const releasePath = 'datasetRuntimeReleases/fyp-v1';
const emulatorVariables = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_DATABASE_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST', 'FIREBASE_EMULATOR_HUB', 'FUNCTIONS_EMULATOR'];
const config = () => ({schemaVersion: 1, projectId: 'gainpath-0619', databaseId: '(default)', organizationId: 'gainpath',
  datasetId: 'fyp-v1', seedId: 'gainpath-fyp-v1', rootPath: 'orgs/gainpath/cohorts/fyp-v1', releaseVersion: 'fyp-cohort-v1',
  enabled: true, fictionalOnly: true, sourceManifestDigest: 'a'.repeat(64), authUids: Array.from({length: 27}, (_, i) => `fictional-${i + 1}`)});

/** SDK-prototype stub only: no Firestore constructor, app, credentials or network. */
function fixture(...args: unknown[]) {
  let data = args.length ? args[0] : config(), error: unknown, afterRead: (() => void) | undefined;
  const get = vi.fn(async () => {if (error) throw error; afterRead?.(); return {exists: data !== undefined, data: () => data};});
  const doc = vi.fn((path: string) => {expect(path).toBe(releasePath); return {get};});
  const db = Object.create(Firestore.prototype) as Firestore;
  Object.defineProperties(db, {_projectId: {value: 'gainpath-0619', writable: true}, _databaseId: {value: '(default)', writable: true},
    _settings: {value: {}, writable: true}, doc: {value: doc}});
  return {db, doc, get, replace: (next: unknown) => {data = next;}, fail: (next: unknown) => {error = next;},
    afterRead: (hook: () => void) => {afterRead = hook;}};
}
beforeEach(() => {for (const name of [...emulatorVariables, 'GOOGLE_CLOUD_UNIVERSE_DOMAIN']) vi.stubEnv(name, undefined);});
afterEach(() => vi.unstubAllEnvs());

it('defaults closed for a missing or disabled release', async () => {
  for (const raw of [undefined, null, {...config(), enabled: false}]) await expect(resolveFypRuntimeRelease(fixture(raw).db)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('mints an opaque grant bound to the exact SDK instance, fictional UIDs and source digest', async () => {
  const f = fixture(), grant = await resolveFypRuntimeRelease(f.db);
  expect(Object.isFrozen(grant)).toBe(true);
  expect(() => assertFypRuntimeRelease(grant, f.db, 'fictional-1', 'a'.repeat(64))).not.toThrow();
  expect(() => assertFypRuntimeRelease(grant, fixture().db)).toThrow();
  expect(() => assertFypRuntimeRelease(grant, f.db, 'ordinary-user')).toThrow();
  expect(() => assertFypRuntimeRelease(grant, f.db, 'fictional-1', 'b'.repeat(64))).toThrow();
  expect(f.get).toHaveBeenCalledTimes(1);
});
it('rejects structural or serialized substitutes for a server-only grant', async () => {
  const f = fixture(), grant = await resolveFypRuntimeRelease(f.db);
  for (const fake of [{}, {...grant}, JSON.parse(JSON.stringify(grant)), {enabled: true, sourceManifestDigest: 'a'.repeat(64)}]) {
    expect(() => assertFypRuntimeRelease(fake as typeof grant, f.db)).toThrow();
  }
});
it('validates every authority field and rejects extra client-style activation controls', async () => {
  for (const patch of [{schemaVersion: 2}, {projectId: 'foreign'}, {databaseId: 'named'}, {organizationId: 'foreign'},
    {datasetId: 'other'}, {seedId: 'other'}, {rootPath: 'orgs/gainpath'}, {releaseVersion: 'next'}, {fictionalOnly: false},
    {sourceManifestDigest: 'x'.repeat(64)}, {sourceManifestDigest: 'a'.repeat(63)}, {demoMode: true}, {enabled: 'true'}]) {
    await expect(resolveFypRuntimeRelease(fixture({...config(), ...patch}).db)).rejects.toMatchObject({code: 'failed-precondition'});
  }
});
it('requires exactly 27 distinct bounded Auth IDs', async () => {
  const ids = config().authUids;
  for (const authUids of [[], ids.slice(0, 26), [...ids, 'extra'], [...ids.slice(0, 26), ids[0]], [...ids.slice(0, 26), '../foreign'],
    [...ids.slice(0, 26), 'x'.repeat(129)], [...ids.slice(0, 26), ''], [...ids.slice(0, 26), 42], 'fictional']) {
    await expect(resolveFypRuntimeRelease(fixture({...config(), authUids}).db)).rejects.toMatchObject({code: 'failed-precondition'});
  }
});
it('rejects foreign SDK projects, named databases, insecure transports and custom hosts before reading configuration', async () => {
  for (const patch of [{_projectId: 'demo-gainpath-fyp'}, {_databaseId: 'named'}, {_settings: {ssl: false}},
    {_settings: {servicePath: '127.0.0.1', port: 18231, ssl: true}}, {_settings: {host: 'evil.example'}},
    {_settings: {apiEndpoint: 'evil.example'}}, {_settings: {port: 8443}}, {_settings: {protocol: 'http'}},
    {_settings: {universeDomain: 'evil.example'}}, {_settings: {sslCreds: {}}}]) {
    const f = fixture(); Object.assign(f.db, patch);
    await expect(resolveFypRuntimeRelease(f.db)).rejects.toMatchObject({code: 'failed-precondition'});
    expect(f.doc).not.toHaveBeenCalled();
  }
  await expect(resolveFypRuntimeRelease({projectId: 'gainpath-0619', databaseId: '(default)'} as unknown as Firestore)).rejects.toThrow();
});
it('accepts only the default TLS Firestore endpoint when explicitly configured', async () => {
  const f = fixture(); Object.assign(f.db, {_settings: {servicePath: 'firestore.googleapis.com', ssl: true, port: 443}});
  const grant = await resolveFypRuntimeRelease(f.db);
  expect(() => assertFypRuntimeRelease(grant, f.db)).not.toThrow();
});
it('rejects ambient universe-domain overrides that change the SDK default endpoint', async () => {
  vi.stubEnv('GOOGLE_CLOUD_UNIVERSE_DOMAIN', 'foreign.example');
  const f = fixture(); await expect(resolveFypRuntimeRelease(f.db)).rejects.toMatchObject({code: 'failed-precondition'});
  expect(f.doc).not.toHaveBeenCalled();
});
it('rejects every emulator environment even with a matching real-project SDK instance', async () => {
  for (const variable of emulatorVariables) {
    vi.stubEnv(variable, variable === 'FUNCTIONS_EMULATOR' ? 'true' : '127.0.0.1:9999');
    const f = fixture(); await expect(resolveFypRuntimeRelease(f.db)).rejects.toMatchObject({code: 'failed-precondition'});
    expect(f.doc).not.toHaveBeenCalled(); vi.stubEnv(variable, undefined);
  }
});
it('revalidates the exact still-enabled server record before subsequent use', async () => {
  const f = fixture(), grant = await resolveFypRuntimeRelease(f.db);
  await expect(revalidateFypRuntimeRelease(grant, f.db)).resolves.toBeUndefined();
  expect(f.get).toHaveBeenCalledTimes(2);
  for (const raw of [undefined, {...config(), enabled: false}, {...config(), sourceManifestDigest: 'b'.repeat(64)},
    {...config(), authUids: [...config().authUids].reverse()}]) {
    f.replace(raw); await expect(revalidateFypRuntimeRelease(grant, f.db)).rejects.toMatchObject({code: 'failed-precondition'});
  }
});
it('rechecks SDK transport/environment binding after minting and after an awaited config read', async () => {
  const f = fixture(), grant = await resolveFypRuntimeRelease(f.db);
  Object.assign(f.db, {_settings: {ssl: false}});
  expect(() => assertFypRuntimeRelease(grant, f.db)).toThrow();
  await expect(revalidateFypRuntimeRelease(grant, f.db)).rejects.toThrow();
  const race = fixture(); race.afterRead(() => {Object.assign(race.db, {_settings: {servicePath: 'evil.example'}});});
  await expect(resolveFypRuntimeRelease(race.db)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('sanitizes SDK configuration-read failures and never relays provider details', async () => {
  const f = fixture(); f.fail(Error('private credentials and provider details'));
  await expect(resolveFypRuntimeRelease(f.db)).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(resolveFypRuntimeRelease(f.db)).rejects.not.toThrow('private credentials');
});
