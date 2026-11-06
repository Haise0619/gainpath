/** Offline audit draft ONLY. No Firebase SDK, deploy export, apply or cleanup executor. */
import {buildModule13DemoDataset} from '../recommendation/demo-dataset';
import {digestOf, validateBackupPayload} from '../workouts/workout-backup-validation';
import type {DocumentData} from '../../platform/firestore/store';

export const SHARED_DATA_BLOCKERS = [
  {code: 'published_visibility', detail: 'Ordinary published Coach and Tutorial queries and Rules have no cohort boundary.'},
  {code: 'admin_authority', detail: 'Canonical active Admin authority is organization-wide, including legacy services.'},
  {code: 'server_aggregates', detail: 'Admin SDK reporting scans canonical organization records without a dataset partition.'},
  {code: 'synthetic_provenance', detail: 'Current backup validation does not accept honestly labeled synthetic observations.'},
  {code: 'local_progress', detail: 'Ordinary Member progress uses local measured history, not seeded cloud backups.'},
  {code: 'normal_composition', detail: 'Ordinary Module 13 repositories remain unavailable; verified cohort wiring is missing.'},
  {code: 'program_catalog', detail: 'Legacy demo generator has no complete published 28-day Program catalog.'},
  {code: 'registration_scope', detail: 'The retired reserved-UID regex is not a general server-owned cohort assignment contract.'},
  {code: 'catalog_authoring', detail: 'Legacy demo catalog fixtures are not proof of complete normal authoring Timestamp contracts.'},
  {code: 'coach_management_profiles', detail: 'Legacy source has public Coach projections and credentials, but lacks the eight normal private professional profile roots.'},
  {code: 'member_profile_timestamps', detail: 'Legacy Member fitness profiles omit the updatedAt field required by normal profile authoring Rules.'},
] as const;

export interface SharedDraftRecord {path: string; data: DocumentData; digest: string; ownerSeedId: string}
export interface SharedDatasetDraft {
  schemaVersion: 1; seedId: 'gainpath-shared-v1'; anchorMillis: number;
  target: {projectId: 'gainpath-0619'; databaseId: '(default)'; organizationId: 'gainpath'};
  status: 'blocked'; liveApplyEnabled: false; approvalEligible: false;
  identities: {uid: string; email: string; displayName: string; role: string}[];
  stories: {memberId: string; scenario: string; exerciseId: string; expectedOutcome: string}[];
  records: SharedDraftRecord[]; counts: Record<string, number>;
  excludedLegacyPaths: string[]; blockers: typeof SHARED_DATA_BLOCKERS;
  validation: {syntheticWorkoutAcceptedByCurrentValidator: false; sourceSchemaAcceptance: 'incomplete'; relationships: 'legacy_generator_only'};
  integrity: string;
}
const seedId = 'gainpath-shared-v1' as const;
const pattern = /^[A-Za-z0-9_-]+$/;
// Explicit source-only allowlist. Capture attestations, recommendation outcomes,
// provider usage and the old access/policy registries MUST NOT be copied.
function sourcePath(path: string): boolean {
  const parts = path.split('/');
  if (parts[0] === 'users') return parts.length === 2;
  if (parts[0] !== 'orgs' || parts[1] !== 'gainpath') return false;
  if (parts.length === 4) return ['members', 'profiles', 'preferences', 'coaches', 'coachProfiles',
    'coachAvailability', 'exerciseVideos', 'routineBlueprints', 'content'].includes(parts[2]);
  if (parts.length === 6) return parts[2] === 'members' && parts[4] === 'workoutBackups' ||
    parts[2] === 'coachProfiles' && ['certifications', 'certificationState'].includes(parts[4]) ||
    parts[2] === 'coachAvailability' && parts[4] === 'days';
  if (parts.length === 8) return parts[2] === 'members' && parts[4] === 'workoutBackups' && parts[6] === 'revisions' ||
    parts[2] === 'coachProfiles' && parts[4] === 'certifications' && parts[6] === 'history';
  return false;
}
function honestObservation(value: unknown): unknown {
  if (value === 'realCamera') return 'recordedFixture';
  if (Array.isArray(value)) return value.map(honestObservation);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, honestObservation(v)]));
  return value;
}
function signature(draft: Omit<SharedDatasetDraft, 'integrity'> | SharedDatasetDraft): string {
  const {integrity: _ignored, ...body} = draft as SharedDatasetDraft;
  return digestOf(body);
}
export async function buildSharedDatasetDraft(options: {anchorMillis: number}): Promise<SharedDatasetDraft> {
  const {anchorMillis} = options;
  if (!Number.isSafeInteger(anchorMillis) || anchorMillis < 0 || anchorMillis > 8640000000000000 - 90 * 86400000)
    throw Error('An explicit valid anchor is required.');
  // Reuse the existing pure fixture generator; never invoke its SDK seeder or consent commands.
  const legacy = await buildModule13DemoDataset({nowMillis: anchorMillis});
  const records: SharedDraftRecord[] = [], excludedLegacyPaths: string[] = [];
  let rejectedSynthetic = false;
  for (const path of Object.keys(legacy.documents).sort()) {
    if (!sourcePath(path)) {excludedLegacyPaths.push(path); continue;}
    let data = structuredClone(legacy.documents[path]);
    if (typeof data.payloadJson === 'string') {
      const payload = honestObservation(JSON.parse(data.payloadJson)) as DocumentData;
      data = {...data, payloadJson: JSON.stringify(payload), digest: digestOf(payload)};
      if (data.kind === 'session') {
        try {validateBackupPayload('session', String(data.id), 'gainpath', String(payload.userId), payload);}
        catch {rejectedSynthetic = true;}
      }
    }
    // Authoring and isolation are deliberately NOT declared valid by adding a demo flag.
    records.push({path, data, digest: digestOf(data), ownerSeedId: seedId});
  }
  if (!rejectedSynthetic) throw Error('Synthetic provenance incompatibility must be reviewed again.');
  const counts: Record<string, number> = {};
  for (const {path} of records) {const parent = path.split('/').slice(0, -1).join('/'); counts[parent] = (counts[parent] ?? 0) + 1;}
  const draft: Omit<SharedDatasetDraft, 'integrity'> = {
    schemaVersion: 1, seedId, anchorMillis, target: {projectId: 'gainpath-0619', databaseId: '(default)', organizationId: 'gainpath'},
    status: 'blocked', liveApplyEnabled: false, approvalEligible: false,
    identities: legacy.authUsers.map(u => ({uid: u.uid, email: u.email, displayName: u.displayName,
      role: legacy.coachIds.includes(u.uid) ? 'coach' : u.uid === legacy.adminId ? 'admin' : 'member'})),
    stories: legacy.memberScenarios.map(s => ({memberId: s.memberId, scenario: s.scenario, exerciseId: s.exerciseId, expectedOutcome: s.expectedOutcome})),
    records, counts, excludedLegacyPaths, blockers: SHARED_DATA_BLOCKERS,
    validation: {syntheticWorkoutAcceptedByCurrentValidator: false, sourceSchemaAcceptance: 'incomplete', relationships: 'legacy_generator_only'},
  };
  return {...draft, integrity: signature(draft)};
}
export function compareSharedDatasetDraft(a: SharedDatasetDraft, b: SharedDatasetDraft): 'identical' {
  if (a.anchorMillis !== b.anchorMillis) throw Error('Existing seed anchor must not be changed.');
  if (signature(a) !== a.integrity || signature(b) !== b.integrity || a.integrity !== b.integrity)
    throw Error('Draft integrity differs; never overwrite existing records.');
  return 'identical';
}
/** Deliberately unconditional: mutable plan fields cannot grant write authority. */
export function assertSharedDatasetExecutable(_draft: SharedDatasetDraft): never {
  throw Error('Shared default-database seed is not executable: cross-module isolation and synthetic readers are unimplemented.');
}
export function planExactOwnedCleanup(requestedSeedId: string, records: {
  path: string; seedId: string; expectedDigest: string; currentDigest: string;
}[]): {executable: false; paths: string[]} {
  if (requestedSeedId !== seedId || records.length > 5000) throw Error('Invalid cleanup ownership.');
  const paths = new Set<string>();
  for (const r of records) {
    if (!sourcePath(r.path) || !r.path.split('/').every(p => pattern.test(p)) || r.seedId !== requestedSeedId ||
      !/^[a-f0-9]{64}$/.test(r.expectedDigest) || r.currentDigest !== r.expectedDigest || paths.has(r.path))
      throw Error('Cleanup ownership, content or exact path changed.');
    paths.add(r.path);
  }
  return {executable: false, paths: [...paths].sort()};
}
