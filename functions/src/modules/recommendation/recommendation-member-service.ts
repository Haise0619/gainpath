import {requireActiveMembership} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {readAll, type TransactionPort} from '../../platform/firestore/store';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {digestOf, keys, object} from '../workouts/workout-backup-validation';
import type {InsightsAuth, InsightsRequest} from './exercise-insights-contracts';
import {authorizeRecommendationSession, recommendationCommandError} from './recommendation-configuration';
import {bindRecommendationRecipient, deliveryNow, parseRecommendationRecipient, requireSyntheticDelivery,
  resolveCurrentRecommendation, verifyRecommendationDelivery, type StoredRecommendationRecipient} from './recommendation-delivery';
import {parseRecommendationLead, queueFailure, queueInteger} from './recommendation-queue-contracts';
import type {RecommendationDeliveryDependencies, MemberRecommendationDetail, MemberRecommendationState} from './recommendation-member-contracts';

type MemberAction = 'get' | 'resolve' | 'read' | 'acknowledge' | 'dismiss';
interface MemberCommand {schemaVersion: 1; organizationId: string; recommendationId: string; action: MemberAction; commandId: string | null; expectedRevision: number | null}
function parseCommand(raw: unknown): MemberCommand {
  const q = object(raw); keys(q, ['schemaVersion', 'organizationId', 'recommendationId', 'action', 'commandId', 'expectedRevision']);
  requiredIdentifier(q.organizationId, 'organization'); requiredIdentifier(q.recommendationId, 'recommendation');
  if (q.schemaVersion !== 1 || typeof q.recommendationId !== 'string' || !/^[a-f0-9]{64}$/.test(q.recommendationId) ||
    !['get', 'resolve', 'read', 'acknowledge', 'dismiss'].includes(q.action as string)) throw new InputValidationError('Invalid recommendation command.');
  if (q.action === 'get' || q.action === 'resolve') {
    if (q.commandId !== null || q.expectedRevision !== null) throw new InputValidationError('Read lookup requires null command metadata.');
  } else {
    requiredIdentifier(q.commandId, 'command');
    if (!queueInteger(q.expectedRevision, 1) || q.expectedRevision >= Number.MAX_SAFE_INTEGER - 1) throw new InputValidationError('Invalid recommendation revision.');
  }
  return q as unknown as MemberCommand;
}
/** Canonical authorization only. Callers must first authenticate the current session with App Check and fresh Auth. */
export async function requireRecommendationMember(tx: TransactionPort, auth: InsightsAuth, org: string): Promise<void> {
  const [user, member, organization] = await readAll(tx, [`users/${auth.uid}`, `orgs/${org}/members/${auth.uid}`, `orgs/${org}`]);
  if (organization?.status !== 'active' || user?.organizationId !== org || user.role !== undefined && user.role !== 'member' ||
    member?.organizationId !== org || member.role !== 'member' || requireActiveMembership(member).role !== 'member' ||
    member.userId !== undefined && member.userId !== auth.uid) throw new DomainError('permission-denied', 'Current Member access required.');
  if (user.accountLifecycle !== undefined) {
    const lifecycle = object(user.accountLifecycle);
    if (lifecycle.schemaVersion !== 1 || lifecycle.state !== 'active' || lifecycle.revocationPending !== false ||
      !queueInteger(lifecycle.sessionNotBeforeSeconds) || !queueInteger(auth.token.auth_time) ||
      auth.token.auth_time < lifecycle.sessionNotBeforeSeconds) throw new DomainError('permission-denied', 'Current Member session required.');
  }
}
const redactedText: Record<Exclude<MemberRecommendationState, 'available'>, {title: string; summary: string}> = {
  not_delivered: {title: 'Recommendation pending delivery', summary: 'This suggestion has not been delivered to your inbox.'},
  expired: {title: 'Recommendation expired', summary: 'This suggestion is no longer current. You can browse Coaches or tutorials.'},
  withdrawn: {title: 'Recommendation unavailable', summary: 'This suggestion is no longer available.'},
  dismissed: {title: 'Recommendation dismissed', summary: 'You dismissed this suggestion.'},
  unavailable: {title: 'Recommendation unavailable', summary: 'This suggestion is currently unavailable.'},
};
function redact(detail: MemberRecommendationDetail, state: Exclude<MemberRecommendationState, 'available'>): MemberRecommendationDetail {
  return {...detail, state, ...redactedText[state], exerciseLabel: null, objective: null, explanations: [], target: null,
    targetLabel: null, specialization: null, imageUrl: null, photoPath: null};
}
async function loadProjection(tx: TransactionPort, deps: RecommendationDeliveryDependencies, auth: InsightsAuth, org: string, id: string, now: number) {
  requireSyntheticDelivery(deps, org);
  await requireRecommendationMember(tx, auth, org);
  const path = `orgs/${org}/recommendationRecipients/${id}`, raw = await tx.get(path);
  // Reject before parsing source, resolving targets or disclosing whether another Member's recommendation exists.
  if (!raw || raw.memberId !== auth.uid) throw new DomainError('permission-denied', 'Recommendation unavailable.');
  const r = parseRecommendationRecipient(raw, org, id);
  const lead = parseRecommendationLead(await tx.get(`orgs/${org}/recommendationLeads/${r.leadId}`), org);
  bindRecommendationRecipient(r, lead);
  if (r.createdAtMillis > now || lead.createdAtMillis > now || (r.deliveredAtMillis ?? 0) > now ||
    [r.memberReadAtMillis, r.acknowledgedAtMillis, r.withdrawnAtMillis, r.dismissedAtMillis].some(t => t !== null && t !== undefined && t > now)) throw queueFailure();
  await verifyRecommendationDelivery(tx, org, r, lead);
  const base: MemberRecommendationDetail = {schemaVersion: 1, mode: 'synthetic_local', organizationId: org, recommendationId: id,
    kind: r.kind, revision: r.revision ?? 0, state: 'unavailable', title: '', summary: '', exerciseLabel: null, objective: null,
    explanations: [], target: null, targetLabel: null, specialization: null, imageUrl: null, photoPath: null,
    createdAtMillis: r.createdAtMillis, deliveredAtMillis: r.deliveredAtMillis ?? null, expiresAtMillis: r.expiresAtMillis,
    readAtMillis: r.memberReadAtMillis, acknowledgedAtMillis: r.acknowledgedAtMillis, dismissedAtMillis: r.dismissedAtMillis ?? null};
  let state: Exclude<MemberRecommendationState, 'available'> | null = r.status === 'prepared' ? 'not_delivered'
    : r.dismissedAtMillis !== null ? 'dismissed' : r.status === 'withdrawn' ? 'withdrawn' : r.expiresAtMillis <= now ? 'expired' : null;
  let detail: MemberRecommendationDetail;
  if (state) detail = redact(base, state);
  else {
    const current = await resolveCurrentRecommendation(tx, deps, lead, now);
    state = current ? null : 'unavailable';
    detail = current ? {...base, state: 'available', title: r.notificationDraft.title,
      summary: 'Your gym reviewed this suggestion for your learning objective.', exerciseLabel: lead.exerciseLabel, objective: lead.objective,
      explanations: structuredClone(lead.ranking.explanations), target: structuredClone(current.target), targetLabel: current.label,
      specialization: current.specialization, imageUrl: current.imageUrl, photoPath: current.photoPath} : redact(base, 'unavailable');
  }
  await requireRecommendationMember(tx, auth, org);
  return {path, recipient: r, detail};
}
/** Safe inbox/detail projection. No writes or external effects; fresh verified Auth/App Check remains a caller boundary. */
export async function projectMemberRecommendation(tx: TransactionPort, deps: RecommendationDeliveryDependencies, auth: InsightsAuth,
  org: string, recommendationId: string, now: number): Promise<MemberRecommendationDetail> {
  return (await loadProjection(tx, deps, auth, org, recommendationId, now)).detail;
}
function replayCommand(raw: unknown, q: MemberCommand, actorId: string, fingerprint: string, recipient: StoredRecommendationRecipient): boolean {
  if (raw === undefined) return false;
  const r = object(raw); keys(r, ['schemaVersion', 'actorId', 'organizationId', 'recommendationId', 'commandId', 'fingerprint', 'action', 'previousRevision', 'revision', 'atMillis']);
  if (r.actorId !== actorId || r.organizationId !== q.organizationId || r.recommendationId !== q.recommendationId || r.commandId !== q.commandId ||
    r.fingerprint !== fingerprint || r.action !== q.action) throw new DomainError('aborted', 'Recommendation command reused.');
  if (r.schemaVersion !== 1 || r.previousRevision !== q.expectedRevision || !queueInteger(r.revision, 1) ||
    ![q.expectedRevision, Number(q.expectedRevision) + 1].includes(r.revision) || r.revision > (recipient.revision ?? 0) || !queueInteger(r.atMillis, recipient.deliveredAtMillis)) throw queueFailure();
  const field = q.action === 'read' ? recipient.memberReadAtMillis : q.action === 'acknowledge' ? recipient.acknowledgedAtMillis : recipient.dismissedAtMillis;
  if (field === null || field === undefined || field > Number(r.atMillis)) throw queueFailure();
  return true;
}
/** Protected local library only; no callable or production composition is registered. */
export function createMemberRecommendationService(deps: RecommendationDeliveryDependencies) {
  return async (request: InsightsRequest): Promise<MemberRecommendationDetail> => {
    try {
      const q = parseCommand(request.data); requireSyntheticDelivery(deps, q.organizationId);
      const auth = await authorizeRecommendationSession(request, deps), now = deliveryNow(deps);
      return await deps.store.transact(async tx => {
        const current = await loadProjection(tx, deps, auth, q.organizationId, q.recommendationId, now);
        if (q.action === 'get' || q.action === 'resolve') return current.detail;
        const {recipient: r, detail} = current, fingerprint = digestOf(q);
        const receiptPath = `orgs/${q.organizationId}/recommendationMemberCommandReceipts/${digestOf({actorId: auth.uid, commandId: q.commandId})}`;
        if (replayCommand(await tx.get(receiptPath), q, auth.uid, fingerprint, r)) return detail;
        if (r.revision !== q.expectedRevision) throw new DomainError('aborted', 'Recommendation revision changed.');
        if (r.status === 'prepared' || q.action !== 'dismiss' && detail.state !== 'available') throw queueFailure();
        const field = q.action === 'read' ? 'memberReadAtMillis' : q.action === 'acknowledge' ? 'acknowledgedAtMillis' : 'dismissedAtMillis';
        const changed = r[field] === null;
        const revision = Number(r.revision) + (changed ? 1 : 0);
        const updated = {...r, [field]: changed ? now : r[field], revision};
        const notificationPath = `orgs/${q.organizationId}/notifications/${r.notificationId}`;
        const notification = q.action === 'read' && changed ? await tx.get(notificationPath) : null;
        await requireRecommendationMember(tx, auth, q.organizationId);
        if (changed) tx.set(current.path, updated);
        if (notification) tx.set(notificationPath, {...notification, read: true});
        tx.create(receiptPath, {schemaVersion: 1, actorId: auth.uid, organizationId: q.organizationId, recommendationId: q.recommendationId,
          commandId: q.commandId, fingerprint, action: q.action, previousRevision: q.expectedRevision, revision, atMillis: now});
        const result: MemberRecommendationDetail = {...detail, revision, readAtMillis: updated.memberReadAtMillis,
          acknowledgedAtMillis: updated.acknowledgedAtMillis, dismissedAtMillis: updated.dismissedAtMillis ?? null};
        return q.action === 'dismiss' ? redact(result, 'dismissed') : result;
      });
    } catch (error) {throw recommendationCommandError(error);}
  };
}
