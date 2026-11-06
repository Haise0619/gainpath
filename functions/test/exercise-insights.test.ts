import {beforeEach, expect, it} from 'vitest';
import {MemoryStore} from './memory-store';
import {exerciseInsightsHandler} from '../src/modules/recommendation/exercise-insights';
import type {EvidenceRow, ExerciseInsightsDependencies, InsightsRequest, ProvisionalSamplePolicy} from '../src/modules/recommendation/exercise-insights-contracts';
import {consent, curl, metrics, now, query, routine, row, scope, session} from './exercise-insights-fixture';
import type {DocumentData} from '../src/platform/firestore/store';

const auth = {uid: 'private-admin-001', token: {email_verified: true, auth_time: 100, email: 'private-admin@example.invalid'}};
const policy: ProvisionalSamplePolicy = {schemaVersion: 1, revision: 'synthetic-policy-v1',
  minimumScoredSessions: 2, minimumDistinctDays: 2, minimumAssessedAttempts: 15, minimumTrackingCoverage: 0.7};
let store: MemoryStore, dependencies: ExerciseInsightsDependencies, rows: Map<string, EvidenceRow[]>;
let backupReads: number, onBackupRead: (() => void) | undefined;
const memberPath = (uid: string) => `orgs/gainpath/members/${uid}`;
const consentPath = (uid: string) => `orgs/gainpath/recommendationConsent/${uid}`;
function addMember(uid = scope.memberId) {
  store.documents.set(`users/${uid}`, {organizationId: 'gainpath', role: 'member'});
  store.documents.set(memberPath(uid), {organizationId: 'gainpath', userId: uid, role: 'member', status: 'active', branchIds: []});
  store.documents.set(consentPath(uid), consent(uid));
}
const invoke = (data: unknown = query, patch: Partial<InsightsRequest> = {}) => exerciseInsightsHandler({
  app: {appId: 'synthetic-verified-app'}, auth, data, ...patch}, dependencies);
beforeEach(() => {
  store = new MemoryStore(); rows = new Map([[scope.memberId, [row()]]]); backupReads = 0; onBackupRead = undefined;
  store.documents.set('orgs/gainpath', {status: 'active'});
  store.documents.set(`users/${auth.uid}`, {organizationId: 'gainpath', role: 'admin'});
  store.documents.set(memberPath(auth.uid), {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});
  addMember();
  dependencies = {store, clock: () => now,
    readAuthIdentity: async uid => ({uid, email: 'private-admin@example.invalid', emailVerified: true,
      disabled: false, tokensValidAfterMillis: 0}),
    reader: {
      members: async (org, after, limit) => [...store.documents].filter(([path]) => path.startsWith(`orgs/${org}/members/`)
        && !path.slice(`orgs/${org}/members/`.length).includes('/'))
        .map(([path, data]) => ({id: path.split('/').at(-1)!, data}))
        .filter(r => !after || r.id > after).sort((a, b) => a.id < b.id ? -1 : 1).slice(0, limit),
      backups: async (s, after, limit) => {
        if (s.organizationId !== 'gainpath') throw Error('Foreign reader scope');
        backupReads++; onBackupRead?.();
        return (rows.get(s.memberId) ?? []).filter(r => !after || r.id > after).slice(0, limit);
      },
    }};
});
it('returns known-answer aggregate evidence, provenance and no active minimum/threshold policy', async () => {
  rows.set(scope.memberId, [row(session('a', 80), 'a'), row(session('b', 60, '2026-10-29T15:59:59.000Z'), 'b')]);
  const before = JSON.stringify([...store.documents]);
  const result = await invoke();
  expect(result).toMatchObject({mode: 'descriptive_only', status: 'available', attentionThreshold: null,
    samplePolicy: null, source: {classification: 'provisional_member_backup', validation: 'existing_workout_backup_validator',
      scanStartedAtMillis: now, capturedAtMillis: now, recordsScanned: 2},
    coverage: {activeMembers: 1, consentedMembers: 1, membersWithBackups: 1, membersWithSupportedEvidence: 1}});
  expect(result.groups).toHaveLength(1);
  expect(result.groups[0]).toMatchObject({sessions: 2, members: 1, scoredSessions: 2, assessedAttempts: 20,
    missingScoreSessions: 0, distinctSessionDays: 2, meanEstimatedFormScore: 70,
    trackedMicros: 16000000, rejectedMicros: 4000000, trackingCoverage: 0.8,
    evidenceState: 'policy_not_configured', membersMeetingProvisionalMinimums: null});
  expect(JSON.stringify([...store.documents])).toBe(before);
  const publicJson = JSON.stringify(result);
  for (const privateText of ['private-member', 'private-admin', 'private-session', 'memberId', 'sessionId',
    'payloadJson', 'poseMetrics', 'consentedAt', 'digest', '2026-10-29T15:59:59.000Z']) expect(publicJson).not.toContain(privateText);
});
it('weights Member means equally rather than letting a prolific Member dominate', async () => {
  rows.set(scope.memberId, [row(session('a', 80), 'a'), row(session('b', 60), 'b')]);
  addMember('private-second-member');
  // Equal local session IDs on different accounts are distinct evidence.
  const p = session('a', 100); p.userId = 'private-second-member';
  rows.set('private-second-member', [row(p)]);
  expect((await invoke()).groups[0]).toMatchObject({sessions: 3, members: 2, meanEstimatedFormScore: 85});
});
it('does not mistake a valid zero form score for missing data', async () => {
  rows.set(scope.memberId, [row(session('zero', 0))]);
  expect((await invoke()).groups[0]).toMatchObject({scoredSessions: 1, missingScoreSessions: 0, meanEstimatedFormScore: 0});
});
it('reports null scores without treating them as poor performance', async () => {
  rows.set(scope.memberId, [row(session('null', null))]);
  expect((await invoke()).groups[0]).toMatchObject({scoredSessions: 0, missingScoreSessions: 1,
    meanEstimatedFormScore: null, evidenceState: 'no_scored_samples'});
});
it('retains unscored exercise coverage without form-score claims', async () => {
  const p = session('row', null); p.exerciseId = 'single-arm-dumbbell-row-side-v1';
  Object.assign(metrics(p), {schemaVersion: 3, scoringVersion: 'single-arm-row-side-v1', rowSide: 'left'});
  rows.set(scope.memberId, [row(p)]);
  expect((await invoke()).groups[0]).toMatchObject({sessions: 1, scoredSessions: 0, missingScoreSessions: 0,
    unscoredSessions: 1, meanEstimatedFormScore: null,
    compatibility: {mode: 'left', scoreSupport: 'unscored'}, evidenceState: 'unscored'});
});
it('does not merge curl modes or count unsupported scoring/model versions as compatible evidence', async () => {
  const old = session('old'); metrics(old).scoringVersion = 'bodyweight-squat-side-v2';
  const model = session('model'); metrics(model).detectorVersion = 'private-unsupported-model';
  rows.set(scope.memberId, [row(curl('a', 'leftOnly'), 'a'), row(curl('b', 'rightOnly'), 'b'),
    row(curl('c', 'both'), 'c'), row(old, 'd'), row(model, 'e')]);
  const result = await invoke();
  expect(result.groups).toHaveLength(3);
  expect(result.groups.map(g => g.compatibility.mode).sort()).toEqual(['both', 'leftOnly', 'rightOnly']);
  expect(result.groups.every(g => g.scoredSessions === 1)).toBe(true);
  expect(result.exclusions).toMatchObject({unsupportedSessions: 2,
    unsupportedReasons: {unsupported_scoring_version: 1, unsupported_detector: 1}});
  expect(JSON.stringify(result)).not.toContain('private-unsupported-model');
});
it('deduplicates head/revision session copies and excludes routine checkpoints entirely', async () => {
  const r = routine('c'), revision = structuredClone(r); revision.id = 'd';
  const payload = JSON.parse(String(revision.data.payloadJson)) as DocumentData;
  payload.selectedIndex = 0; payload.updatedAtMicros = Number(payload.updatedAtMicros) + 1000;
  (payload.attempt as DocumentData).updatedAtMicros = payload.updatedAtMicros;
  const newer = row(payload, 'e', 'routine'); newer.data.updatedAtMillis++;
  rows.set(scope.memberId, [row(session(), 'a'), row(session(), 'b'), r, revision, newer]);
  const result = await invoke();
  expect(result.groups[0].sessions).toBe(1);
  expect(result.exclusions).toMatchObject({duplicateRecords: 3, routineRecords: 1});
});
it('rejects conflicting immutable session revisions instead of choosing or double-counting them', async () => {
  rows.set(scope.memberId, [row(session('same', 80), 'a'), row(session('same', 60), 'b')]);
  await expect(invoke()).rejects.toMatchObject({code: 'failed-precondition', message: 'Exercise insight sources require review.'});
});
it('validates corrupt duplicate revisions before deduplication', async () => {
  const duplicate = row(session(), 'b'); duplicate.data.digest = 'a'.repeat(64);
  rows.set(scope.memberId, [row(session(), 'a'), duplicate]);
  await expect(invoke()).rejects.toMatchObject({code: 'failed-precondition'});
});
it('uses a half-open date window and excludes future device sessions without implying inactivity', async () => {
  rows.set(scope.memberId, [row(session('before', 80, '2026-10-29T16:00:00.000Z'), 'a'),
    row(session('inside', 70, '2026-10-30T16:00:00.000Z'), 'b'),
    row(session('end', 60, '2026-10-31T16:00:00.000Z'), 'c'),
    row(session('future', 50, '2026-11-02T16:00:00.000Z'), 'd')]);
  const result = await invoke({...query, startAtMillis: Date.UTC(2026, 9, 30, 16), endAtMillis: Date.UTC(2026, 9, 31, 16)});
  expect(result.groups[0]).toMatchObject({sessions: 1, meanEstimatedFormScore: 70});
  expect(result.exclusions).toMatchObject({outOfWindowSessions: 2, futureSessions: 1});
});
it('only evaluates explicitly supplied provisional sample minimums and never creates attention flags', async () => {
  dependencies = {...dependencies, provisionalPolicy: policy};
  let result = await invoke();
  expect(result.groups[0]).toMatchObject({evidenceState: 'insufficient_evidence', membersMeetingProvisionalMinimums: 0});
  rows.set(scope.memberId, [row(session('a', 80), 'a'), row(session('b', 60, '2026-10-29T15:59:59.000Z'), 'b')]);
  result = await invoke();
  expect(result.groups[0]).toMatchObject({evidenceState: 'meets_provisional_minimums', membersMeetingProvisionalMinimums: 1});
  expect(result.attentionThreshold).toBeNull();
});
it('cannot pool different Members to meet individual sample minimums', async () => {
  dependencies = {...dependencies, provisionalPolicy: policy}; addMember('second');
  const p = session('second', 70, '2026-10-29T15:59:59.000Z'); p.userId = 'second'; rows.set('second', [row(p)]);
  expect((await invoke()).groups[0]).toMatchObject({scoredSessions: 2, members: 2,
    evidenceState: 'insufficient_evidence', membersMeetingProvisionalMinimums: 0});
});
it('does not count low-coverage samples toward a provisional minimum', async () => {
  dependencies = {...dependencies, provisionalPolicy: {...policy, minimumTrackingCoverage: 0.9}};
  rows.set(scope.memberId, [row(session('a'), 'a'), row(session('b', 60, '2026-10-29T15:59:59.000Z'), 'b')]);
  expect((await invoke()).groups[0]).toMatchObject({scoredSessions: 2,
    evidenceState: 'insufficient_evidence', membersMeetingProvisionalMinimums: 0});
});
it.each([undefined, {consented: true}, {...consent(), revokedAtMillis: now - 2000},
  {...consent(), purposes: {...consent().purposes as object, exerciseInsights: false}},
])('never reads histories without separate current insights consent (%j)', async c => {
  if (c === undefined) store.documents.delete(consentPath(scope.memberId)); else store.documents.set(consentPath(scope.memberId), c);
  const result = await invoke();
  expect(result.status).toBe('no_consented_members'); expect(result.groups).toEqual([]);
  expect(result.coverage.membersWithoutConsent).toBe(1); expect(backupReads).toBe(0);
});
it('discards all results if consent changes during the scan', async () => {
  onBackupRead = () => {store.documents.set(consentPath(scope.memberId), {...consent(), revision: 2, revokedAtMillis: now - 2000});};
  await expect(invoke()).rejects.toMatchObject({code: 'aborted'});
});
it.each([
  [{app: undefined}, 'unauthenticated'], [{auth: undefined}, 'unauthenticated'],
  [{auth: {...auth, token: {...auth.token, email_verified: false}}}, 'permission-denied'],
] as const)('rejects missing App Check/Auth/verification before reading histories (%j)', async (patch, code) => {
  await expect(invoke(query, patch)).rejects.toMatchObject({code}); expect(backupReads).toBe(0);
});
it.each(['member', 'coach', 'staff'])('rejects the %s role', async role => {
  store.documents.set(memberPath(auth.uid), {organizationId: 'gainpath', role, status: 'active', branchIds: []});
  await expect(invoke()).rejects.toMatchObject({code: 'permission-denied'}); expect(backupReads).toBe(0);
});
it('rejects a disabled or token-revoked Admin using fresh Auth', async () => {
  dependencies = {...dependencies, readAuthIdentity: async uid => ({uid, email: String(auth.token.email), emailVerified: true,
    disabled: true, tokensValidAfterMillis: 101000})};
  await expect(invoke()).rejects.toMatchObject({code: 'unauthenticated'}); expect(backupReads).toBe(0);
});
it('rechecks Admin membership after source reads', async () => {
  onBackupRead = () => {store.documents.set(memberPath(auth.uid), {organizationId: 'gainpath', role: 'admin', status: 'inactive', branchIds: []});};
  await expect(invoke()).rejects.toMatchObject({code: 'permission-denied'});
});
it('discards output when a participating Member becomes inactive', async () => {
  onBackupRead = () => {store.documents.set(memberPath(scope.memberId), {organizationId: 'gainpath', role: 'member', status: 'inactive', branchIds: []});};
  await expect(invoke()).rejects.toMatchObject({code: 'aborted'});
});
it('rejects organization drift and source owner substitution', async () => {
  const p = session(); p.userId = 'foreign'; rows.set(scope.memberId, [row(p)]);
  await expect(invoke()).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(invoke({...query, organizationId: 'foreign'})).rejects.toMatchObject({code: 'permission-denied'});
});
it.each([
  {...query, startAtMillis: NaN}, {...query, startAtMillis: query.endAtMillis},
  {...query, endAtMillis: now + 1}, {...query, startAtMillis: 0},
  {...query, memberId: scope.memberId}, {...query, threshold: 70},
])('rejects unbounded/future/invalid dates and client policy/identity injection (%j)', async data => {
  await expect(invoke(data)).rejects.toMatchObject({code: 'invalid-argument'}); expect(backupReads).toBe(0);
});
it('rejects nonascending source pagination rather than looping or leaking partial totals', async () => {
  rows.set(scope.memberId, [row(session(), 'b'), row(session(), 'a')]);
  await expect(invoke()).rejects.toMatchObject({code: 'failed-precondition'});
});
it('counts duplicate records against the record bound before filtering', async () => {
  rows.set(scope.memberId, Array.from({length: 2001}, (_, i) => row(session(), `row-${String(i).padStart(4, '0')}`)));
  await expect(invoke()).rejects.toMatchObject({code: 'resource-exhausted'});
});
it('bounds bytes before JSON parsing', async () => {
  const r = row(); r.data.payloadJson = ' '.repeat(16 * 1024 * 1024 + 1); rows.set(scope.memberId, [r]);
  await expect(invoke()).rejects.toMatchObject({code: 'resource-exhausted'});
});
it('bounds the membership scan even for nonconsented accounts', async () => {
  for (let i = 0; i < 2001; i++) store.documents.set(memberPath(`m${String(i).padStart(4, '0')}`),
    {organizationId: 'gainpath', role: 'member', status: 'inactive', branchIds: []});
  await expect(invoke()).rejects.toMatchObject({code: 'resource-exhausted'}); expect(backupReads).toBe(0);
});
it('bounds eligible Members before any history processing', async () => {
  for (let i = 0; i < 200; i++) addMember(`active-${String(i).padStart(3, '0')}`);
  await expect(invoke()).rejects.toMatchObject({code: 'resource-exhausted'}); expect(backupReads).toBe(0);
});
it('rejects an oversized page instead of ignoring the excess records', async () => {
  dependencies = {...dependencies, reader: {...dependencies.reader,
    backups: async () => Array.from({length: 26}, (_, i) => row(session(), `row-${i}`))}};
  await expect(invoke()).rejects.toMatchObject({code: 'failed-precondition'});
});
it('sanitizes typed transport failures as well as ordinary exceptions', async () => {
  const {DomainError} = await import('../src/platform/errors');
  dependencies = {...dependencies, reader: {...dependencies.reader, backups: async () => {
    throw new DomainError('failed-precondition', 'private-member-001 private-history-secret');
  }}};
  await expect(invoke()).rejects.toMatchObject({code: 'failed-precondition', message: 'Exercise insight sources require review.'});
});
it('rejects an invalid injected sample policy rather than reporting false sufficiency', async () => {
  dependencies = {...dependencies, provisionalPolicy: {...policy, minimumScoredSessions: 0}};
  await expect(invoke()).rejects.toMatchObject({code: 'invalid-argument'}); expect(backupReads).toBe(0);
});
it('reports unsupported-only or empty sources explicitly', async () => {
  const p = session(); p.exerciseId = 'unregistered'; rows.set(scope.memberId, [row(p)]);
  let result = await invoke();
  expect(result.status).toBe('no_supported_evidence'); expect(result.groups).toEqual([]);
  expect(result.exclusions.unsupportedSessions).toBe(1);
  rows.set(scope.memberId, []); result = await invoke();
  expect(result.status).toBe('no_supported_evidence'); expect(result.coverage.membersWithBackups).toBe(0);
});
it('sanitizes transport failures with private data in the error message', async () => {
  dependencies = {...dependencies, reader: {...dependencies.reader, backups: async () => {
    throw Error('private-member-001 private-session-001 private-history-secret');
  }}};
  await expect(invoke()).rejects.toMatchObject({code: 'unavailable', message: 'Exercise insights are temporarily unavailable.'});
});
