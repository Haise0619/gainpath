import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError, type ErrorCode} from '../../platform/errors';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {readAll, type DocumentData} from '../../platform/firestore/store';
import {authorizeAdminReport} from '../analytics/admin-reporting';
import {digestOf, keys, object} from '../workouts/workout-backup-validation';
import {aggregateExerciseEvidence, type MemberEvidence} from './exercise-insights-aggregation';
import {evaluateRecommendationConsent} from './recommendation-consent';
import type {ReviewedConsentNoticePolicy} from './recommendation-consent-v2';
import {extractWorkoutEvidence, insightSourceError} from './workout-evidence';
import {extractFypObservationEvidence} from '../dataset/fyp-observations';
import type {EvidenceRow, EvidenceScope, ExerciseInsights, ExerciseInsightsDependencies, ExerciseInsightsQuery,
  ExtractedWorkoutEvidence, InsightsAuth, InsightsRequest, ProvisionalSamplePolicy, SessionEvidence} from './exercise-insights-contracts';

// Cost/safety caps mirror M12's bounds. No scoring or minimum-evidence policy is implied.
export const EXERCISE_INSIGHTS_LIMITS = Object.freeze({members: 2000, activeMembers: 200,
  records: 2000, bytes: 16 * 1024 * 1024, memberPage: 251, backupPage: 25, windowDays: 90});
const DAY = 86400000;
const integer = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) >= 0;
const changed = () => new DomainError('aborted', 'Exercise insight permissions changed.');
const bounded = () => new DomainError('resource-exhausted', 'Exercise insight scan limit exceeded.');
const MESSAGES: Partial<Record<ErrorCode, string>> = {
  unauthenticated: 'Verified sign-in and App Check are required.',
  'permission-denied': 'Current organization Admin access is required.',
  'invalid-argument': 'Invalid exercise insight query or provisional policy.',
  'failed-precondition': 'Exercise insight sources require review.',
  aborted: 'Exercise insight permissions changed. Retry with current consent.',
  'resource-exhausted': 'Exercise insights exceed the bounded scan limit. No partial results were returned.',
  unavailable: 'Exercise insights are temporarily unavailable.',
};
function parseQuery(raw: unknown, now: number): ExerciseInsightsQuery {
  const q = object(raw);
  keys(q, ['schemaVersion', 'organizationId', 'startAtMillis', 'endAtMillis']);
  if (q.schemaVersion !== 1 || !integer(now) || now > 8640000000000000 - DAY ||
    !integer(q.startAtMillis) || !integer(q.endAtMillis) || q.startAtMillis >= q.endAtMillis ||
    q.endAtMillis > now || q.endAtMillis - q.startAtMillis > EXERCISE_INSIGHTS_LIMITS.windowDays * DAY) {
    throw new InputValidationError('Invalid insight window.');
  }
  return {schemaVersion: 1, organizationId: requiredIdentifier(q.organizationId, 'organization'),
    startAtMillis: q.startAtMillis, endAtMillis: q.endAtMillis};
}
function parsePolicy(raw: ProvisionalSamplePolicy | null | undefined): ProvisionalSamplePolicy | null {
  if (raw === null || raw === undefined) return null;
  const p = object(raw);
  keys(p, ['schemaVersion', 'revision', 'minimumScoredSessions', 'minimumDistinctDays', 'minimumAssessedAttempts', 'minimumTrackingCoverage']);
  if (p.schemaVersion !== 1 || !integer(p.minimumScoredSessions) || p.minimumScoredSessions < 1 || p.minimumScoredSessions > 2000 ||
    !integer(p.minimumDistinctDays) || p.minimumDistinctDays < 1 || p.minimumDistinctDays > p.minimumScoredSessions ||
    !integer(p.minimumAssessedAttempts) || p.minimumAssessedAttempts < 1 || p.minimumAssessedAttempts > 20000000 ||
    typeof p.minimumTrackingCoverage !== 'number' || !Number.isFinite(p.minimumTrackingCoverage) || p.minimumTrackingCoverage < 0 || p.minimumTrackingCoverage > 1) {
    throw new InputValidationError('Invalid provisional sample policy.');
  }
  return {schemaVersion: 1, revision: requiredIdentifier(p.revision, 'policyRevision'),
    minimumScoredSessions: p.minimumScoredSessions, minimumDistinctDays: p.minimumDistinctDays,
    minimumAssessedAttempts: p.minimumAssessedAttempts, minimumTrackingCoverage: p.minimumTrackingCoverage};
}
function checkPage(rows: readonly EvidenceRow[], after: string | undefined, limit: number): void {
  if (!Array.isArray(rows) || rows.length > limit) throw insightSourceError();
  let previous = after;
  for (const r of rows) {
    if (!r || typeof r.id !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(r.id) ||
      (previous !== undefined && r.id <= previous) || !r.data || typeof r.data !== 'object' || Array.isArray(r.data)) throw insightSourceError();
    previous = r.id;
  }
}
function canonicalMember(user: DocumentData | undefined, member: DocumentData | undefined, scope: EvidenceScope): string | null {
  if (user?.organizationId !== scope.organizationId || (user.role !== undefined && user.role !== 'member') ||
    member?.organizationId !== scope.organizationId || member.role !== 'member' || member.status !== 'active' ||
    (member.userId !== undefined && member.userId !== scope.memberId) || !Array.isArray(member.branchIds) ||
    !member.branchIds.every(id => typeof id === 'string')) return null;
  const l = user.accountLifecycle;
  if (l !== undefined) {
    if (!l || typeof l !== 'object' || Array.isArray(l)) return null;
    const lifecycle = l as DocumentData;
    if (lifecycle.schemaVersion !== 1 || lifecycle.state !== 'active' || lifecycle.revocationPending !== false ||
      !integer(lifecycle.sessionNotBeforeSeconds)) return null;
  }
  return digestOf({organizationId: user.organizationId, role: user.role ?? 'member',
    lifecycle: l ?? null, membership: member});
}
interface Participant {scope: EvidenceScope; membershipFingerprint: string; consentFingerprint: string; historyStartAtMillis?: number}

/** Local prepared server API. No Cloud Function export, production reader or browser records are added in A1. */
export async function exerciseInsightsHandler(request: InsightsRequest, dependencies: ExerciseInsightsDependencies & {
  readonly consentNoticePolicies?: readonly ReviewedConsentNoticePolicy[];
}): Promise<ExerciseInsights> {
  try {
    if (!request.app || typeof request.app.appId !== 'string' || !request.app.appId.trim() || !request.auth) {
      throw new DomainError('unauthenticated', 'App verification and sign-in required.');
    }
    requireVerifiedEmail(request.auth);
    const auth: InsightsAuth = request.auth;
    requiredIdentifier(auth.uid, 'actor');
    if (typeof auth.token.email !== 'string' || !auth.token.email || !integer(auth.token.auth_time)) {
      throw new DomainError('unauthenticated', 'Verified session required.');
    }
    const clock = dependencies.clock ?? Date.now, started = clock(), q = parseQuery(request.data, started);
    const policy = parsePolicy(dependencies.provisionalPolicy);
    const {store, reader} = dependencies;
    const authorize = async () => {
      const fresh = await dependencies.readAuthIdentity(auth.uid);
      if (!fresh || fresh.uid !== auth.uid || fresh.disabled !== false || fresh.emailVerified !== true ||
        fresh.email !== auth.token.email || !integer(fresh.tokensValidAfterMillis) ||
        Number(auth.token.auth_time) * 1000 < fresh.tokensValidAfterMillis) {
        throw new DomainError('unauthenticated', 'Account session changed.');
      }
      await store.transact(tx => authorizeAdminReport(tx, auth, q.organizationId));
    };
    const readParticipant = async (scope: EvidenceScope): Promise<Participant | null> => store.transact(async tx => {
      await authorizeAdminReport(tx, auth, q.organizationId);
      const [u, m, c] = await readAll(tx, [`users/${scope.memberId}`, `orgs/${scope.organizationId}/members/${scope.memberId}`,
        `orgs/${scope.organizationId}/recommendationConsent/${scope.memberId}`]);
      const fingerprint = canonicalMember(u, m, scope);
      if (!fingerprint) return null;
      const consent = evaluateRecommendationConsent(c, scope, started, dependencies.consentNoticePolicies);
      // The entire requested window must be authorized before even the first history read.
      // V1 synthetic fixtures preserve their A1 contract; v2 always supplies an explicit boundary.
      const permitted = consent.allowed && (consent.historyStartAtMillis === undefined || q.startAtMillis >= consent.historyStartAtMillis);
      return {scope, membershipFingerprint: fingerprint, consentFingerprint: permitted ? consent.fingerprint : '',
        ...(consent.allowed && consent.historyStartAtMillis !== undefined ? {historyStartAtMillis: consent.historyStartAtMillis} : {})};
    });
    const unchanged = async (p: Participant) => {
      const current = await readParticipant(p.scope);
      if (!current || current.membershipFingerprint !== p.membershipFingerprint ||
        current.consentFingerprint !== p.consentFingerprint) throw changed();
    };
    await authorize();
    const memberRows: EvidenceRow[] = [];
    let cursor: string | undefined;
    do {
      await authorize();
      const page = await reader.members(q.organizationId, cursor, EXERCISE_INSIGHTS_LIMITS.memberPage);
      checkPage(page, cursor, EXERCISE_INSIGHTS_LIMITS.memberPage);
      for (const r of page) {
        if (r.data.organizationId !== q.organizationId) throw insightSourceError();
        memberRows.push(r); if (memberRows.length > EXERCISE_INSIGHTS_LIMITS.members) throw bounded();
      }
      if (page.length < EXERCISE_INSIGHTS_LIMITS.memberPage) break;
      cursor = page.at(-1)!.id;
    } while (true);
    let activeMembers = 0, withoutConsent = 0, withBackups = 0, withSupported = 0, records = 0, bytes = 0;
    const participants: Participant[] = [], evidence: MemberEvidence[] = [];
    const exclusions: {duplicateRecords: number; routineRecords: number; futureSessions: number; outOfWindowSessions: number;
      unsupportedSessions: number; unsupportedReasons: ExerciseInsights['exclusions']['unsupportedReasons']} = {
      duplicateRecords: 0, routineRecords: 0, futureSessions: 0, outOfWindowSessions: 0, unsupportedSessions: 0, unsupportedReasons: {}};
    for (const r of memberRows) {
      if (r.data.role !== 'member' || r.data.status !== 'active') continue;
      const p = await readParticipant({organizationId: q.organizationId, memberId: r.id});
      if (!p) continue;
      if (++activeMembers > EXERCISE_INSIGHTS_LIMITS.activeMembers) throw bounded();
      if (p.consentFingerprint) participants.push(p); else withoutConsent++;
    }
    for (const p of participants) {
      if (p.historyStartAtMillis !== undefined && !reader.consentScopedBackups) {
        throw new DomainError('failed-precondition', 'Consent-scoped history source requires review.');
      }
      const seen = new Map<string, ExtractedWorkoutEvidence>();
      let after: string | undefined;
      do {
        await authorize(); await unchanged(p);
        const page = p.historyStartAtMillis === undefined
          ? await reader.backups(p.scope, after, EXERCISE_INSIGHTS_LIMITS.backupPage)
          : await reader.consentScopedBackups!(p.scope, {startAtMillis: q.startAtMillis, endAtMillis: q.endAtMillis}, after, EXERCISE_INSIGHTS_LIMITS.backupPage);
        checkPage(page, after, EXERCISE_INSIGHTS_LIMITS.backupPage);
        for (const row of page) {
          if (++records > EXERCISE_INSIGHTS_LIMITS.records) throw bounded();
          if (typeof row.data.payloadJson !== 'string') throw insightSourceError();
          bytes += Buffer.byteLength(row.data.payloadJson, 'utf8');
          if (bytes > EXERCISE_INSIGHTS_LIMITS.bytes) throw bounded();
          // Validate every copy, even duplicates and unsupported/out-of-window records.
          const extracted = dependencies.fypCapability ? extractFypObservationEvidence(p.scope, row, started, dependencies.fypCapability) : extractWorkoutEvidence(p.scope, row, started), previous = seen.get(extracted.recordKey);
          if (previous) {
            exclusions.duplicateRecords++;
            if (extracted.kind === 'session' && previous.digest !== extracted.digest) throw insightSourceError();
          } else seen.set(extracted.recordKey, extracted);
        }
        if (page.length < EXERCISE_INSIGHTS_LIMITS.backupPage) break;
        after = page.at(-1)!.id;
      } while (true);
      if (seen.size) withBackups++;
      const sessions: SessionEvidence[] = [];
      for (const s of seen.values()) {
        if (s.kind === 'routine') {exclusions.routineRecords++; continue;}
        if (s.endedAtMillis > started) {exclusions.futureSessions++; continue;}
        if (s.endedAtMillis < q.startAtMillis || s.endedAtMillis >= q.endAtMillis) {exclusions.outOfWindowSessions++; continue;}
        if (!s.compatibility) {
          exclusions.unsupportedSessions++;
          const reason = s.unsupportedReason!;
          exclusions.unsupportedReasons[reason] = (exclusions.unsupportedReasons[reason] ?? 0) + 1;
          continue;
        }
        sessions.push(s);
      }
      if (sessions.length) withSupported++;
      evidence.push({memberId: p.scope.memberId, sessions});
    }
    const groups = aggregateExerciseEvidence(evidence, policy);
    // Revoke/role drift discards the entire output, even if the last source page already completed.
    await authorize();
    for (const p of participants) await unchanged(p);
    await authorize();
    const captured = clock();
    if (!integer(captured) || captured < started || captured > 8640000000000000 - DAY) throw insightSourceError();
    return {schemaVersion: 1, organizationId: q.organizationId, concept: 'Exercises Needing Attention', mode: 'descriptive_only',
      status: participants.length === 0 ? 'no_consented_members' : groups.length === 0 ? 'no_supported_evidence' : 'available',
      startAtMillis: q.startAtMillis, endAtMillis: q.endAtMillis,
      source: {classification: 'provisional_member_backup', validation: 'existing_workout_backup_validator',
        scoreAggregation: 'equal_member_mean_of_session_means',
        scanStartedAtMillis: started, capturedAtMillis: captured, timezone: 'Asia/Kuala_Lumpur',
        snapshot: 'bounded_non_atomic_scan', recordsScanned: records, bytesScanned: bytes},
      coverage: {membersScanned: memberRows.length, activeMembers, consentedMembers: participants.length,
        membersWithoutConsent: withoutConsent, membersWithBackups: withBackups, membersWithSupportedEvidence: withSupported},
      exclusions, samplePolicy: policy, attentionThreshold: null, groups};
  } catch (error) {
    const code: ErrorCode = error instanceof InputValidationError ? 'invalid-argument'
      : error instanceof DomainError && MESSAGES[error.code] ? error.code : 'unavailable';
    // Source adapters may throw arbitrary provider/SDK errors, including DomainError instances.
    throw new DomainError(code, MESSAGES[code]!);
  }
}
