import {expect, it} from 'vitest';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {buildSharedDatasetDraft, assertSharedDatasetExecutable, compareSharedDatasetDraft,
  planExactOwnedCleanup} from '../src/modules/demo/shared-dataset-plan';

const anchorMillis = Date.UTC(2026, 10, 3, 4);
it('reuses fictional identities and stories but never authorizes a default-database write', async () => {
  const d = await buildSharedDatasetDraft({anchorMillis});
  expect(d.target).toEqual({projectId: 'gainpath-0619', databaseId: '(default)', organizationId: 'gainpath'});
  expect(d.status).toBe('blocked'); expect(d.liveApplyEnabled).toBe(false);
  expect(d.identities).toHaveLength(27); expect(d.stories).toHaveLength(18);
  expect(d.records.some(r => r.path.includes('/coaches/'))).toBe(true);
  expect(d.records.some(r => /recommendation(Leads|Inbox|DeliveryReceipts)|workoutEvidenceCaptures|module13Demo/.test(r.path))).toBe(false);
  expect(d.blockers.map(b => b.code)).toEqual(expect.arrayContaining(['published_visibility', 'admin_authority',
    'server_aggregates', 'synthetic_provenance', 'local_progress', 'normal_composition', 'program_catalog', 'registration_scope']));
  expect(() => assertSharedDatasetExecutable(d)).toThrow('not executable');
  expect(() => assertSharedDatasetExecutable({...d, status: 'ready', blockers: [], liveApplyEnabled: true} as never)).toThrow('not executable');
});
it('honestly labels every proposed observation and removes capture attestations', async () => {
  const d = await buildSharedDatasetDraft({anchorMillis});
  const observations = d.records.filter(r => r.path.includes('/workoutBackups/'));
  expect(observations.length).toBeGreaterThan(0);
  expect(JSON.stringify(d)).not.toContain('realCamera');
  expect(observations.every(r => String(r.data.payloadJson).includes('recordedFixture'))).toBe(true);
  expect(d.validation.syntheticWorkoutAcceptedByCurrentValidator).toBe(false);
});
it('keeps an explicit deterministic anchor and detects reanchoring or edited plans', async () => {
  const a = await buildSharedDatasetDraft({anchorMillis}), b = await buildSharedDatasetDraft({anchorMillis});
  expect(a).toEqual(b); expect(compareSharedDatasetDraft(a, b)).toBe('identical');
  const next = await buildSharedDatasetDraft({anchorMillis: anchorMillis + 86400000});
  expect(() => compareSharedDatasetDraft(a, next)).toThrow('anchor');
  b.records[0].data.changed = true;
  expect(() => compareSharedDatasetDraft(a, b)).toThrow('integrity');
});
it.each([NaN, Infinity, -1, 1.5, 8640000000000001])('rejects invalid anchor %s', async anchorMillis => {
  await expect(buildSharedDatasetDraft({anchorMillis})).rejects.toThrow('anchor');
});
it('never emits credentials, derived outcomes, payments, or arbitrary awards', async () => {
  const d = await buildSharedDatasetDraft({anchorMillis});
  expect(JSON.stringify(d)).not.toMatch(/password|privateKey|apiKey|bytesBase64/);
  expect(d.records.every(r => !/\/(transactions|payments|pointsLedger|notifications|recommendationLeads|recommendationInbox)\//.test(r.path))).toBe(true);
  expect(d.records.every(r => r.digest.length === 64 && r.ownerSeedId === d.seedId)).toBe(true);
});
it('plans cleanup only for exact matching ownership and bytes; never executes deletion', () => {
  const owned = {path: 'orgs/gainpath/coaches/fictional', seedId: 'gainpath-shared-v1', expectedDigest: 'a'.repeat(64), currentDigest: 'a'.repeat(64)};
  expect(planExactOwnedCleanup('gainpath-shared-v1', [owned])).toEqual({executable: false, paths: [owned.path]});
  for (const patch of [{seedId: 'other'}, {currentDigest: 'b'.repeat(64)}, {path: 'orgs/gainpath'}, {path: '../real'}, {expectedDigest: ''}]) {
    expect(() => planExactOwnedCleanup('gainpath-shared-v1', [{...owned, ...patch}])).toThrow();
  }
  expect(() => planExactOwnedCleanup('gainpath-shared-v1', [owned, owned])).toThrow();
});
it('superseded CLI rejects the old live plan before loading SDK or compiled seed code', () => {
  const result = spawnSync(process.execPath, ['tools/seed-module13-demo.cjs', '--live-plan', '--dry-run'], {encoding: 'utf8'});
  expect(result.status).not.toBe(0); expect(result.stderr).toContain('superseded');
});
it('new planner rejects apply and both historical app bootstraps block live initialization', () => {
  const result = spawnSync(process.execPath, ['tools/plan-shared-dataset.cjs', '--apply'], {encoding: 'utf8'});
  expect(result.status).not.toBe(0); expect(result.stderr).toContain('No apply/live/deploy mode');
  for (const app of ['admin_web', 'mobile']) {
    const source = readFileSync(`../apps/${app}/lib/infrastructure/firebase/firebase_demo_bootstrap.dart`, 'utf8');
    expect(source.indexOf("if (!const bool.fromEnvironment('MODULE13_DEMO_EMULATOR'))")).toBeLessThan(source.indexOf('Firebase.initializeApp('));
    expect(source).toContain('separate Module 13 live demo architecture is superseded');
  }
});
