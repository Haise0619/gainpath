import {expect, it} from 'vitest';
import {buildFypDataset, FYP_ROOT} from '../src/modules/dataset/fyp-dataset';
import {createFypScopedStore, mintFypRuntimeCapability, resolveFypScope} from '../src/modules/dataset/fyp-scope';
import {evaluateTrainerCandidates} from '../src/modules/recommendation/trainer-candidate-eligibility';
import {deriveEvidenceLearningNeed, type AttestedWorkoutEvidenceBatch} from '../src/modules/recommendation/evidence-learning-need';
import {MemoryStore} from './memory-store';
import {evaluateContentCandidates} from '../src/modules/recommendation/content-candidate-eligibility';

it('derives a real fictional learning need and retains multiple currently eligible scoped Coaches', async () => {
  const now = Date.parse('2026-11-03T04:00:00Z'), d = await buildFypDataset({anchorMillis: now}), base = new MemoryStore();
  for (const [p, v] of Object.entries(d.documents)) base.documents.set(p, v);
  base.documents.set(`datasetAssignments/${d.adminId}`, {schemaVersion: 1, organizationId: 'gainpath', datasetId: 'fyp-v1', seedId: d.seedId, role: 'admin', enabled: true, revision: 1, authCreatedAtMillis: now - 1000});
  const actor = d.identities.find(u => u.uid === d.adminId)!;
  const scope = await resolveFypScope({app: {appId: 'test'}, auth: {uid: actor.uid, token: {email_verified: true, email: actor.email, auth_time: now / 1000, fypAuthCreatedAtMillis: now - 1000}}, data: {schemaVersion: 1}},
    {store: base, identity: async () => ({...actor, creationTimeMillis: now - 1000, tokensValidAfterMillis: 0})});
  const store = createFypScopedStore(base, scope), capability = mintFypRuntimeCapability(scope), member = d.memberScenarios[0];
  const target = {organizationId: 'gainpath', memberId: member.memberId}, observations = d.observations.filter(o => o.memberId === member.memberId);
  const rows = observations.map(o => ({id: `session-${o.observationId}`, data: {schemaVersion: 1, classification: 'fictional_synthetic_observation', kind: 'session', id: o.observationId, key: `session-${o.observationId}`,
    payloadJson: JSON.stringify(o.data.payload), digest: o.data.digest, updatedAtMillis: o.data.observedAtMillis}}));
  const batch: AttestedWorkoutEvidenceBatch = {schemaVersion: 1, scope: target, window: d.legacyDataset.window, sourceRevision: 'a'.repeat(64), rows,
    attestations: rows.map(row => ({rowId: row.id, organizationId: 'gainpath', memberId: member.memberId, recordKey: row.data.key, digest: String(row.data.digest), updatedAtMillis: Number(row.data.updatedAtMillis), capturedAtMillis: Number(row.data.updatedAtMillis), trust: 'cohort_synthetic_observation'}))};
  const policy = d.policies.find(p => p.policyId === member.policyId)!;
  const derived = deriveEvidenceLearningNeed(target, batch, policy, d.legacyDataset.window, now, capability);
  expect(derived).toMatchObject({status: 'derived', need: {exercise: 'squat', objective: 'technique_foundations'}});
  const result = await evaluateTrainerCandidates({schemaVersion: 1, organizationId: 'gainpath', memberId: member.memberId, exerciseId: member.exerciseId, learningObjective: member.objective, level: member.level, localDate: d.legacyDataset.bookingDate, durationMinutes: 60},
    {repository: {transact: work => store.transact(work), listCoachIds: async () => d.coachIds}, trustedExpertise: d.expertise, clock: () => now,
      readIdentity: async uid => ({exists: d.identities.some(u => u.uid === uid), emailVerified: true, disabled: false})});
  expect(result.candidates.length, JSON.stringify(result.rejected)).toBeGreaterThanOrEqual(3);
  expect(result.rejected).toContainEqual({candidateId: d.coachIds[7], reason: 'coach_unavailable'});
  const tutorials = evaluateContentCandidates({organizationId: 'gainpath', exerciseId: member.exerciseId, objective: member.objective, level: member.level}, d.contentSource);
  expect(tutorials.candidates.length, JSON.stringify(tutorials.rejected)).toBeGreaterThanOrEqual(3);
  expect(tutorials.candidates.every(c => d.publicationIds.includes(c.destination.routineId))).toBe(true);
  // Physical documents retain logical domain Storage references used by the unchanged validator.
  for (const [path, data] of Object.entries(d.documents)) if (path.includes('/certifications/')) expect(String(data.storagePath)).toMatch(/^orgs\/gainpath\/coachCertifications\//);
});
