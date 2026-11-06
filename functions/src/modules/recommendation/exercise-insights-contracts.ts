import type {DocumentData, DocumentStore} from '../../platform/firestore/store';

export interface EvidenceScope {readonly organizationId: string; readonly memberId: string}
export interface EvidenceRow {readonly id: string; readonly data: DocumentData}
export interface RecommendationPurposes {
  readonly exerciseInsights: boolean;
  readonly recommendationGeneration: boolean;
  readonly externalAiInference: boolean;
  readonly recommendationDelivery: boolean;
}
/** Proposed contract only: there is deliberately no writer, migration or grant default. */
export interface RecommendationConsent extends EvidenceScope {
  readonly schemaVersion: 1;
  readonly policyVersion: 'module13-purpose-v1-proposed';
  readonly revision: number;
  readonly purposes: RecommendationPurposes;
  readonly grantedAtMillis: number | null;
  readonly revokedAtMillis: number | null;
  readonly updatedAtMillis: number;
}
export type ConsentDecision = {readonly allowed: true; readonly revision: number; readonly fingerprint: string; readonly historyStartAtMillis?: number}
  | {readonly allowed: false; readonly reason: 'missing' | 'invalid' | 'not_granted' | 'revoked'};
export type UnsupportedReason = 'unsupported_exercise' | 'unsupported_scoring_version' | 'unsupported_metric_schema'
  | 'incompatible_camera_view' | 'unsupported_detector' | 'unknown_exercise_mode';
export interface ExerciseCompatibility {
  readonly exerciseId: string;
  readonly metricSchemaVersion: number;
  readonly scoringVersion: string;
  readonly detectorId: string;
  readonly detectorVersion: string;
  readonly cameraView: 'side' | 'front';
  readonly mode: 'not_applicable' | 'both' | 'leftOnly' | 'rightOnly' | 'left' | 'right';
  readonly scoreSupport: 'scored' | 'unscored';
}
interface BackupIdentity {readonly recordKey: string; readonly digest: string; readonly updatedAtMillis: number}
/** Internal only. Never serialize these session identities to an Admin response. */
export interface SessionEvidence extends BackupIdentity {
  readonly kind: 'session';
  readonly endedAtMillis: number;
  readonly localDate: string;
  readonly compatibility: ExerciseCompatibility | null;
  readonly unsupportedReason: UnsupportedReason | null;
  readonly formScorePercent: number | null;
  readonly assessedAttempts: number;
  readonly trackedMicros: number;
  readonly rejectedMicros: number;
  readonly trackingCoverage: number | null;
}
export type ExtractedWorkoutEvidence = SessionEvidence | (BackupIdentity & {readonly kind: 'routine'});

/** All fields must be explicitly supplied by trusted server composition; no default minimums. */
export interface ProvisionalSamplePolicy {
  readonly schemaVersion: 1;
  readonly revision: string;
  readonly minimumScoredSessions: number;
  readonly minimumDistinctDays: number;
  readonly minimumAssessedAttempts: number;
  readonly minimumTrackingCoverage: number;
}
export interface ExerciseInsightsQuery {
  readonly schemaVersion: 1;
  readonly organizationId: string;
  readonly startAtMillis: number;
  readonly endAtMillis: number;
}
export interface InsightsAuth {readonly uid: string; readonly token: Record<string, unknown>}
export interface InsightsRequest {readonly app?: {readonly appId: string}; readonly auth?: InsightsAuth; readonly data: unknown}
export interface FreshAuthIdentity {
  readonly uid: string; readonly email: string; readonly emailVerified: boolean;
  readonly disabled: boolean; readonly tokensValidAfterMillis: number;
}
export interface ExerciseInsightsReader {
  // Organization/member path binding belongs to the trusted reader, never a browser query.
  // Opaque row IDs must be unique and ascending; head and revision copies may share a record key.
  members(organizationId: string, after: string | undefined, limit: number): Promise<readonly EvidenceRow[]>;
  backups(scope: EvidenceScope, after: string | undefined, limit: number): Promise<readonly EvidenceRow[]>;
  // V2 requires a trusted source that bounds history reads before fetching records.
  // Existing payloadJson-only heads cannot supply this guarantee; do not emulate it by post-filtering.
  consentScopedBackups?(scope: EvidenceScope, window: {readonly startAtMillis: number; readonly endAtMillis: number},
    after: string | undefined, limit: number): Promise<readonly EvidenceRow[]>;
}
export interface ExerciseInsightsDependencies {
  readonly fypCapability?: import('../dataset/fyp-scope').FypRuntimeCapability;
  readonly store: DocumentStore;
  readonly reader: ExerciseInsightsReader;
  readonly readAuthIdentity: (uid: string) => Promise<FreshAuthIdentity>;
  readonly clock?: () => number;
  readonly provisionalPolicy?: ProvisionalSamplePolicy | null;
}
export interface ExerciseInsightGroup {
  readonly compatibility: ExerciseCompatibility;
  readonly sessions: number;
  readonly members: number;
  readonly scoredSessions: number;
  readonly missingScoreSessions: number;
  readonly unscoredSessions: number;
  readonly assessedAttempts: number;
  readonly distinctSessionDays: number;
  readonly meanEstimatedFormScore: number | null;
  readonly trackedMicros: number;
  readonly rejectedMicros: number;
  readonly trackingCoverage: number | null;
  readonly membersMeetingProvisionalMinimums: number | null;
  readonly evidenceState: 'policy_not_configured' | 'insufficient_evidence' | 'meets_provisional_minimums'
    | 'no_scored_samples' | 'unscored';
}
export interface ExerciseInsights {
  readonly schemaVersion: 1;
  readonly organizationId: string;
  readonly concept: 'Exercises Needing Attention';
  readonly mode: 'descriptive_only';
  readonly status: 'available' | 'no_consented_members' | 'no_supported_evidence';
  readonly startAtMillis: number;
  readonly endAtMillis: number;
  readonly source: {readonly classification: 'provisional_member_backup'; readonly validation: 'existing_workout_backup_validator';
    readonly scanStartedAtMillis: number; readonly capturedAtMillis: number; readonly timezone: 'Asia/Kuala_Lumpur';
    readonly scoreAggregation: 'equal_member_mean_of_session_means';
    readonly snapshot: 'bounded_non_atomic_scan'; readonly recordsScanned: number; readonly bytesScanned: number};
  readonly coverage: {readonly membersScanned: number; readonly activeMembers: number; readonly consentedMembers: number;
    readonly membersWithoutConsent: number; readonly membersWithBackups: number; readonly membersWithSupportedEvidence: number};
  readonly exclusions: {readonly duplicateRecords: number; readonly routineRecords: number; readonly futureSessions: number;
    readonly outOfWindowSessions: number; readonly unsupportedSessions: number; readonly unsupportedReasons: Partial<Record<UnsupportedReason, number>>};
  readonly samplePolicy: ProvisionalSamplePolicy | null;
  readonly attentionThreshold: null;
  readonly groups: readonly ExerciseInsightGroup[];
}
