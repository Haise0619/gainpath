import {requireActiveMembership} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {readAll, type TransactionPort} from '../../platform/firestore/store';
import {requiredIdentifier} from '../../platform/validation';
import {authorizeAdminReport} from '../analytics/admin-reporting';
import {digestOf, object} from '../workouts/workout-backup-validation';
import type {EvidenceScope, InsightsAuth, InsightsRequest} from './exercise-insights-contracts';
import {authorizeRecommendationSession, type RecommendationCommandDependencies} from './recommendation-configuration';
import {evaluateRecommendationConsentV2, type RecommendationPurpose, type ReviewedConsentNoticePolicy} from './recommendation-consent-v2';
import {requireDemoRuntimeCapability,type DemoRuntimeCapability} from './demo-runtime-capability';
import {requireFypRuntimeCapability,type FypRuntimeCapability} from '../dataset/fyp-scope';

/** Explicit local fixture composition; never derive this authority from a request. */
export interface QueueSecurityDependencies extends RecommendationCommandDependencies {
  readonly demoCapability?:DemoRuntimeCapability;
  readonly fypCapability?:FypRuntimeCapability;
  readonly localFixture?: {readonly fixtureSetId: 'module13-c-v1'; readonly organizationId: 'synthetic-org' | 'gainpath'};
  readonly noticePolicies?: readonly ReviewedConsentNoticePolicy[];
}
const integer = (value: unknown): value is number => Number.isSafeInteger(value) && Number(value) >= 0;
export function requireSyntheticQueue(deps: QueueSecurityDependencies, organizationId: string): void {
  if(requireFypRuntimeCapability(deps.fypCapability,organizationId))return;
  if(requireDemoRuntimeCapability(deps.demoCapability,organizationId))return;
  const fixture = deps.localFixture;
  if (!fixture || typeof fixture !== 'object' || Array.isArray(fixture) || Object.keys(fixture).length !== 2 ||
    fixture.fixtureSetId !== 'module13-c-v1' || !['synthetic-org','gainpath'].includes(fixture.organizationId) || organizationId !== fixture.organizationId) {
    throw new DomainError('failed-precondition', 'Synthetic queue composition is required.');
  }
}
export async function requireQueueAdmin(tx: TransactionPort, auth: InsightsAuth, organizationId: string): Promise<void> {
  await authorizeAdminReport(tx, auth, organizationId);
  // The generic legacy membership helper string-coerces roles. Queue roles are literal.
  const member = await tx.get(`orgs/${organizationId}/members/${auth.uid}`);
  if (member?.role !== 'admin') throw new DomainError('permission-denied', 'Current Admin role required.');
}
/** Fresh Auth is read outside a retryable transaction; canonical authority is checked inside it. */
export async function authorizeQueue(request: InsightsRequest, deps: QueueSecurityDependencies): Promise<{
  auth: InsightsAuth; organizationId: string; now: number;
}> {
  const organizationId = requiredIdentifier(object(request.data).organizationId, 'organizationId');
  requireSyntheticQueue(deps, organizationId);
  const auth = await authorizeRecommendationSession(request, deps), now = (deps.clock ?? Date.now)();
  if (!integer(now) || now > 8640000000000000) throw new DomainError('unavailable', 'Invalid queue clock.');
  await deps.store.transact(tx => requireQueueAdmin(tx, auth, organizationId));
  return {auth, organizationId, now};
}
export interface RecommendationMemberState {eligible: boolean; fingerprint: string; consentRevision: number | null}
/** Internal read only purpose gate. No histories or provider calls are made here. */
export async function readRecommendationMemberState(tx: Pick<TransactionPort, 'get' | 'getAll'>, scope: EvidenceScope,
  now: number, notices: readonly ReviewedConsentNoticePolicy[], purposes: readonly RecommendationPurpose[]): Promise<RecommendationMemberState> {
  const denied: RecommendationMemberState = {eligible: false, fingerprint: '', consentRevision: null};
  requiredIdentifier(scope.organizationId, 'organization'); requiredIdentifier(scope.memberId, 'member');
  if (!integer(now) || !Array.isArray(purposes) || purposes.length === 0 || new Set(purposes).size !== purposes.length) return denied;
  // Do not swallow source exceptions: a failed read must not become a durable blocked transition.
  const [user, member, consent, organization] = await readAll(tx as TransactionPort, [`users/${scope.memberId}`,
    `orgs/${scope.organizationId}/members/${scope.memberId}`, `orgs/${scope.organizationId}/recommendationConsent/${scope.memberId}`, `orgs/${scope.organizationId}`]);
  try {
    if (organization?.status !== 'active' || user?.organizationId !== scope.organizationId ||
      (user.role !== undefined && user.role !== 'member') || member?.organizationId !== scope.organizationId ||
      member.role !== 'member' || requireActiveMembership(member).role !== 'member' || (member.userId !== undefined && member.userId !== scope.memberId) ||
      !Array.isArray(member.branchIds) || !member.branchIds.every(id => typeof id === 'string')) return denied;
    if (user.accountLifecycle !== undefined) {
      const lifecycle = object(user.accountLifecycle);
      if (lifecycle.schemaVersion !== 1 || lifecycle.state !== 'active' || lifecycle.revocationPending !== false ||
        !integer(lifecycle.sessionNotBeforeSeconds)) return denied;
    }
    const decisions = purposes.map(purpose => evaluateRecommendationConsentV2(consent, scope, now, notices, purpose));
    if (decisions.some(decision => !decision.allowed)) return denied;
    const allowed = decisions.find(decision => decision.allowed)!;
    return {eligible: true, fingerprint: digestOf({user, member, consentFingerprint: allowed.allowed ? allowed.fingerprint : ''}),
      consentRevision: allowed.allowed ? allowed.revision : null};
  } catch {return denied;}
}
