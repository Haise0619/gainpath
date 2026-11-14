import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {keys, object} from '../workouts/workout-backup-validation';
import type {InsightsRequest} from './exercise-insights-contracts';
import {authorizeRecommendationSession, recommendationCommandError, type RecommendationCommandDependencies} from './recommendation-configuration';
import {createRecommendationConsentV2Command, parseRecommendationConsentV2} from './recommendation-consent-v2';
import {requireRecommendationMember} from './recommendation-member-service';
import {createCanonicalRecommendationLifecycle, type ReviewedCanonicalRuntime} from './canonical-recommendation-lifecycle';

/** A code-reviewed release prerequisite, not a remote flag or request option.
 * Accepted v2 summaries do not yet carry exact metric-schema/mode/coverage
 * bindings required by Module 13. Neither backups nor fictional attestations
 * may fill that gap. Keep this separate from the workout tuple allowlist. */
export const CANONICAL_RECOMMENDATION_RELEASE = Object.freeze({
  enabled: false as const,
  reason: 'review_required' as const,
  missing: Object.freeze(['accepted_metric_binding', 'reviewed_evidence_policy', 'reviewed_notice', 'canonical_target_adapter']),
});

const OPERATIONS = ['session.access', 'member.consent.get', 'member.consent.set', 'member.consent.notice',
  'member.recommendation.list', 'member.recommendation.command'] as const;

/** Default-database Member boundary. Deliberately never instantiates a demo/FYP
 * capability and never queries synthetic lead or recipient collections. */
export function createCanonicalRecommendationBackend(deps: RecommendationCommandDependencies & {readonly runtime?: ReviewedCanonicalRuntime}) {
  return async (incoming: InsightsRequest): Promise<unknown> => {
    try {
      const envelope = object(incoming.data); keys(envelope, ['schemaVersion', 'operation', 'data']);
      if (envelope.schemaVersion !== 1 || !OPERATIONS.includes(envelope.operation as typeof OPERATIONS[number]) ||
        Buffer.byteLength(JSON.stringify(envelope)) > 16384) throw new DomainError('invalid-argument', 'Invalid bounded command.');
      const data = object(envelope.data), org = requiredIdentifier(data.organizationId, 'organization');
      // No environment, scope, owner or capability selector is accepted here.
      const request: InsightsRequest = {...incoming, data};
      const auth = await authorizeRecommendationSession(request, deps);
      await deps.store.transact(async tx => {if(await tx.get(`datasetAssignments/${auth.uid}`))throw new DomainError('permission-denied','Canonical account required.');
        await requireRecommendationMember(tx, auth, org);});
      const operation = envelope.operation;
      if (operation === 'member.consent.set') {
        // Privacy revocation remains available during rollout/rollback. Grants
        // need a reviewed notice; no such production policy is registered.
        if (data.action !== 'revoke' && !deps.runtime) throw new DomainError('failed-precondition', 'Notice requires server review.');
        return await createRecommendationConsentV2Command({...deps, noticePolicies: deps.runtime?.notices})(request);
      }
      if (operation === 'member.consent.get') {
        keys(data, ['schemaVersion', 'organizationId']);
        if (data.schemaVersion !== 2) throw new DomainError('invalid-argument', 'Invalid consent version.');
        return await deps.store.transact(async tx => {
          await requireRecommendationMember(tx, auth, org);
          const raw = await tx.get(`orgs/${org}/recommendationConsent/${auth.uid}`);
          return raw ? parseRecommendationConsentV2(raw, {organizationId: org, memberId: auth.uid}, (deps.clock ?? Date.now)()) : null;
        });
      }
      if (operation === 'session.access') {
        keys(data, ['schemaVersion', 'organizationId']);
        if (data.schemaVersion !== 1) throw new DomainError('invalid-argument', 'Invalid version.');
        return {schemaVersion: 1, mode: 'accepted_workout', organizationId: org, role: 'member',
          enabled: !!deps.runtime, reason: deps.runtime ? null : CANONICAL_RECOMMENDATION_RELEASE.reason};
      }
      if (operation === 'member.recommendation.list') {
        keys(data, ['schemaVersion', 'organizationId', 'history', 'afterId']);
        if (data.schemaVersion !== 1 || typeof data.history !== 'boolean' ||
          data.afterId !== null && (typeof data.afterId !== 'string' || !/^[a-f0-9]{64}$/.test(data.afterId))) {
          throw new DomainError('invalid-argument', 'Invalid inbox query.');
        }
        if (deps.runtime) {
          const lifecycle = createCanonicalRecommendationLifecycle({...deps, runtime: deps.runtime});
          const ids = await lifecycle.ids(auth, org, data.afterId as string|null), recommendations: unknown[] = [];
          for (const id of ids) {
            try {const detail = await lifecycle.member(auth, org, id, 'get', null, null);
              const d=object(detail);
              if (d.deliveredAtMillis!==null&&(data.history || d.state==='available')) recommendations.push(detail);
            } catch (error) {if (!(error instanceof DomainError) || !['failed-precondition','permission-denied'].includes(error.code)) throw error;}
          }
          return {schemaVersion: 1, mode: 'accepted_workout', organizationId: org, enabled: true, reason: null,
            recommendations, nextAfterId: ids.length === 25 ? ids[ids.length - 1] : null};
        }
        return {schemaVersion: 1, mode: 'accepted_workout', organizationId: org, enabled: false,
          reason: CANONICAL_RECOMMENDATION_RELEASE.reason, recommendations: [], nextAfterId: null};
      }
      if (deps.runtime && operation === 'member.consent.notice') {
        keys(data, ['schemaVersion','organizationId']);
        if (data.schemaVersion !== 1 || deps.runtime.notices.length !== 1) throw new DomainError('failed-precondition','Notice requires review.');
        const notice = deps.runtime.notices[0];
        return {schemaVersion: 1, organizationId: org, demoData: false, policyId: notice.policyId,
          noticeVersion: notice.noticeVersion, contentVersion: notice.contentVersion,
          historyDescription: notice.history.mode === 'from_grant' ? 'Only qualifying accepted workouts captured after this permission was granted.' :
            `Qualifying accepted workouts from ${new Date(notice.history.earliestAtMillis).toISOString()}.`};
      }
      if (deps.runtime && operation === 'member.recommendation.command') {
        keys(data, ['schemaVersion','organizationId','recommendationId','action','commandId','expectedRevision']);
        if (data.schemaVersion !== 1 || typeof data.recommendationId !== 'string' || !/^[a-f0-9]{64}$/.test(data.recommendationId) ||
          !['get','resolve','read','acknowledge','dismiss'].includes(String(data.action)) ||
          (['get','resolve'].includes(String(data.action)) ? data.commandId !== null || data.expectedRevision !== null :
            typeof data.commandId !== 'string' || !Number.isSafeInteger(data.expectedRevision) || Number(data.expectedRevision) < 1)) {
          throw new DomainError('invalid-argument','Invalid recommendation command.');
        }
        return await createCanonicalRecommendationLifecycle({...deps,runtime:deps.runtime}).member(auth,org,data.recommendationId,
          data.action as 'get'|'resolve'|'read'|'acknowledge'|'dismiss',data.expectedRevision as number|null,data.commandId as string|null);
      }
      throw new DomainError('failed-precondition', 'Canonical evidence and target policies require review.');
    } catch (error) {throw recommendationCommandError(error);}
  };
}
