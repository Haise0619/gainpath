import {digestOf, keys, object} from '../workouts/workout-backup-validation';
import type {ConsentDecision, EvidenceScope, RecommendationPurposes} from './exercise-insights-contracts';
import {evaluateRecommendationConsentV2, type ReviewedConsentNoticePolicy} from './recommendation-consent-v2';

export const DEFAULT_RECOMMENDATION_PURPOSES: RecommendationPurposes = Object.freeze({
  exerciseInsights: false, recommendationGeneration: false, externalAiInference: false, recommendationDelivery: false,
});
const timestamp = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) >= 0;

/** A read-only evaluator of a proposed independent contract, not camera/backup permission. */
export function evaluateRecommendationConsent(raw: unknown, scope: EvidenceScope, now: number,
  noticePolicies: readonly ReviewedConsentNoticePolicy[] = []): ConsentDecision {
  if (raw === undefined || raw === null) return {allowed: false, reason: 'missing'};
  try {
    const c = object(raw);
    if (c.schemaVersion === 2) return evaluateRecommendationConsentV2(raw, scope, now, noticePolicies);
    keys(c, ['schemaVersion', 'policyVersion', 'organizationId', 'memberId', 'revision', 'purposes',
      'grantedAtMillis', 'revokedAtMillis', 'updatedAtMillis']);
    const purposes = object(c.purposes);
    keys(purposes, Object.keys(DEFAULT_RECOMMENDATION_PURPOSES));
    if (c.schemaVersion !== 1 || c.policyVersion !== 'module13-purpose-v1-proposed' ||
      c.organizationId !== scope.organizationId || c.memberId !== scope.memberId ||
      !Number.isSafeInteger(c.revision) || Number(c.revision) < 1 ||
      !timestamp(now) || !timestamp(c.updatedAtMillis) || c.updatedAtMillis > now ||
      Object.values(purposes).some(value => typeof value !== 'boolean') ||
      (c.grantedAtMillis !== null && (!timestamp(c.grantedAtMillis) || c.grantedAtMillis > c.updatedAtMillis)) ||
      (c.revokedAtMillis !== null && (!timestamp(c.revokedAtMillis) || c.revokedAtMillis > c.updatedAtMillis))) {
      return {allowed: false, reason: 'invalid'};
    }
    if (c.revokedAtMillis !== null) return {allowed: false, reason: 'revoked'};
    if (purposes.exerciseInsights !== true || c.grantedAtMillis === null) return {allowed: false, reason: 'not_granted'};
    return {allowed: true, revision: Number(c.revision), fingerprint: digestOf(c)};
  } catch {
    return {allowed: false, reason: 'invalid'};
  }
}
