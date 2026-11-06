import {FieldPath, type Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import type {DocumentData, DocumentStore, TransactionPort} from '../../platform/firestore/store';
import {requiredIdentifier} from '../../platform/validation';
import {digestOf, object} from '../workouts/workout-backup-validation';
import type {AttestedWorkoutEvidenceBatch, EvidenceWindow, ReviewedEvidenceLearningPolicy} from '../recommendation/evidence-learning-need';
import {evidenceLearningPolicyFingerprint} from '../recommendation/evidence-learning-need';
import type {EvidenceRow, EvidenceScope, FreshAuthIdentity, InsightsRequest} from '../recommendation/exercise-insights-contracts';
import {evaluateRecommendationConsentV2, type ReviewedConsentNoticePolicy} from '../recommendation/recommendation-consent-v2';
import {readRecommendationMemberState} from '../recommendation/recommendation-queue-security';
import {fypDigest} from './fyp-dataset';
import {extractFypObservationEvidence} from './fyp-observations';
import {requireFypObservationScope, requireFypScope, type FypRuntimeCapability, type FypScope} from './fyp-scope';

export interface FypEvidenceSource {
  window: EvidenceWindow; observationPathsByMember: Record<string, string[]>; observationTimesByPath: Record<string, number>;
  policyByMember: Record<string, string>; policyPaths: Record<string, string>; members: {memberId: string}[];
}
export interface FypEvidenceReaderOptions {
  db: Firestore; scope: FypScope; store: DocumentStore; fypCapability: FypRuntimeCapability; source: FypEvidenceSource;
  noticePolicies: readonly ReviewedConsentNoticePolicy[]; clock: () => number;
  readAuthIdentity: (uid: string) => Promise<FreshAuthIdentity & {creationTimeMillis: number}>;
}
type ReadTx = Pick<TransactionPort, 'get'>;
const unavailable = () => new DomainError('failed-precondition', 'Fictional workout sources require review.');
const denied = () => new DomainError('permission-denied', 'Current fictional workout access is required.');

/** Server-owned physical query adapter. No SDK creation, arbitrary paths, camera claims or writes. */
export function createFypEvidenceReader(options: FypEvidenceReaderOptions) {
  const {db, scope: actor, store, fypCapability, source, noticePolicies, readAuthIdentity, clock} = options;
  requireFypScope(actor);
  const root = actor.rootPath;
  const logical = (path: string) => {
    if (!path.startsWith(root + '/') || path.split('/').some(p => !/^[A-Za-z0-9_-]{1,128}$/.test(p))) throw unavailable();
    return `orgs/gainpath/${path.slice(root.length + 1)}`;
  };
  const authorizeScope = (scope: EvidenceScope) => {
    requiredIdentifier(scope.memberId, 'member');
    requireFypObservationScope(fypCapability, scope.organizationId, scope.memberId);
    if (!source.members.some(m => m.memberId === scope.memberId)) throw denied();
  };
  const pathsFor = (memberId: string) => {
    const paths = source.observationPathsByMember[memberId];
    if (!Array.isArray(paths) || paths.length > 100 || new Set(paths).size !== paths.length || paths.some(p => !p.startsWith(`${root}/members/${memberId}/syntheticObservations/`) || p.split('/').length !== root.split('/').length + 4)) throw unavailable();
    for (const p of paths) {logical(p); if (!Number.isSafeInteger(source.observationTimesByPath[p]) || source.observationTimesByPath[p] < 0) throw unavailable();}
    return paths;
  };
  const validWindow = (window: EvidenceWindow, presentation = false) => {
    if (!Number.isSafeInteger(window.startAtMillis) || window.startAtMillis < 0 || !Number.isSafeInteger(window.endAtMillis)
        || window.endAtMillis > clock() || window.endAtMillis <= window.startAtMillis || window.endAtMillis - window.startAtMillis > 90 * 86400000
        || !presentation && (window.startAtMillis < source.window.startAtMillis || window.endAtMillis > source.window.endAtMillis)) throw unavailable();
  };
  const fresh = async (target: EvidenceScope) => {
    authorizeScope(target);
    for (const uid of new Set([actor.uid, target.memberId])) {
      const identity = await readAuthIdentity(uid);
      if (identity.uid !== uid || identity.disabled || !identity.emailVerified || !Number.isSafeInteger(identity.creationTimeMillis)
          || identity.creationTimeMillis <= 0 || !Number.isFinite(identity.tokensValidAfterMillis)
          || uid === actor.uid && identity.creationTimeMillis !== actor.authCreatedAtMillis) throw denied();
    }
  };
  const memberState = async (tx: ReadTx, target: EvidenceScope) => {
    const user = await tx.get(`users/${target.memberId}`), member = await tx.get(`orgs/gainpath/members/${target.memberId}`);
    if (user?.organizationId !== target.organizationId || user.role !== 'member' || user.status !== 'active'
        || member?.organizationId !== target.organizationId || member.userId !== target.memberId || member.role !== 'member' || member.status !== 'active') throw denied();
    return digestOf({user, member});
  };
  const permitted = async (tx: ReadTx, target: EvidenceScope, window: EvidenceWindow, generation: boolean) => {
    const purposes = generation ? ['exerciseInsights', 'recommendationGeneration'] as const : ['exerciseInsights'] as const;
    const state = await readRecommendationMemberState(tx, target, clock(), noticePolicies, purposes);
    if (!state.eligible) throw denied();
    const consent = await tx.get(`orgs/gainpath/recommendationConsent/${target.memberId}`);
    for (const purpose of purposes) {
      const decision = evaluateRecommendationConsentV2(consent, target, clock(), noticePolicies, purpose);
      if (!decision.allowed || decision.historyStartAtMillis === undefined || window.startAtMillis < decision.historyStartAtMillis) throw denied();
    }
    return state.fingerprint;
  };
  function wire(path: string, data: DocumentData, target: EvidenceScope): EvidenceRow {
    const id = path.split('/').at(-1)!;
    if (Object.keys(data).some(k => !['schemaVersion', 'organizationId', 'memberId', 'observationId', 'seedId', 'provenance', 'payload', 'digest', 'observedAtMillis'].includes(k))
        || data.schemaVersion !== 1 || data.organizationId !== target.organizationId || data.memberId !== target.memberId || data.observationId !== id
        || data.seedId !== actor.seedId || data.provenance !== 'fictional_synthetic' || !Number.isSafeInteger(data.observedAtMillis)) throw unavailable();
    const row: EvidenceRow = {id: `session-${id}`, data: {schemaVersion: 1, classification: 'fictional_synthetic_observation', kind: 'session', id, key: `session-${id}`,
      payloadJson: JSON.stringify(data.payload), digest: data.digest, updatedAtMillis: data.observedAtMillis}};
    extractFypObservationEvidence(target, row, clock(), fypCapability); return row;
  }
  async function owned(tx: ReadTx, path: string, target: EvidenceScope, snapshot?: DocumentData) {
    const data = await tx.get(logical(path)), ownership = await tx.get(`orgs/gainpath/seedOwnership/${fypDigest(path)}`);
    if (!data || !ownership || ownership.schemaVersion !== 1 || ownership.seedId !== actor.seedId || ownership.path !== path
        || ownership.digest !== fypDigest(data) || snapshot && fypDigest(data) !== fypDigest(snapshot)) throw unavailable();
    return {metadata: {id: path.split('/').at(-1)!, data}, row: wire(path, data, target)};
  }
  async function load(target: EvidenceScope, window: EvidenceWindow, generation: boolean | undefined) {
    // Presentation may end after the frozen fixture anchor. The entire requested
    // range still needs current consent; queried paths must exactly match the
    // immutable approved inventory. Generation/revalidation retain source bounds.
    authorizeScope(target); validWindow(window, generation === false); const approved = new Set(pathsFor(target.memberId)); await fresh(target);
    const gate = (tx: ReadTx) => generation === undefined ? memberState(tx, target) : permitted(tx, target, window, generation);
    const initial = await store.transact(gate);
    const result = await db.collection(`${root}/members/${target.memberId}/syntheticObservations`)
      .where('observedAtMillis', '>=', window.startAtMillis).where('observedAtMillis', '<', window.endAtMillis)
      .orderBy('observedAtMillis').orderBy(FieldPath.documentId()).limit(101).get();
    if (result.size > 100) throw new DomainError('resource-exhausted', 'Fictional workout source exceeds its reviewed bound.');
    const expected = [...approved].filter(p => source.observationTimesByPath[p] >= window.startAtMillis && source.observationTimesByPath[p] < window.endAtMillis).sort();
    if (digestOf(result.docs.map(doc => doc.ref.path).sort()) !== digestOf(expected)) throw unavailable();
    const pairs = await store.transact(async tx => {
      if (await gate(tx) !== initial) throw denied();
      const out = [];
      for (const doc of result.docs) {
        if (doc.ref.path !== `${root}/members/${target.memberId}/syntheticObservations/${doc.id}` || !approved.has(doc.ref.path)) throw unavailable();
        const pair = await owned(tx, doc.ref.path, target, doc.data());
        if (pair.metadata.data.observedAtMillis !== source.observationTimesByPath[doc.ref.path]) throw unavailable();
        out.push(pair);
      }
      return out;
    });
    await fresh(target);
    await store.transact(async tx => {if (await gate(tx) !== initial) throw denied();});
    pairs.sort((a, b) => a.row.id.localeCompare(b.row.id));
    return pairs;
  }
  async function read(target: EvidenceScope, window: EvidenceWindow, generation: boolean): Promise<AttestedWorkoutEvidenceBatch> {
    if (typeof generation !== 'boolean') throw denied();
    const pairs = await load(target, window, generation), rows = pairs.map(p => p.row), metadata = pairs.map(p => p.metadata);
    return {schemaVersion: 1, scope: {...target}, window: {...window}, sourceRevision: digestOf({metadata, rows}), rows,
      attestations: pairs.map(({row}) => ({rowId: row.id, organizationId: target.organizationId, memberId: target.memberId,
        recordKey: String(row.data.key), digest: String(row.data.digest), updatedAtMillis: Number(row.data.updatedAtMillis),
        capturedAtMillis: Number(row.data.updatedAtMillis), trust: 'cohort_synthetic_observation'}))};
  }
  async function revalidate(tx: ReadTx, target: EvidenceScope, revision: string, policyFingerprint: string): Promise<boolean> {
    try {
      authorizeScope(target); validWindow(source.window); await permitted(tx, target, source.window, true);
      const pairs = [];
      for (const path of pathsFor(target.memberId)) {
        const pair = await owned(tx, path, target), at = Number(pair.metadata.data.observedAtMillis);
        if (at !== source.observationTimesByPath[path]) return false;
        if (at >= source.window.startAtMillis && at < source.window.endAtMillis) pairs.push(pair);
      }
      pairs.sort((a, b) => a.row.id.localeCompare(b.row.id));
      const id = source.policyByMember[target.memberId], policyPath = source.policyPaths[id];
      if (!policyPath) return false;
      const policy = await tx.get(logical(policyPath));
      if (!policy || evidenceLearningPolicyFingerprint(policy as unknown as ReviewedEvidenceLearningPolicy) !== policyFingerprint) return false;
      return digestOf({metadata: pairs.map(p => p.metadata), rows: pairs.map(p => p.row)}) === revision;
    } catch {return false;}
  }
  async function rows(memberId: string): Promise<EvidenceRow[]> {return (await load({organizationId: actor.organizationId, memberId}, source.window, undefined)).map(p => p.row);}
  async function history(request: InsightsRequest) {
    if (actor.role !== 'member' || !request.app?.appId || request.auth?.uid !== actor.uid || request.auth.token.email_verified !== true
        || request.auth.token.fypAuthCreatedAtMillis !== actor.authCreatedAtMillis || typeof request.auth.token.email !== 'string' || !Number.isSafeInteger(request.auth.token.auth_time)) throw denied();
    const data = object(request.data);
    if (data.schemaVersion !== 1 || Object.keys(data).some(k => !['schemaVersion', 'organizationId'].includes(k))
        || data.organizationId !== undefined && data.organizationId !== actor.organizationId) throw denied();
    const identity = await readAuthIdentity(actor.uid);
    if (identity.email !== request.auth.token.email || Number(request.auth.token.auth_time) * 1000 < identity.tokensValidAfterMillis) throw denied();
    return {schemaVersion: 1 as const, fictional: true as const, provenance: 'recordedFixture' as const,
      records: (await rows(actor.uid)).map(row => ({kind: 'session' as const, payload: JSON.parse(String(row.data.payloadJson)) as DocumentData})), nextCursor: null};
  }
  return {read, revalidate, rows, history};
}
