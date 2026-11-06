import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError, type ErrorCode} from '../../platform/errors';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import type {DocumentStore} from '../../platform/firestore/store';
import {authorizeAdminReport} from '../analytics/admin-reporting';
import {digestOf, keys, object} from '../workouts/workout-backup-validation';
import type {ExerciseCompatibility, FreshAuthIdentity, InsightsAuth, InsightsRequest, ProvisionalSamplePolicy} from './exercise-insights-contracts';

/** Review authority comes only from trusted server composition, never an Admin payload. */
export interface ReviewedRecommendationPolicy {
  readonly policyId: string;
  readonly reviewVersion: string;
  readonly compatibility: ExerciseCompatibility;
  readonly provisionalSamplePolicy: ProvisionalSamplePolicy | null;
  readonly attentionThreshold: {readonly operator: 'score_below'; readonly estimatedFormScorePercent: number} | null;
  /** A descriptive cohort minimum, neither privacy disclosure nor recommendation eligibility. */
  readonly cohortEligibility: {readonly minimumMembersMeetingProvisionalMinimums: number} | null;
}
export interface RecommendationConfiguration {
  readonly schemaVersion: 1;
  readonly organizationId: string;
  readonly revision: number;
  readonly policies: readonly ReviewedRecommendationPolicy[];
  readonly activation: {readonly generation: false; readonly externalAi: false; readonly matching: false; readonly delivery: false};
}
export interface RecommendationCommandDependencies {
  readonly store: DocumentStore;
  readonly readAuthIdentity: (uid: string) => Promise<FreshAuthIdentity>;
  readonly clock?: () => number;
}
export interface RecommendationConfigurationDependencies extends RecommendationCommandDependencies {
  readonly reviewedPolicies?: readonly ReviewedRecommendationPolicy[];
}
const integer = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) >= 0;
const messages: Partial<Record<ErrorCode, string>> = {
  unauthenticated: 'Current verified sign-in and App Check are required.',
  'permission-denied': 'Current organization access is required.',
  'invalid-argument': 'Invalid recommendation command.',
  'failed-precondition': 'Recommendation policy requires server review.',
  aborted: 'Recommendation revision changed. Reload and retry.',
  unavailable: 'Recommendation settings are temporarily unavailable.',
};
/** Shared guard for these local-only commands. Does not export a callable or adapter. */
export async function authorizeRecommendationSession(request: InsightsRequest, deps: RecommendationCommandDependencies): Promise<InsightsAuth> {
  if (!request.app || typeof request.app.appId !== 'string' || !request.app.appId.trim() || !request.auth) {
    throw new DomainError('unauthenticated', 'App verification and sign-in required.');
  }
  requireVerifiedEmail(request.auth);
  const auth = request.auth;
  requiredIdentifier(auth.uid, 'actor');
  if (typeof auth.token.email !== 'string' || !auth.token.email || !integer(auth.token.auth_time)) {
    throw new DomainError('unauthenticated', 'Verified session required.');
  }
  const fresh = await deps.readAuthIdentity(auth.uid);
  if (!fresh || fresh.uid !== auth.uid || fresh.disabled !== false || fresh.emailVerified !== true ||
    fresh.email !== auth.token.email || !integer(fresh.tokensValidAfterMillis) ||
    auth.token.auth_time * 1000 < fresh.tokensValidAfterMillis) {
    throw new DomainError('unauthenticated', 'Account session changed.');
  }
  return auth;
}
/** Never relay SDK/provider error text, including typed provider errors. */
export function recommendationCommandError(error: unknown): DomainError {
  const code: ErrorCode = error instanceof InputValidationError ? 'invalid-argument'
    : error instanceof DomainError && messages[error.code] ? error.code : 'unavailable';
  return new DomainError(code, messages[code]!);
}
export function defaultRecommendationConfiguration(organizationId: string): RecommendationConfiguration {
  requiredIdentifier(organizationId, 'organization');
  return {schemaVersion: 1, organizationId, revision: 0, policies: [],
    activation: {generation: false, externalAi: false, matching: false, delivery: false}};
}
function validatedPolicy(raw: ReviewedRecommendationPolicy): ReviewedRecommendationPolicy {
  const p = object(raw);
  keys(p, ['policyId', 'reviewVersion', 'compatibility', 'provisionalSamplePolicy', 'attentionThreshold', 'cohortEligibility']);
  requiredIdentifier(p.policyId, 'policy'); requiredIdentifier(p.reviewVersion, 'review');
  const c = object(p.compatibility);
  keys(c, ['exerciseId', 'metricSchemaVersion', 'scoringVersion', 'detectorId', 'detectorVersion', 'cameraView', 'mode', 'scoreSupport']);
  for (const key of ['exerciseId', 'scoringVersion', 'detectorId', 'detectorVersion']) requiredIdentifier(c[key], key);
  if (!integer(c.metricSchemaVersion) || c.metricSchemaVersion < 1 ||
    typeof c.cameraView !== 'string' || !['side', 'front'].includes(c.cameraView) || typeof c.mode !== 'string' ||
    !['not_applicable', 'both', 'leftOnly', 'rightOnly', 'left', 'right'].includes(c.mode) ||
    (c.scoreSupport !== 'scored' && c.scoreSupport !== 'unscored')) throw new InputValidationError('Invalid exact compatibility.');
  if (p.provisionalSamplePolicy !== null) {
    const s = object(p.provisionalSamplePolicy);
    keys(s, ['schemaVersion', 'revision', 'minimumScoredSessions', 'minimumDistinctDays', 'minimumAssessedAttempts', 'minimumTrackingCoverage']);
    requiredIdentifier(s.revision, 'sampleRevision');
    if (s.schemaVersion !== 1 || !integer(s.minimumScoredSessions) || s.minimumScoredSessions < 1 || s.minimumScoredSessions > 2000 ||
      !integer(s.minimumDistinctDays) || s.minimumDistinctDays < 1 || s.minimumDistinctDays > s.minimumScoredSessions ||
      !integer(s.minimumAssessedAttempts) || s.minimumAssessedAttempts < 1 || s.minimumAssessedAttempts > 20000000 ||
      typeof s.minimumTrackingCoverage !== 'number' || !Number.isFinite(s.minimumTrackingCoverage) || s.minimumTrackingCoverage < 0 || s.minimumTrackingCoverage > 1) {
      throw new InputValidationError('Invalid provisional samples.');
    }
  }
  if (p.attentionThreshold !== null) {
    const t = object(p.attentionThreshold); keys(t, ['operator', 'estimatedFormScorePercent']);
    if (t.operator !== 'score_below' || typeof t.estimatedFormScorePercent !== 'number' || !Number.isFinite(t.estimatedFormScorePercent) ||
      t.estimatedFormScorePercent < 0 || t.estimatedFormScorePercent > 100 || c.scoreSupport !== 'scored' || p.provisionalSamplePolicy === null) {
      throw new InputValidationError('Invalid reviewed attention threshold.');
    }
  }
  if (p.cohortEligibility !== null) {
    const e = object(p.cohortEligibility); keys(e, ['minimumMembersMeetingProvisionalMinimums']);
    if (!integer(e.minimumMembersMeetingProvisionalMinimums) || e.minimumMembersMeetingProvisionalMinimums < 1 ||
      e.minimumMembersMeetingProvisionalMinimums > 200 || p.provisionalSamplePolicy === null) throw new InputValidationError('Invalid cohort minimum.');
  }
  return structuredClone(raw);
}
function validateCurrentConfiguration(raw: unknown, org: string): RecommendationConfiguration {
  const c = object(raw); keys(c, ['schemaVersion', 'organizationId', 'revision', 'policies', 'activation']);
  const a = object(c.activation); keys(a, ['generation', 'externalAi', 'matching', 'delivery']);
  if (c.schemaVersion !== 1 || c.organizationId !== org || !integer(c.revision) || c.revision < 1 ||
    !Array.isArray(c.policies) || c.policies.length > 100 || Object.values(a).some(value => value !== false)) {
    throw new DomainError('failed-precondition', 'Stored configuration requires review.');
  }
  const policies = c.policies.map(p => validatedPolicy(p as ReviewedRecommendationPolicy));
  if (new Set(policies.map(p => p.policyId)).size !== policies.length ||
    new Set(policies.map(p => digestOf(p.compatibility))).size !== policies.length) throw new DomainError('failed-precondition', 'Ambiguous configuration.');
  return c as unknown as RecommendationConfiguration;
}
/** Shared strict read parser; exporting it does not register or enable an API. */
export const parseRecommendationConfiguration = validateCurrentConfiguration;
/** Local dependency-injected command only. All activation gates remain off. */
export function createRecommendationConfigurationCommand(deps: RecommendationConfigurationDependencies) {
  return async (request: InsightsRequest): Promise<RecommendationConfiguration> => {
    try {
      const auth = await authorizeRecommendationSession(request, deps);
      const q = object(request.data); keys(q, ['schemaVersion', 'organizationId', 'commandId', 'expectedRevision', 'policyIds']);
      const org = requiredIdentifier(q.organizationId, 'organization'), command = requiredIdentifier(q.commandId, 'command');
      if (q.schemaVersion !== 1 || !integer(q.expectedRevision) || q.expectedRevision >= Number.MAX_SAFE_INTEGER ||
        !Array.isArray(q.policyIds) || q.policyIds.length > 100) throw new InputValidationError('Invalid revision or policies.');
      const ids = q.policyIds.map(id => requiredIdentifier(id, 'policy'));
      if (new Set(ids).size !== ids.length) throw new InputValidationError('Duplicate policy.');
      const allowlist = (deps.reviewedPolicies ?? []).map(validatedPolicy);
      if (new Set(allowlist.map(p => p.policyId)).size !== allowlist.length) throw new DomainError('failed-precondition', 'Ambiguous server policy.');
      const policies = ids.map(id => {
        const policy = allowlist.find(p => p.policyId === id);
        if (!policy) throw new DomainError('failed-precondition', 'Policy not reviewed.');
        return policy;
      });
      if (new Set(policies.map(p => digestOf(p.compatibility))).size !== policies.length) throw new InputValidationError('Duplicate compatibility.');
      const now = (deps.clock ?? Date.now)();
      if (!integer(now)) throw new DomainError('unavailable', 'Invalid server clock.');
      const path = `orgs/${org}/recommendationConfiguration/current`;
      const commandKey = digestOf({actorId: auth.uid, commandId: command});
      const receiptPath = `orgs/${org}/recommendationConfigurationReceipts/${commandKey}`;
      const fingerprint = digestOf(q);
      return await deps.store.transact(async tx => {
        await authorizeAdminReport(tx, auth, org);
        const current = await tx.get(path), receipt = await tx.get(receiptPath);
        if (receipt) {
          if (receipt.fingerprint !== fingerprint) throw new DomainError('aborted', 'Command reused.');
          return validateCurrentConfiguration(receipt.result, org);
        }
        if (current) validateCurrentConfiguration(current, org);
        if ((current?.revision ?? 0) !== q.expectedRevision) {
          throw new DomainError('aborted', 'Revision changed.');
        }
        const result: RecommendationConfiguration = {...defaultRecommendationConfiguration(org), revision: Number(q.expectedRevision) + 1, policies};
        tx.set(path, result);
        tx.create(`orgs/${org}/recommendationConfigurationAudit/${commandKey}`, {
          schemaVersion: 1, actorId: auth.uid, commandId: command, previousRevision: q.expectedRevision,
          revision: result.revision, policyIds: ids, reviewVersions: policies.map(p => p.reviewVersion), atMillis: now,
          configurationFingerprint: digestOf(result)});
        tx.create(receiptPath, {schemaVersion: 1, fingerprint, result});
        return result;
      });
    } catch (error) {throw recommendationCommandError(error);}
  };
}
