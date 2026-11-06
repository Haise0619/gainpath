import {DomainError} from '../../platform/errors';
import type {TransactionPort} from '../../platform/firestore/store';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {digestOf, keys, object} from '../workouts/workout-backup-validation';
import type {FreshAuthIdentity, InsightsRequest} from './exercise-insights-contracts';
import {authorizeRecommendationSession, recommendationCommandError} from './recommendation-configuration';
import type {RecommendationPurpose} from './recommendation-consent-v2';
import {parseQueueTarget, parseRecommendationLead, queueBusinessKey, queueFailure, queueInteger, queueText,
  type RecommendationLead, type RecommendationRecipientRecord} from './recommendation-queue-contracts';
import {authorizeQueue, readRecommendationMemberState, requireQueueAdmin, requireSyntheticQueue} from './recommendation-queue-security';
import {recommendationNotificationId, type CurrentRecommendationTarget, type RecommendationDeliveryDependencies,
  type RecommendationDeliveryReceipt} from './recommendation-member-contracts';
import {requireDemoRuntimeCapability} from './demo-runtime-capability';
import {requireFypRuntimeCapability} from '../dataset/fyp-scope';

/** C's prepared wire contract stays unchanged. Only D writes this strict stored extension. */
export type StoredRecommendationRecipient = Omit<RecommendationRecipientRecord,
  'status' | 'memberReadAtMillis' | 'acknowledgedAtMillis' | 'withdrawnAtMillis'> & {
  status: 'prepared' | 'delivered' | 'withdrawn';
  memberReadAtMillis: number | null; acknowledgedAtMillis: number | null; withdrawnAtMillis: number | null;
  revision?: number; deliveredAtMillis?: number; notificationId?: string; dismissedAtMillis?: number | null;
};
const C_KEYS = ['schemaVersion', 'mode', 'recipientRecommendationId', 'organizationId', 'memberId', 'leadId', 'kind', 'target',
  'createdAtMillis', 'expiresAtMillis', 'status', 'memberReadAtMillis', 'acknowledgedAtMillis', 'withdrawnAtMillis'];
export function requireSyntheticDelivery(deps: RecommendationDeliveryDependencies, org: string): void {
  if(requireFypRuntimeCapability(deps.fypCapability,org)||requireDemoRuntimeCapability(deps.demoCapability,org))return;
  requireSyntheticQueue(deps, org);
  const d = deps.localDelivery;
  if (!d || typeof d !== 'object' || Array.isArray(d) || Object.keys(d).length !== 1 || d.fixtureSetId !== 'module13-d-v1') {
    throw new DomainError('failed-precondition', 'Synthetic delivery composition is required.');
  }
}
export function deliveryNow(deps: RecommendationDeliveryDependencies, minimum = 1): number {
  const now = (deps.clock ?? Date.now)();
  if (!queueInteger(now, minimum) || now > 8640000000000000) throw new DomainError('unavailable', 'Invalid delivery clock.');
  return now;
}
export function parseRecommendationRecipient(raw: unknown, org: string, id: string): StoredRecommendationRecipient {
  try {
    const r = object(raw), extended = r.status !== 'prepared';
    keys(r, [...C_KEYS, 'notificationDraft', ...(extended ? ['revision', 'deliveredAtMillis', 'notificationId', 'dismissedAtMillis'] : [])]);
    if (r.schemaVersion !== 1 || r.mode !== 'synthetic_local' || r.organizationId !== org || r.recipientRecommendationId !== id ||
      !/^[a-f0-9]{64}$/.test(id) || !['trainer', 'content'].includes(r.kind as string) ||
      !['prepared', 'delivered', 'withdrawn'].includes(r.status as string) || !queueInteger(r.createdAtMillis, 1) ||
      !queueInteger(r.expiresAtMillis, 1) || r.expiresAtMillis <= r.createdAtMillis) throw queueFailure();
    requiredIdentifier(r.memberId, 'member'); requiredIdentifier(r.leadId, 'lead');
    if (parseQueueTarget(r.target, org).kind !== r.kind) throw queueFailure();
    const draft = object(r.notificationDraft);
    keys(draft, ['schemaVersion', 'type', 'recipientId', 'recommendationId', 'title', 'message', 'createdAtMillis', 'read']);
    if (draft.schemaVersion !== 1 || draft.type !== 'recommendation' || draft.recipientId !== r.memberId || draft.recommendationId !== id ||
      draft.createdAtMillis !== r.createdAtMillis || draft.read !== false || !queueText(draft.title, 120) || !queueText(draft.message, 400)) throw queueFailure();
    for (const key of ['memberReadAtMillis', 'acknowledgedAtMillis', 'withdrawnAtMillis', ...(extended ? ['dismissedAtMillis'] : [])]) {
      if (r[key] !== null && (!extended || !queueInteger(r[key], Number(r.deliveredAtMillis)))) throw queueFailure();
    }
    if (extended && (!queueInteger(r.revision, 1) || r.revision >= Number.MAX_SAFE_INTEGER || !queueInteger(r.deliveredAtMillis, Number(r.createdAtMillis)) ||
      r.notificationId !== recommendationNotificationId(id) || (r.status === 'withdrawn') !== (r.withdrawnAtMillis !== null))) throw queueFailure();
    return structuredClone(r) as unknown as StoredRecommendationRecipient;
  } catch {throw queueFailure();}
}
export function bindRecommendationRecipient(r: StoredRecommendationRecipient, lead: RecommendationLead): void {
  const id = queueBusinessKey(lead.organizationId, lead.memberId, lead.kind, lead.exerciseId, lead.objective, lead.sourceFingerprint);
  if (lead.status !== 'sent' || lead.decision?.recipientRecommendationId !== id || r.recipientRecommendationId !== id ||
    r.leadId !== lead.leadId || r.memberId !== lead.memberId || r.kind !== lead.kind || r.createdAtMillis !== lead.decision.atMillis ||
    r.expiresAtMillis !== lead.expiresAtMillis || digestOf(r.target) !== digestOf(lead.target) ||
    r.notificationDraft.title !== (lead.kind === 'trainer' ? 'Suggested coaching support' : 'Suggested exercise tutorial') ||
    r.notificationDraft.message !== `An organization Admin prepared a suggestion for ${lead.exerciseLabel}.`) throw queueFailure();
}
function immutableRecipient(r: StoredRecommendationRecipient): object {
  const {status: _status, memberReadAtMillis: _read, acknowledgedAtMillis: _ack, withdrawnAtMillis: _withdraw,
    revision: _rev, deliveredAtMillis: _delivered, notificationId: _notification, dismissedAtMillis: _dismissed, ...immutable} = r;
  return immutable;
}
export const validRecipientIdentity = (identity: FreshAuthIdentity, uid: string): boolean => !!identity && identity.uid === uid &&
  identity.disabled === false && identity.emailVerified === true && queueText(identity.email, 320) && queueInteger(identity.tokensValidAfterMillis);
export function recommendationPurposes(lead: RecommendationLead): RecommendationPurpose[] {
  const purposes: RecommendationPurpose[] = ['exerciseInsights', 'recommendationGeneration', 'recommendationDelivery'];
  const r = lead.ranking;
  if (r.origin === 'ai_reranked' || r.model !== null || r.origin === 'deterministic_fallback' &&
    !['provider_not_configured', 'no_safe_semantic_evidence', 'single_eligible_candidate'].includes(r.fallbackReason ?? '')) purposes.push('externalAiInference');
  return purposes;
}
/** Recheck current purposes and B eligibility/source integrity on every delivery, read and action. */
export async function resolveCurrentRecommendation(tx: Pick<TransactionPort, 'get' | 'getAll'>, deps: RecommendationDeliveryDependencies,
  lead: RecommendationLead, now: number): Promise<CurrentRecommendationTarget | null> {
  const member = await readRecommendationMemberState(tx, {organizationId: lead.organizationId, memberId: lead.memberId}, now,
    deps.noticePolicies ?? [], recommendationPurposes(lead));
  if (!member.eligible) return null;
  const readonlyTx = {get: (path: string) => tx.get(path), ...(tx.getAll ? {getAll: (paths: readonly string[]) => tx.getAll!(paths)} : {})};
  const current = await deps.resolveTarget(readonlyTx, structuredClone(lead));
  if (current === null) return null;
  const t = object(current); keys(t, ['target', 'label', 'specialization', 'imageUrl', 'photoPath']);
  if (digestOf(parseQueueTarget(t.target, lead.organizationId)) !== digestOf(lead.target) || !queueText(t.label, 200) ||
    t.specialization !== null && !queueText(t.specialization, 120) || t.photoPath !== null && !queueText(t.photoPath, 1024)) throw queueFailure();
  if (t.imageUrl !== null) {
    if (!queueText(t.imageUrl, 2048)) throw queueFailure();
    const url = new URL(t.imageUrl);
    if (url.protocol !== 'https:' || !url.hostname || url.username || url.password) throw queueFailure();
  }
  return structuredClone(current);
}
export async function verifyRecommendationDelivery(tx: Pick<TransactionPort, 'get' | 'getAll'>, org: string,
  r: StoredRecommendationRecipient, lead: RecommendationLead): Promise<RecommendationDeliveryReceipt | null> {
  const raw = await tx.get(`orgs/${org}/recommendationDeliveryReceipts/${r.recipientRecommendationId}`);
  const notice = await tx.get(`orgs/${org}/notifications/${recommendationNotificationId(r.recipientRecommendationId)}`);
  if (r.status === 'prepared') {
    if (raw || notice) throw queueFailure();
    return null;
  }
  const stored = object(raw); keys(stored, ['schemaVersion', 'recipientFingerprint', 'leadFingerprint', 'result']);
  const result = object(stored.result);
  keys(result, ['schemaVersion', 'mode', 'organizationId', 'recommendationId', 'notificationId', 'revision', 'deliveredAtMillis', 'status']);
  if (stored.schemaVersion !== 1 || stored.recipientFingerprint !== digestOf(immutableRecipient(r)) || stored.leadFingerprint !== digestOf(lead) ||
    result.schemaVersion !== 1 || result.mode !== 'synthetic_local' || result.organizationId !== org || result.recommendationId !== r.recipientRecommendationId ||
    result.notificationId !== r.notificationId || result.revision !== 1 || result.deliveredAtMillis !== r.deliveredAtMillis || result.status !== 'delivered' ||
    !notice || notice.schemaVersion !== 1 || notice.recipientId !== r.memberId || notice.type !== 'recommendation' ||
    notice.recommendationId !== r.recipientRecommendationId || notice.recommendationKind !== r.kind || typeof notice.read !== 'boolean' ||
    notice.title !== r.notificationDraft.title || notice.message !== 'Open to review this suggestion.' || notice.createdAtMillis !== r.deliveredAtMillis ||
    (r.memberReadAtMillis !== null) !== notice.read) throw queueFailure();
  return structuredClone(result) as unknown as RecommendationDeliveryReceipt;
}
/** Manually controlled local-only Admin entrypoint. No export, worker or provider is registered. */
export function createRecommendationDelivery(deps: RecommendationDeliveryDependencies) {
  return async (request: InsightsRequest): Promise<RecommendationDeliveryReceipt> => {
    try {
      const q = object(request.data); keys(q, ['schemaVersion', 'organizationId', 'recommendationId']);
      const org = requiredIdentifier(q.organizationId, 'organization'), id = requiredIdentifier(q.recommendationId, 'recommendation');
      if (q.schemaVersion !== 1 || !/^[a-f0-9]{64}$/.test(id)) throw new InputValidationError('Invalid recommendation.');
      requireSyntheticDelivery(deps, org);
      const first = await authorizeQueue(request, deps);
      const path = `orgs/${org}/recommendationRecipients/${id}`;
      const before = await deps.store.transact(async tx => {
        await requireQueueAdmin(tx, first.auth, org);
        const r = parseRecommendationRecipient(await tx.get(path), org, id);
        const lead = parseRecommendationLead(await tx.get(`orgs/${org}/recommendationLeads/${r.leadId}`), org);
        bindRecommendationRecipient(r, lead);
        return {r, lead};
      });
      const identity = await deps.readAuthIdentity(before.r.memberId);
      await authorizeRecommendationSession(request, deps);
      const now = deliveryNow(deps, first.now);
      return await deps.store.transact(async tx => {
        await requireQueueAdmin(tx, first.auth, org);
        const r = parseRecommendationRecipient(await tx.get(path), org, id);
        const lead = parseRecommendationLead(await tx.get(`orgs/${org}/recommendationLeads/${r.leadId}`), org);
        bindRecommendationRecipient(r, lead);
        if (digestOf(immutableRecipient(r)) !== digestOf(immutableRecipient(before.r)) || digestOf(lead) !== digestOf(before.lead)) {
          throw new DomainError('aborted', 'Recommendation changed.');
        }
        if (r.createdAtMillis > now || lead.createdAtMillis > now || r.expiresAtMillis <= now || r.status === 'withdrawn' ||
          !validRecipientIdentity(identity, r.memberId) || !await resolveCurrentRecommendation(tx, deps, lead, now)) throw queueFailure();
        const existing = await verifyRecommendationDelivery(tx, org, r, lead);
        await requireQueueAdmin(tx, first.auth, org);
        if (existing) return existing;
        const notificationId = recommendationNotificationId(id);
        const result: RecommendationDeliveryReceipt = {schemaVersion: 1, mode: 'synthetic_local', organizationId: org, recommendationId: id,
          notificationId, revision: 1, deliveredAtMillis: now, status: 'delivered'};
        tx.create(`orgs/${org}/notifications/${notificationId}`, {schemaVersion: 1, type: 'recommendation', recipientId: r.memberId,
          recommendationId: id, recommendationKind: r.kind, title: r.notificationDraft.title, message: 'Open to review this suggestion.', createdAtMillis: now, read: false});
        tx.create(`orgs/${org}/recommendationDeliveryReceipts/${id}`, {schemaVersion: 1, recipientFingerprint: digestOf(immutableRecipient(r)), leadFingerprint: digestOf(lead), result});
        tx.set(path, {...r, status: 'delivered', revision: 1, deliveredAtMillis: now, notificationId, dismissedAtMillis: null});
        return result;
      });
    } catch (error) {throw recommendationCommandError(error);}
  };
}
