import {DomainError} from '../../platform/errors';
import type {TransactionPort} from '../../platform/firestore/store';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {digestOf, keys, object} from '../workouts/workout-backup-validation';
import type {InsightsRequest} from './exercise-insights-contracts';
import {authorizeRecommendationSession, recommendationCommandError} from './recommendation-configuration';
import type {RecommendationPurpose} from './recommendation-consent-v2';
import {parseRecommendationLead, queueBusinessKey, queueInteger, QUEUE_STATUSES, queueText,
  type RecommendationDecisionReceipt, type RecommendationLead, type RecommendationLeadStatus, type RecommendationRecipientRecord} from './recommendation-queue-contracts';
import {authorizeQueue, readRecommendationMemberState, requireQueueAdmin, type QueueSecurityDependencies} from './recommendation-queue-security';

export interface RecommendationLeadDecisionDependencies extends QueueSecurityDependencies {
  /** Read only current source/config/target validation, with no external effect inside retryable work. */
  readonly validateTarget: (tx: Pick<TransactionPort, 'get' | 'getAll'>, lead: RecommendationLead) => Promise<'valid' | 'stale'>;
}
interface DecisionCommand {schemaVersion: 1; organizationId: string; leadId: string; commandId: string; expectedRevision: number; action: 'send' | 'dismiss'; reason: string | null}
function parseCommand(raw: unknown): DecisionCommand {
  const q = object(raw);
  keys(q, ['schemaVersion', 'organizationId', 'leadId', 'commandId', 'expectedRevision', 'action', 'reason']);
  requiredIdentifier(q.organizationId, 'organization'); requiredIdentifier(q.leadId, 'lead'); requiredIdentifier(q.commandId, 'command');
  if (q.schemaVersion !== 1 || !queueInteger(q.expectedRevision, 1) || q.expectedRevision >= Number.MAX_SAFE_INTEGER ||
    (q.action !== 'send' && q.action !== 'dismiss')) throw new InputValidationError('Invalid decision.');
  if (q.action === 'send' && q.reason !== null || q.action === 'dismiss' &&
    (!queueText(q.reason, 300) || q.reason.trim().length < 8 || !/[\p{L}\p{N}]/u.test(q.reason))) throw new InputValidationError('A meaningful dismissal reason is required.');
  return q as unknown as DecisionCommand;
}
function replay(raw: unknown, q: DecisionCommand, actorId: string, fingerprint: string): RecommendationDecisionReceipt | null {
  if (raw === undefined) return null;
  const r = object(raw);
  if (r.schemaVersion !== 1 || r.actorId !== actorId || r.commandId !== q.commandId || r.fingerprint !== fingerprint) {
    throw new DomainError('aborted', 'Command reused.');
  }
  const result = object(r.result);
  keys(result, ['schemaVersion', 'organizationId', 'leadId', 'revision', 'status', 'outcome', 'recipientRecommendationId', 'deliveryStatus']);
  if (result.schemaVersion !== 1 || result.organizationId !== q.organizationId || result.leadId !== q.leadId ||
    result.revision !== q.expectedRevision + 1 || !QUEUE_STATUSES.includes(result.status as RecommendationLeadStatus) ||
    !['prepared', 'dismissed', 'blocked'].includes(result.outcome as string) ||
    result.recipientRecommendationId !== null && (typeof result.recipientRecommendationId !== 'string' || !/^[a-f0-9]{64}$/.test(result.recipientRecommendationId)) ||
    result.deliveryStatus !== 'prepared_local' && result.deliveryStatus !== 'not_prepared' ||
    (result.outcome === 'prepared' && (result.status !== 'sent' || result.deliveryStatus !== 'prepared_local' || result.recipientRecommendationId === null)) ||
    (result.outcome === 'dismissed' && result.status !== 'dismissed') ||
    (result.outcome === 'blocked' && !['expired', 'stale', 'revoked'].includes(result.status as string)) ||
    (q.action === 'dismiss' && result.outcome !== 'dismissed') ||
    (q.action === 'send' && result.outcome === 'dismissed') ||
    (result.outcome !== 'prepared' && (result.recipientRecommendationId !== null || result.deliveryStatus !== 'not_prepared'))) {
    throw new DomainError('failed-precondition', 'Decision receipt requires review.');
  }
  return structuredClone(result) as unknown as RecommendationDecisionReceipt;
}
function pending(lead: RecommendationLead, q: DecisionCommand): void {
  if (lead.leadId !== q.leadId || lead.status !== 'pending' || lead.revision !== q.expectedRevision || lead.revision >= Number.MAX_SAFE_INTEGER) {
    throw new DomainError('aborted', 'Lead revision changed.');
  }
}
/** A fallback may still have attempted inference; absence of a model does not imply no transfer. */
function usedInference(lead: RecommendationLead): boolean {
  return lead.ranking.origin === 'ai_reranked' || lead.ranking.model !== null ||
    lead.ranking.origin === 'deterministic_fallback' &&
    !['provider_not_configured', 'no_safe_semantic_evidence', 'single_eligible_candidate'].includes(lead.ranking.fallbackReason ?? '');
}
/** Local synthetic decision lifecycle only. No callable, notification worker or Member feed writer. */
export function createRecommendationLeadDecision(deps: RecommendationLeadDecisionDependencies) {
  return async (request: InsightsRequest): Promise<RecommendationDecisionReceipt> => {
    try {
      const first = await authorizeQueue(request, deps), q = parseCommand(request.data), org = first.organizationId;
      const commandKey = digestOf({actorId: first.auth.uid, commandId: q.commandId}), fingerprint = digestOf(q);
      const leadPath = `orgs/${org}/recommendationLeads/${q.leadId}`,
        receiptPath = `orgs/${org}/recommendationCommandReceipts/${commandKey}`;
      const before = await deps.store.transact(async tx => {
        await requireQueueAdmin(tx, first.auth, org);
        const receipt = replay(await tx.get(receiptPath), q, first.auth.uid, fingerprint);
        if (receipt) return {receipt, lead: null};
        const lead = parseRecommendationLead(await tx.get(leadPath), org); pending(lead, q);
        if(lead.createdAtMillis>first.now)throw new DomainError('failed-precondition','Lead creation time requires review.');
        return {receipt: null, lead};
      });
      if (before.receipt) return before.receipt;
      const leadBefore = before.lead!;
      // Auth lookups are not transaction reads and may fail: do them before the atomic write.
      let memberAuthEligible = true;
      if (q.action === 'send' && leadBefore.expiresAtMillis > first.now) {
        const identity = await deps.readAuthIdentity(leadBefore.memberId);
        memberAuthEligible = !!identity && identity.uid === leadBefore.memberId && identity.disabled === false &&
          identity.emailVerified === true && typeof identity.email === 'string' && !!identity.email.trim() && queueInteger(identity.tokensValidAfterMillis);
      }
      await authorizeRecommendationSession(request, deps);
      const now = (deps.clock ?? Date.now)();
      if (!queueInteger(now, 1) || now < first.now || now > 8640000000000000) throw new DomainError('unavailable', 'Invalid queue clock.');
      return await deps.store.transact(async tx => {
        await requireQueueAdmin(tx, first.auth, org);
        const replayed = replay(await tx.get(receiptPath), q, first.auth.uid, fingerprint);
        if (replayed) return replayed;
        const lead = parseRecommendationLead(await tx.get(leadPath), org); pending(lead, q);
        if (digestOf(lead) !== digestOf(leadBefore)) throw new DomainError('aborted', 'Lead changed.');
        let status: RecommendationLeadStatus = q.action === 'dismiss' ? 'dismissed' : 'sent';
        let recipientRecommendationId: string | null = null;
        if (q.action === 'send') {
          if (lead.expiresAtMillis <= now) status = 'expired';
          else {
            const purposes: RecommendationPurpose[] = ['exerciseInsights', 'recommendationGeneration', 'recommendationDelivery'];
            if (usedInference(lead)) purposes.push('externalAiInference');
            const member = await readRecommendationMemberState(tx, {organizationId: org, memberId: lead.memberId}, now, deps.noticePolicies ?? [], purposes);
            if (!memberAuthEligible || !member.eligible) status = 'revoked';
            else if (member.fingerprint !== lead.memberFingerprint) status = 'stale';
            else {
              const readonlyTx = {get: (path: string) => tx.get(path), ...(tx.getAll ? {getAll: (paths: readonly string[]) => tx.getAll!(paths)} : {})};
              const valid = await deps.validateTarget(readonlyTx, structuredClone(lead));
              if (valid !== 'valid' && valid !== 'stale') throw new DomainError('unavailable', 'Invalid target source.');
              if (valid === 'stale') status = 'stale';
            }
          }
          if (status === 'sent') {
            recipientRecommendationId = queueBusinessKey(org, lead.memberId, lead.kind, lead.exerciseId, lead.objective, lead.sourceFingerprint);
            if (await tx.get(`orgs/${org}/recommendationRecipients/${recipientRecommendationId}`)) throw new DomainError('aborted', 'Recommendation already prepared.');
          }
        }
        // Last canonical check is in the same transaction and precedes every write.
        await requireQueueAdmin(tx, first.auth, org);
        const outcome: RecommendationDecisionReceipt['outcome'] = status === 'sent' ? 'prepared' : status === 'dismissed' ? 'dismissed' : 'blocked';
        const result: RecommendationDecisionReceipt = {schemaVersion: 1, organizationId: org, leadId: lead.leadId,
          revision: lead.revision + 1, status, outcome, recipientRecommendationId,
          deliveryStatus: status === 'sent' ? 'prepared_local' : 'not_prepared'};
        const reason = q.reason === null ? null : q.reason.trim();
        const updated: RecommendationLead = {...lead, revision: result.revision, status,
          decision: {actorId: first.auth.uid, atMillis: now, commandId: q.commandId, reason, recipientRecommendationId}};
        tx.set(leadPath, updated);
        tx.create(`orgs/${org}/recommendationDecisionAudits/${commandKey}`, {schemaVersion: 1, mode: 'synthetic_local',
          organizationId: org, actorId: first.auth.uid, commandId: q.commandId, leadId: lead.leadId, action: q.action,
          previousStatus: lead.status, status, previousRevision: lead.revision, revision: result.revision, reason,
          atMillis: now, recipientRecommendationId, sourceFingerprint: lead.sourceFingerprint, memberFingerprint: lead.memberFingerprint});
        tx.create(receiptPath, {schemaVersion: 1, actorId: first.auth.uid, commandId: q.commandId, fingerprint, result});
        if (recipientRecommendationId !== null) {
          const record: RecommendationRecipientRecord = {schemaVersion: 1, mode: 'synthetic_local', recipientRecommendationId,
            organizationId: org, memberId: lead.memberId, leadId: lead.leadId, kind: lead.kind, target: structuredClone(lead.target),
            createdAtMillis: now, expiresAtMillis: lead.expiresAtMillis, status: 'prepared', memberReadAtMillis: null,
            acknowledgedAtMillis: null, withdrawnAtMillis: null, notificationDraft: {schemaVersion: 1, type: 'recommendation',
              recipientId: lead.memberId, recommendationId: recipientRecommendationId,
              title: lead.kind === 'trainer' ? 'Suggested coaching support' : 'Suggested exercise tutorial',
              message: `An organization Admin prepared a suggestion for ${lead.exerciseLabel}.`, createdAtMillis: now, read: false}};
          tx.create(`orgs/${org}/recommendationRecipients/${recipientRecommendationId}`, record);
        }
        return result;
      });
    } catch (error) {throw recommendationCommandError(error);}
  };
}
