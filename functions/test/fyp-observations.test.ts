import {beforeAll, describe, expect, it} from 'vitest';
import {buildFypDataset, FYP_ROOT, type FypDataset} from '../src/modules/dataset/fyp-dataset';
import {mintFypRuntimeCapability, resolveFypScope, type FypRuntimeCapability} from '../src/modules/dataset/fyp-scope';
import {extractFypObservationEvidence} from '../src/modules/dataset/fyp-observations';
import {digestOf, validateBackupPayload, validateFictionalSessionPayload} from '../src/modules/workouts/workout-backup-validation';
import {MemoryStore} from './memory-store';
const now = Date.parse('2026-11-03T04:00:00Z');
let dataset: FypDataset, capability: FypRuntimeCapability;
beforeAll(async () => {
  dataset = await buildFypDataset({anchorMillis: now}); const store = new MemoryStore(), uid = dataset.adminId;
  for (const [p, d] of Object.entries(dataset.documents)) store.documents.set(p, d);
  store.documents.set(`datasetAssignments/${uid}`, {schemaVersion: 1, organizationId: 'gainpath', datasetId: 'fyp-v1', seedId: dataset.seedId, role: 'admin', enabled: true, revision: 1, authCreatedAtMillis: now - 1000});
  const scope = await resolveFypScope({app: {appId: 'emulator-test'}, auth: {uid, token: {email_verified: true, email: dataset.identities[0].email, auth_time: Math.floor(now / 1000), fypAuthCreatedAtMillis: now - 1000}}, data: {schemaVersion: 1}},
    {store, identity: async () => ({uid, email: dataset.identities[0].email, emailVerified: true, disabled: false, creationTimeMillis: now - 1000, tokensValidAfterMillis: 0})});
  capability = mintFypRuntimeCapability(scope);
});
function source(index = 0) {
  const row = dataset.observations[index], payload = structuredClone(row.data.payload) as Record<string, unknown>, id = String(payload.sessionId);
  return {scope: {organizationId: 'gainpath', memberId: row.memberId}, row: {id, data: {schemaVersion: 1, classification: 'fictional_synthetic_observation', kind: 'session', id, key: `session-${id}`, payloadJson: JSON.stringify(payload), digest: digestOf(payload), updatedAtMillis: row.data.observedAtMillis}}, payload};
}
describe('honest fictional observation projection', () => {
  it('retains provenance and reuses compatible scored measurement projection', () => {
    const {scope, row, payload} = source(), before = structuredClone(row);
    const evidence = extractFypObservationEvidence(scope, row, now, capability);
    expect(evidence).toMatchObject({kind: 'session', formScorePercent: 56, assessedAttempts: 10, trackingCoverage: .8, compatibility: {scoreSupport: 'scored'}});
    expect(row).toEqual(before); expect(payload.provenance).toBe('recordedFixture');
    expect(() => validateBackupPayload('session', row.id, scope.organizationId, scope.memberId, payload)).toThrow('Only measured local summaries');
    expect(validateFictionalSessionPayload(row.id, scope.organizationId, scope.memberId, payload)).toBe(payload);
  });
  it('keeps unscored/null evidence honest without fabricating a score', () => {
    const index = dataset.observations.findIndex(r => (r.data.payload as Record<string, unknown>).exerciseId === 'bodyweight-reverse-lunge-side-v1');
    const {scope, row} = source(index);
    expect(extractFypObservationEvidence(scope, row, now, capability)).toMatchObject({formScorePercent: null, compatibility: {scoreSupport: 'unscored'}});
  });
  it.each(['missing-capability', 'spoofed-capability', 'camera-provenance', 'foreign-owner', 'future-date', 'bad-digest', 'malformed-metrics', 'null-payload'])('rejects %s without projection', mode => {
    const {scope, row, payload} = source();
    let cap: FypRuntimeCapability | undefined = capability;
    if (mode === 'missing-capability') cap = undefined;
    if (mode === 'spoofed-capability') cap = {};
    if (mode === 'camera-provenance') payload.provenance = 'realCamera';
    if (mode === 'foreign-owner') payload.userId = 'someone-else';
    if (mode === 'future-date') {payload.startedAt = new Date(now + 1000).toISOString(); payload.endedAt = new Date(now + 11000).toISOString(); row.data.updatedAtMillis = now + 11000;}
    if (mode === 'malformed-metrics') (payload.poseMetrics as Record<string, unknown>).trackedDurationMicros = -1;
    row.data.payloadJson = JSON.stringify(mode === 'null-payload' ? null : payload); row.data.digest = digestOf(payload);
    if (mode === 'bad-digest') row.data.digest = '0'.repeat(64);
    expect(() => extractFypObservationEvidence(scope, row, now, cap)).toThrow();
  });
});
