import {requireActiveMembership} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {readAll, type TransactionPort} from '../../platform/firestore/store';
import {digestOf, keys, object} from '../workouts/workout-backup-validation';
import type {ConsentDecision, EvidenceScope, InsightsAuth, InsightsRequest, RecommendationPurposes} from './exercise-insights-contracts';
import {authorizeRecommendationSession, recommendationCommandError, type RecommendationCommandDependencies} from './recommendation-configuration';

export type RecommendationPurpose = keyof RecommendationPurposes;
const PURPOSES: readonly RecommendationPurpose[] = ['exerciseInsights', 'recommendationGeneration', 'externalAiInference', 'recommendationDelivery'];
/** Inject only after review. A request cannot supply retained-history authority. */
export interface ReviewedConsentNoticePolicy {
  readonly policyId: string;
  readonly noticeVersion: string;
  readonly contentVersion: string;
  readonly history: {readonly mode: 'from_grant'} | {readonly mode: 'retained'; readonly earliestAtMillis: number};
}
export interface PurposeConsentV2 {
  readonly granted: boolean;
  readonly revision: number;
  readonly grantedAtMillis: number | null;
  readonly revokedAtMillis: number | null;
  readonly noticePolicyId: string | null;
  readonly noticeVersion: string | null;
  readonly contentVersion: string | null;
  readonly historyStartAtMillis: number | null;
}
export interface RecommendationConsentV2 extends EvidenceScope {
  readonly schemaVersion: 2;
  readonly policyVersion: 'module13-purpose-v2-local';
  readonly revision: number;
  readonly purposes: Readonly<Record<RecommendationPurpose, PurposeConsentV2>>;
  readonly updatedAtMillis: number;
}
export interface RecommendationConsentV2Dependencies extends RecommendationCommandDependencies {
  readonly noticePolicies?: readonly ReviewedConsentNoticePolicy[];
}
export interface RecommendationConsentReceipt {
  readonly schemaVersion: 2;
  readonly revision: number;
  readonly purpose: RecommendationPurpose;
  readonly purposeRevision: number;
  readonly granted: boolean;
  readonly noticeVersion: string | null;
  readonly contentVersion: string | null;
  readonly historyStartAtMillis: number | null;
}
const integer = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) >= 0;
const emptyPurpose = (): PurposeConsentV2 => ({granted: false, revision: 0, grantedAtMillis: null, revokedAtMillis: null,
  noticePolicyId: null, noticeVersion: null, contentVersion: null, historyStartAtMillis: null});
function emptyConsent(scope: EvidenceScope, now: number): RecommendationConsentV2 {
  return {...scope, schemaVersion: 2, policyVersion: 'module13-purpose-v2-local', revision: 0, updatedAtMillis: now,
    purposes: Object.fromEntries(PURPOSES.map(p => [p, emptyPurpose()])) as unknown as RecommendationConsentV2['purposes']};
}
function validatedNotice(raw: ReviewedConsentNoticePolicy): ReviewedConsentNoticePolicy {
  const n = object(raw); keys(n, ['policyId', 'noticeVersion', 'contentVersion', 'history']);
  for (const field of ['policyId', 'noticeVersion', 'contentVersion']) requiredIdentifier(n[field], field);
  const h = object(n.history);
  if (h.mode === 'from_grant') keys(h, ['mode']);
  else if (h.mode === 'retained') {
    keys(h, ['mode', 'earliestAtMillis']);
    if (!integer(h.earliestAtMillis)) throw new InputValidationError('Invalid reviewed history boundary.');
  } else throw new InputValidationError('Invalid history review.');
  return structuredClone(raw);
}
export function parseRecommendationConsentV2(raw: unknown, scope: EvidenceScope, now: number): RecommendationConsentV2 {
  const c = object(raw);
  keys(c, ['schemaVersion', 'policyVersion', 'organizationId', 'memberId', 'revision', 'purposes', 'updatedAtMillis']);
  if (c.schemaVersion !== 2 || c.policyVersion !== 'module13-purpose-v2-local' || c.organizationId !== scope.organizationId ||
    c.memberId !== scope.memberId || !integer(now) || !integer(c.revision) || c.revision < 1 ||
    !integer(c.updatedAtMillis) || c.updatedAtMillis > now) throw new InputValidationError('Invalid consent.');
  const purposes = object(c.purposes); keys(purposes, [...PURPOSES]);
  for (const key of PURPOSES) {
    const p = object(purposes[key]);
    keys(p, ['granted', 'revision', 'grantedAtMillis', 'revokedAtMillis', 'noticePolicyId', 'noticeVersion', 'contentVersion', 'historyStartAtMillis']);
    if (typeof p.granted !== 'boolean' || !integer(p.revision) || p.revision > c.revision) throw new InputValidationError('Invalid purpose revision.');
    for (const time of ['grantedAtMillis', 'revokedAtMillis', 'historyStartAtMillis']) {
      if (p[time] !== null && (!integer(p[time]) || Number(p[time]) > c.updatedAtMillis)) throw new InputValidationError('Invalid purpose time.');
    }
    for (const version of ['noticePolicyId', 'noticeVersion', 'contentVersion']) {
      if (p[version] !== null) requiredIdentifier(p[version], version);
    }
    if (p.revision === 0 && (Object.entries(p).some(([k, v]) => k !== 'revision' && k !== 'granted' && v !== null) ||
      p.granted !== false)) throw new InputValidationError('Invalid default purpose.');
    const grantFields = ['grantedAtMillis', 'noticePolicyId', 'noticeVersion', 'contentVersion', 'historyStartAtMillis'];
    const hasGrant = grantFields.some(k => p[k] !== null);
    if (hasGrant && (grantFields.some(k => p[k] === null) || Number(p.historyStartAtMillis) > Number(p.grantedAtMillis))) {
      throw new InputValidationError('Invalid retained grant receipt.');
    }
    if (p.granted && (p.revision < 1 || p.grantedAtMillis === null || p.revokedAtMillis !== null ||
      p.noticePolicyId === null || p.noticeVersion === null || p.contentVersion === null || p.historyStartAtMillis === null ||
      Number(p.historyStartAtMillis) > Number(p.grantedAtMillis))) throw new InputValidationError('Invalid explicit grant.');
    if (!p.granted && p.revision > 0 && p.revokedAtMillis === null) throw new InputValidationError('Missing explicit revocation.');
    if (!p.granted && p.grantedAtMillis !== null && Number(p.revokedAtMillis) < Number(p.grantedAtMillis)) throw new InputValidationError('Invalid revocation time.');
  }
  if (PURPOSES.reduce((sum, key) => sum + Number(object(purposes[key]).revision), 0) !== c.revision) {
    throw new InputValidationError('Invalid consent revision total.');
  }
  return c as unknown as RecommendationConsentV2;
}
const parseConsent = parseRecommendationConsentV2;
/** Default-off, independent of camera/backup permissions. Matching trusted notice is mandatory. */
export function evaluateRecommendationConsentV2(raw: unknown, scope: EvidenceScope, now: number,
  noticePolicies: readonly ReviewedConsentNoticePolicy[] = [], purpose: RecommendationPurpose = 'exerciseInsights'): ConsentDecision {
  if (raw === undefined || raw === null) return {allowed: false, reason: 'missing'};
  try {
    if (typeof purpose !== 'string' || !PURPOSES.includes(purpose)) return {allowed: false, reason: 'invalid'};
    const c = parseConsent(raw, scope, now), p = c.purposes[purpose];
    if (!p.granted) return {allowed: false, reason: p.revokedAtMillis === null ? 'not_granted' : 'revoked'};
    const notices = noticePolicies.map(validatedNotice);
    const matches = notices.filter(n => n.policyId === p.noticePolicyId);
    if (matches.length !== 1) return {allowed: false, reason: 'invalid'};
    const n = matches[0];
    const expectedStart = n.history.mode === 'from_grant' ? p.grantedAtMillis : n.history.earliestAtMillis;
    if (n.noticeVersion !== p.noticeVersion || n.contentVersion !== p.contentVersion || expectedStart !== p.historyStartAtMillis ||
      expectedStart! > p.grantedAtMillis!) return {allowed: false, reason: 'invalid'};
    return {allowed: true, revision: c.revision, fingerprint: digestOf(c), historyStartAtMillis: p.historyStartAtMillis!};
  } catch {return {allowed: false, reason: 'invalid'};}
}
async function authorizeMember(tx: TransactionPort, auth: InsightsAuth, org: string): Promise<void> {
  const [user, member, organization] = await readAll(tx, [`users/${auth.uid}`, `orgs/${org}/members/${auth.uid}`, `orgs/${org}`]);
  if (organization?.status !== 'active' || user?.organizationId !== org || (user.role !== undefined && user.role !== 'member') ||
    member?.organizationId !== org || requireActiveMembership(member).role !== 'member' ||
    (member.userId !== undefined && member.userId !== auth.uid)) throw new DomainError('permission-denied', 'Current Member required.');
  if (user.accountLifecycle !== undefined) {
    const l = object(user.accountLifecycle);
    if (l.schemaVersion !== 1 || l.state !== 'active' || l.revocationPending !== false || !integer(l.sessionNotBeforeSeconds) ||
      !integer(auth.token.auth_time) || auth.token.auth_time < l.sessionNotBeforeSeconds) throw new DomainError('permission-denied', 'Session changed.');
  }
}
/** Local injected command only: no callable, production writer, UI collection or migration. */
export function createRecommendationConsentV2Command(deps: RecommendationConsentV2Dependencies) {
  return async (request: InsightsRequest): Promise<RecommendationConsentReceipt> => {
    try {
      const auth = await authorizeRecommendationSession(request, deps), q = object(request.data);
      const base = ['schemaVersion', 'organizationId', 'commandId', 'expectedRevision', 'purpose', 'action'];
      keys(q, q.action === 'grant' ? [...base, 'noticePolicyId', 'acceptedNoticeVersion', 'acceptedContentVersion'] : base);
      const org = requiredIdentifier(q.organizationId, 'organization'), command = requiredIdentifier(q.commandId, 'command');
      if (q.schemaVersion !== 2 || !integer(q.expectedRevision) || q.expectedRevision >= Number.MAX_SAFE_INTEGER ||
        !PURPOSES.includes(q.purpose as RecommendationPurpose) || (q.action !== 'grant' && q.action !== 'revoke')) throw new InputValidationError('Invalid purpose command.');
      const purpose = q.purpose as RecommendationPurpose, now = (deps.clock ?? Date.now)();
      if (!integer(now)) throw new DomainError('unavailable', 'Invalid clock.');
      let notice: ReviewedConsentNoticePolicy | undefined;
      if (q.action === 'grant') {
        const matches = (deps.noticePolicies ?? []).map(validatedNotice).filter(n => n.policyId === q.noticePolicyId);
        notice = matches.length === 1 ? matches[0] : undefined;
        if (!notice || notice.noticeVersion !== q.acceptedNoticeVersion || notice.contentVersion !== q.acceptedContentVersion ||
          notice.history.mode === 'retained' && notice.history.earliestAtMillis > now) throw new DomainError('failed-precondition', 'Notice requires review.');
      }
      const path = `orgs/${org}/recommendationConsent/${auth.uid}`, scope = {organizationId: org, memberId: auth.uid};
      const commandKey = digestOf({actorId: auth.uid, commandId: command});
      const receiptPath = `orgs/${org}/recommendationConsentReceipts/${commandKey}`, fingerprint = digestOf(q);
      return await deps.store.transact(async tx => {
        await authorizeMember(tx, auth, org);
        const raw = await tx.get(path), receipt = await tx.get(receiptPath);
        if (receipt) {
          if (receipt.fingerprint !== fingerprint) throw new DomainError('aborted', 'Command reused.');
          return receipt.result as unknown as RecommendationConsentReceipt;
        }
        if (raw && raw.schemaVersion !== 2) throw new DomainError('failed-precondition', 'Legacy consent requires explicit reviewed migration.');
        const current = raw ? parseConsent(raw, scope, now) : emptyConsent(scope, now);
        if (current.revision !== q.expectedRevision) throw new DomainError('aborted', 'Revision changed.');
        const previous = current.purposes[purpose];
        const p: PurposeConsentV2 = q.action === 'grant' ? {granted: true, revision: previous.revision + 1,
          grantedAtMillis: now, revokedAtMillis: null, noticePolicyId: notice!.policyId, noticeVersion: notice!.noticeVersion,
          contentVersion: notice!.contentVersion, historyStartAtMillis: notice!.history.mode === 'from_grant' ? now : notice!.history.earliestAtMillis}
          : {...previous, granted: false, revision: previous.revision + 1, revokedAtMillis: now};
        const updated: RecommendationConsentV2 = {...current, revision: current.revision + 1, updatedAtMillis: now,
          purposes: {...current.purposes, [purpose]: p}};
        const result: RecommendationConsentReceipt = {schemaVersion: 2, revision: updated.revision, purpose,
          purposeRevision: p.revision, granted: p.granted, noticeVersion: p.noticeVersion, contentVersion: p.contentVersion,
          historyStartAtMillis: p.granted ? p.historyStartAtMillis : null};
        tx.set(path, updated);
        tx.create(`orgs/${org}/recommendationConsentAudit/${commandKey}`, {schemaVersion: 2, actorId: auth.uid,
          commandId: command, purpose, action: q.action, previousRevision: current.revision, revision: updated.revision,
          noticePolicyId: p.noticePolicyId, noticeVersion: p.noticeVersion, contentVersion: p.contentVersion,
          historyStartAtMillis: p.historyStartAtMillis, atMillis: now, consentFingerprint: digestOf(updated)});
        tx.create(receiptPath, {schemaVersion: 2, fingerprint, result});
        return result;
      });
    } catch (error) {throw recommendationCommandError(error);}
  };
}
