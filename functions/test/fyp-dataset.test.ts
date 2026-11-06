import {describe, expect, it} from 'vitest';
import {buildFypDataset, FYP_ROOT, fypDigest, validateFypDataset} from '../src/modules/dataset/fyp-dataset';
import {workoutPrograms} from '../src/modules/content/workout-programs';
import {MemoryStore} from './memory-store';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {keyOf} from '../src/platform/idempotency';

const anchorMillis = Date.parse('2026-11-03T04:00:00Z');
describe('unified fictional source graph', () => {
  it('builds deterministically with all physical data isolated and without outcomes or camera claims', async () => {
    const a = await buildFypDataset({anchorMillis}), b = await buildFypDataset({anchorMillis});
    expect(a).toEqual(b);
    expect(a.documents[`${FYP_ROOT}/module13DemoSource/current`].noticePolicies).toEqual(a.noticePolicies);
    expect(validateFypDataset(a)).toMatchObject({valid: true, identities: 27, members: 18, coaches: 8, tutorials: 12, programs: 3, observations: 52});
    expect(Object.keys(a.documents).every(p => p === FYP_ROOT || p.startsWith(`${FYP_ROOT}/`))).toBe(true);
    expect(Object.keys(a.documents).some(p => /workoutBackups|workoutEvidenceCaptures|recommendationLeads|recommendationRecipients|DeliveryReceipts|\/notifications\//.test(p))).toBe(false);
    for (const row of a.observations) {
      expect(row.data).toMatchObject({schemaVersion: 1, provenance: 'fictional_synthetic', payload: {provenance: 'recordedFixture'}});
      expect(row.data.digest).toBe(digestOf(row.data.payload));
    }
  });
  it('completes normal profile, catalog, blueprint and private Coach schemas', async () => {
    const d = await buildFypDataset({anchorMillis});
    for (const uid of d.memberIds) expect(d.documents[`${FYP_ROOT}/profiles/${uid}`]).toMatchObject({createdAt: expect.any(Date), updatedAt: expect.any(Date), profileCompletedAt: expect.any(Date)});
    for (const uid of d.memberIds) expect(d.documents[`${FYP_ROOT}/profiles/${uid}/goals/fyp-training-frequency`]).toMatchObject({category: 'trainingFrequency', targetValue: 3, revision: 1});
    for (const uid of d.coachIds) expect(d.documents[`${FYP_ROOT}/coachProfiles/${uid}`]).toMatchObject({schemaVersion: 1, revision: 1, displayName: expect.any(String), bio: expect.any(String)});
    for (const [p, value] of Object.entries(d.documents)) if (/\/(exerciseVideos|routineBlueprints)\//.test(p)) {
      expect(value.createdAt).toBeInstanceOf(Date); expect(value.updatedAt).toBeInstanceOf(Date);
      expect(value).not.toHaveProperty('createdAtMillis');
    }
  });
  it('lists genuine 28-day service publications and keeps independent consent scenarios', async () => {
    const d = await buildFypDataset({anchorMillis}), store = new MemoryStore();
    // Reverse translation is test-only: production uses its server-authorized scoped store.
    for (const [p, value] of Object.entries(d.documents)) {
      const relative = p.slice(FYP_ROOT.length);
      store.documents.set(relative.startsWith('/users/') ? relative.slice(1) : `orgs/gainpath${relative}`, value);
    }
    const result = await workoutPrograms(store, {uid: d.memberIds[0], token: {email_verified: true}}, {schemaVersion: 1, organizationId: 'gainpath', action: 'list'}, {freshAuth: async () => undefined});
    expect(result.programs).toHaveLength(3);
    for (const p of result.programs) expect(p.days).toHaveLength(28);
    const off = d.memberScenarios.find(m => m.scenario === 'all_purposes_off')!;
    expect(d.documents[`${FYP_ROOT}/recommendationConsent/${off.memberId}`]).toBeUndefined();
    const revoked = d.memberScenarios.find(m => m.scenario === 'generation_revoked')!;
    expect(d.documents[`${FYP_ROOT}/recommendationConsent/${revoked.memberId}`]).toMatchObject({purposes: {recommendationGeneration: {granted: false}}});
  });
  it('uses actual Routine publisher IDs, receipts and complete instructional snapshots', async () => {
    const d = await buildFypDataset({anchorMillis});
    expect(d.source.publicationIds).toEqual(d.publicationIds);
    for (const id of d.publicationIds) {
      expect(id).toMatch(/^routine_demo-m13-tutorial-\d{2}-blueprint$/);
      const publication = d.documents[`${FYP_ROOT}/content/${id}`], blueprintId = String(publication.sourceBlueprintId);
      expect(publication).toMatchObject({schemaVersion: 1, status: 'published', publishedAtMillis: anchorMillis - 86400000});
      const receipt = d.documents[`${FYP_ROOT}/commandReceipts/${keyOf('publishRoutine', d.adminId, `fyp-publish-${blueprintId}`)}`];
      expect(receipt).toMatchObject({result: {contentId: id, sourceBlueprintId: blueprintId, status: 'published'}});
      expect((publication.exercises as Record<string, unknown>[])[0].tutorialSteps).toHaveLength(3);
      expect(d.contentSource.suitability.find(s => s.publicationId === id)?.publicationDigest).toBe(digestOf(publication));
    }
    expect(Object.keys(d.documents).filter(p => p.startsWith(`${FYP_ROOT}/content/`))).toHaveLength(12);
    expect(d.legacyDataset.publicationIds.every(id => d.documents[`${FYP_ROOT}/content/${id}`] === undefined)).toBe(true);
    const foundation = d.documents[`${FYP_ROOT}/workoutProgramVersions/fyp-foundations_v1`].program as {days: {kind: string; category: string; muscleGroups: string[]}[]};
    expect(foundation.days.filter(day => day.kind === 'workout').every(day => day.category === 'Lower Body' && day.muscleGroups.join() === 'lower')).toBe(true);
  });
  it('rejects a changed observation and an invalid anchor', async () => {
    const d = await buildFypDataset({anchorMillis});
    d.observations[0].data.digest = '0'.repeat(64);
    expect(() => validateFypDataset(d)).toThrow();
    await expect(buildFypDataset({anchorMillis: NaN})).rejects.toThrow();
  });
});
