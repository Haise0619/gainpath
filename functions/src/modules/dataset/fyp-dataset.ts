/** Pure fictional graph compiler. This module never initializes a Firebase client. */
import {fypDigest} from './fyp-integrity';
export {fypDigest} from './fyp-integrity';
import type {DocumentData, DocumentStore, TransactionPort} from '../../platform/firestore/store';
import {buildModule13DemoDataset, type DemoAuthUser, type Module13DemoDataset} from '../recommendation/demo-dataset';
import {createRecommendationConsentV2Command} from '../recommendation/recommendation-consent-v2';
import {workoutPrograms} from '../content/workout-programs';
import {digestOf} from '../workouts/workout-backup-validation';
import {publishRoutine} from '../content/publish-routine';

export const FYP_SEED_ID = 'gainpath-fyp-v1';
export const FYP_DATASET_ID = 'fyp-v1';
export const FYP_ROOT = 'orgs/gainpath/cohorts/fyp-v1';
export const FYP_EMULATOR_PROJECT = 'demo-gainpath-fyp';
export const FYP_PROPOSED_LIVE_PROJECT = 'gainpath-0619';
const DAY = 86400000;
export type FypIdentity = DemoAuthUser & {role: 'admin' | 'coach' | 'member'};
export interface FypObservation {path: string; data: DocumentData; memberId: string; observationId: string}
export interface FypDataset {
  schemaVersion: 1; seedId: typeof FYP_SEED_ID; datasetId: typeof FYP_DATASET_ID; rootPath: typeof FYP_ROOT;
  organizationId: 'gainpath'; anchorMillis: number; identities: FypIdentity[]; documents: Record<string, DocumentData>;
  observations: FypObservation[]; memberScenarios: Module13DemoDataset['memberScenarios'];
  memberIds: string[]; coachIds: string[]; adminId: string; publicationIds: string[]; programIds: string[];
  legacyDataset: Module13DemoDataset; legacyManifest: Module13DemoDataset['manifest']; source: DocumentData;
  expertise: Module13DemoDataset['expertise']; policies: Module13DemoDataset['policies'];
  contentSource: Module13DemoDataset['contentSource']; noticePolicies: Module13DemoDataset['noticePolicies'];
  counts: Record<string, number>; digest: string;
}

function physical(path: string): string {
  if (path === 'orgs/gainpath') return FYP_ROOT;
  if (path.startsWith('orgs/gainpath/')) return `${FYP_ROOT}/${path.slice('orgs/gainpath/'.length)}`;
  if (/^(users|module13DemoSource)\//.test(path)) return `${FYP_ROOT}/${path}`;
  throw new Error('Unreviewed fictional source path');
}
function scopedCompiler(documents: Record<string, DocumentData>): DocumentStore {
  return {transact: async <T>(work: (tx: TransactionPort) => Promise<T>) => {
    const writes = new Map<string, DocumentData>(); let writing = false;
    const result = await work({get: async p => {if (writing) throw new Error('Read after write'); return structuredClone(documents[physical(p)]);},
      create: (p, d) => {const path = physical(p); if (documents[path] || writes.has(path)) throw new Error('Source collision'); writing = true; writes.set(path, structuredClone(d) as DocumentData);},
      set: (p, d) => {writing = true; writes.set(physical(p), structuredClone(d) as DocumentData);}});
    for (const [p, d] of writes) documents[p] = d;
    return result;
  }};
}

export async function buildFypDataset(options: {anchorMillis: number}): Promise<FypDataset> {
  const anchorMillis = options.anchorMillis;
  if (!Number.isSafeInteger(anchorMillis) || anchorMillis < 1700000000000 || anchorMillis > 4102444800000) throw new Error('Explicit bounded date anchor required');
  const legacy = await buildModule13DemoDataset({nowMillis: anchorMillis});
  const publicationIds = legacy.publicationIds.map(id => `routine_${String(legacy.documents[`orgs/gainpath/content/${id}`].sourceBlueprintId)}`);
  const publicationRemap = Object.fromEntries(legacy.publicationIds.map((id, i) => [id, publicationIds[i]]));
  const documents: Record<string, DocumentData> = {}, observations: FypObservation[] = [];
  for (const [path, raw] of Object.entries(legacy.documents)) {
    if (!/^(orgs\/gainpath(?:\/|$)|users\/|module13DemoSource\/)/.test(path)
        || /\/(content|workoutBackups|workoutEvidenceCaptures|recommendationConsent|recommendationConsentAudit|recommendationConsentReceipts)\//.test(path)) continue;
    const d = structuredClone(raw);
    if (path.startsWith('users/')) d.status = 'active';
    if (path.includes('/profiles/')) Object.assign(d, {createdAt: new Date(anchorMillis - 40 * DAY), updatedAt: new Date(anchorMillis - DAY), profileCompletedAt: new Date(anchorMillis - 40 * DAY)});
    if (/\/(exerciseVideos|routineBlueprints)\//.test(path)) {
      d.createdAt = new Date(Number(d.createdAtMillis ?? anchorMillis - 2 * DAY));
      d.updatedAt = new Date(Number(d.updatedAtMillis ?? anchorMillis - DAY));
      delete d.createdAtMillis; delete d.updatedAtMillis;
      if (path.includes('/routineBlueprints/')) d.updatedBy = legacy.adminId;
    }
    if (path.includes('/certifications/')) {
      // These are disclosed metadata fixtures, never physical qualification/upload attestations.
      // Services validate logical domain references. A future Storage adapter must
      // translate them separately; Firestore namespace translation applies to documents only.
      d.storagePath = String(d.storagePath);
    }
    documents[physical(path)] = d;
  }
  for (const uid of legacy.coachIds) {
    const pub = documents[`${FYP_ROOT}/coaches/${uid}`];
    documents[`${FYP_ROOT}/coachProfiles/${uid}`] = Object.fromEntries(['displayName', 'specialty', 'bio', 'specializationTags', 'yearsExperience', 'consultationFeeMinor', 'photoPath', 'createdAtMillis', 'updatedAtMillis'].map(k => [k, pub[k]]));
    Object.assign(documents[`${FYP_ROOT}/coachProfiles/${uid}`], {schemaVersion: 1, revision: 1});
  }
  for (const row of legacy.workoutRecords.filter(r => r.kind === 'head')) {
    const payload = JSON.parse(String(legacy.documents[row.backupPath].payloadJson)) as DocumentData;
    payload.provenance = 'recordedFixture';
    const metrics = payload.poseMetrics as DocumentData;
    if (typeof metrics.publishedRoutineId === 'string' && publicationRemap[metrics.publishedRoutineId]) metrics.publishedRoutineId = publicationRemap[metrics.publishedRoutineId];
    const observationId = String(payload.sessionId), path = `${FYP_ROOT}/members/${row.memberId}/syntheticObservations/${observationId}`;
    const data: DocumentData = {schemaVersion: 1, organizationId: 'gainpath', memberId: row.memberId, observationId,
      seedId: FYP_SEED_ID, provenance: 'fictional_synthetic', payload, digest: digestOf(payload), observedAtMillis: Date.parse(String(payload.endedAt))};
    documents[path] = data; observations.push({path, data, memberId: row.memberId, observationId});
  }
  for (const uid of legacy.memberIds) {
    const goal = {schemaVersion: 1, category: 'trainingFrequency', targetValue: 3, unit: 'sessions', evaluationPeriod: 'calendarWeek', status: 'active', revision: 1,
      createdAt: new Date(anchorMillis - 5 * DAY), updatedAt: new Date(anchorMillis - 5 * DAY)};
    const path = `${FYP_ROOT}/profiles/${uid}/goals/fyp-training-frequency`;
    documents[path] = goal; documents[`${path}/revisions/1`] = structuredClone(goal);
  }
  const store = scopedCompiler(documents);
  // Publish every lesson through the actual service. Instruction edits are
  // source inputs; generated snapshots and command receipts are never fabricated.
  for (const [i, legacyId] of legacy.publicationIds.entries()) {
    const old = legacy.documents[`orgs/gainpath/content/${legacyId}`], exercise = (old.exercises as DocumentData[])[0];
    const catalogPath = `${FYP_ROOT}/exerciseVideos/${String(exercise.exerciseId)}`;
    documents[catalogPath] = {...documents[catalogPath], description: exercise.description, tutorialSteps: structuredClone(exercise.tutorialSteps)};
    const blueprintId = String(old.sourceBlueprintId);
    const result = await publishRoutine(store, {uid: legacy.adminId, token: {email_verified: true}},
      {schemaVersion: 1, organizationId: 'gainpath', blueprintId, requestId: `fyp-publish-${blueprintId}`}, () => anchorMillis - DAY);
    if (result.contentId !== publicationIds[i]) throw new Error('Routine publisher identity drift');
  }
  const suitability = legacy.suitability.map(row => ({...row, publicationId: publicationRemap[row.publicationId],
    publicationDigest: digestOf(documents[`${FYP_ROOT}/content/${publicationRemap[row.publicationId]}`])}));
  for (const row of suitability) documents[`${FYP_ROOT}/recommendationContentSuitability/${row.id}`] = row;
  // Re-run the real consent command against the scoped store; never fabricate grants.
  for (const c of legacy.consentCommands) {
    const identity = legacy.authUsers.find(u => u.uid === c.uid)!;
    await createRecommendationConsentV2Command({store, clock: () => c.nowMillis, noticePolicies: legacy.noticePolicies,
      readAuthIdentity: async () => ({...identity, tokensValidAfterMillis: 0})})({app: {appId: 'server-owned-fictional-source-compiler'},
      auth: {uid: c.uid, token: {email_verified: true, email: identity.email, auth_time: Math.floor((anchorMillis - 6 * DAY) / 1000)}}, data: c.data});
  }
  const programIds = ['fyp-foundations', 'fyp-upper-practice', 'fyp-movement-control'];
  const routineIds = [publicationIds[0], publicationIds[4], publicationIds[9]];
  for (const [i, id] of programIds.entries()) {
    const program = {schemaVersion: 1, id, version: 0, title: ['Fictional foundations: four weeks', 'Fictional upper-body practice: four weeks', 'Fictional movement control: four weeks'][i], level: 'Beginner', weeks: 4,
      days: Array.from({length: 28}, (_, n) => {const workout = [0, 2, 4].includes(n % 7); return {week: Math.floor(n / 7) + 1, weekday: n % 7 + 1,
        kind: workout ? 'workout' : 'rest', category: workout ? i === 0 ? 'Lower Body' : 'Upper Body' : 'Rest', routineId: workout ? routineIds[i] : null, routineDay: 1,
        muscleGroups: workout ? i === 0 ? ['lower'] : ['upperPush', 'upperPull'] : [], restSeconds: 60};})};
    const auth = {uid: legacy.adminId, token: {email_verified: true}}, deps = {freshAuth: async () => undefined, clock: () => anchorMillis};
    await workoutPrograms(store, auth, {schemaVersion: 1, organizationId: 'gainpath', action: 'saveDraft', requestId: `${id}-save`, expectedRevision: 0, program}, deps);
    await workoutPrograms(store, auth, {schemaVersion: 1, organizationId: 'gainpath', action: 'publish', requestId: `${id}-publish`, expectedRevision: 1, programId: id}, deps);
  }
  const identities = legacy.authUsers.map(u => ({...u, role: u.uid === legacy.adminId ? 'admin' as const : legacy.coachIds.includes(u.uid) ? 'coach' as const : 'member' as const}));
  Object.assign(documents[FYP_ROOT], {schemaVersion: 1, datasetId: FYP_DATASET_ID, seedId: FYP_SEED_ID, organizationId: 'gainpath', enabled: true, status: 'active'});
  const source = {...documents[`${FYP_ROOT}/module13DemoSource/current`], seedId: FYP_SEED_ID, datasetId: FYP_DATASET_ID, rootPath: FYP_ROOT,
    publicationIds,
    noticePolicies: legacy.noticePolicies,
    observationPaths: observations.map(r => r.path), observationPathsByMember: Object.fromEntries(legacy.memberIds.map(uid => [uid, observations.filter(r => r.memberId === uid).map(r => r.path)])),
    observationTimesByPath: Object.fromEntries(observations.map(r => [r.path, r.data.observedAtMillis])),
    expertisePaths: legacy.expertise.map(e => `${FYP_ROOT}/recommendationExpertise/${e.mappingId}`),
    suitabilityPaths: legacy.suitability.map(s => `${FYP_ROOT}/recommendationContentSuitability/${s.id}`),
    policyPaths: Object.fromEntries(legacy.policies.map(p => [p.policyId, `${FYP_ROOT}/recommendationEvidencePolicies/${p.policyId}`]))};
  documents[`${FYP_ROOT}/module13DemoSource/current`] = source;
  const counts: Record<string, number> = {identities: 27, members: 18, coaches: 8, admins: 1, tutorials: 12, observations: observations.length, programs: programIds.length, goals: 18};
  for (const p of Object.keys(documents)) {const col = p.split('/').slice(0, -1).join('/'); counts[col] = (counts[col] ?? 0) + 1;}
  counts.documents = Object.keys(documents).length;
  const result: FypDataset = {schemaVersion: 1, seedId: FYP_SEED_ID, datasetId: FYP_DATASET_ID, rootPath: FYP_ROOT, organizationId: 'gainpath', anchorMillis, identities, documents, observations,
    memberScenarios: legacy.memberScenarios, memberIds: legacy.memberIds, coachIds: legacy.coachIds, adminId: legacy.adminId, publicationIds, programIds,
    legacyDataset: legacy, legacyManifest: legacy.manifest, source, expertise: legacy.expertise, policies: legacy.policies,
    contentSource: {...legacy.contentSource, suitability, catalog: legacy.contentSource.catalog.map(r => ({id: r.id, data: documents[`${FYP_ROOT}/exerciseVideos/${r.id}`]})), publications: publicationIds.map(id => ({id, data: documents[`${FYP_ROOT}/content/${id}`]}))},
    noticePolicies: legacy.noticePolicies, counts, digest: fypDigest({anchorMillis, identities, documents})};
  validateFypDataset(result); return result;
}

export function validateFypDataset(d: FypDataset) {
  if (d.seedId !== FYP_SEED_ID || d.rootPath !== FYP_ROOT || d.identities.length !== 27 || new Set(d.identities.map(u => u.uid)).size !== 27
      || d.memberIds.length !== 18 || d.coachIds.length !== 8 || d.publicationIds.length !== 12 || d.programIds.length !== 3
      || Object.keys(d.documents).some(p => p !== FYP_ROOT && !p.startsWith(`${FYP_ROOT}/`))
      || Object.keys(d.documents).some(p => /workoutBackups|workoutEvidenceCaptures|recommendationLeads|recommendationRecipients|DeliveryReceipts|\/notifications\//.test(p))) throw new Error('Fictional source graph boundary failed');
  for (const r of d.observations) {
    const p = r.data.payload as DocumentData;
    if (r.data.provenance !== 'fictional_synthetic' || p.provenance !== 'recordedFixture' || r.data.seedId !== FYP_SEED_ID
        || p.userId !== r.memberId || p.sessionId !== r.observationId || p.organizationId !== 'gainpath' || r.data.digest !== digestOf(p)
        || r.path !== `${FYP_ROOT}/members/${r.memberId}/syntheticObservations/${r.observationId}` || !Number.isFinite(r.data.observedAtMillis)) throw new Error('Fictional observation integrity failed');
  }
  if (d.digest !== fypDigest({anchorMillis: d.anchorMillis, identities: d.identities, documents: d.documents})) throw new Error('Source manifest content changed');
  return {valid: true as const, identities: d.identities.length, members: d.memberIds.length, coaches: d.coachIds.length, tutorials: d.publicationIds.length, programs: d.programIds.length, observations: d.observations.length, documents: Object.keys(d.documents).length};
}
