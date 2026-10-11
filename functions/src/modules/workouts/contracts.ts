import type { CommandV1 } from '../../platform/command';

/** Historical v1 seam; the real acceptance handler rejects this version. */
export interface SubmitWorkoutSessionV1 extends CommandV1 {
  readonly memberId: string;
  readonly sessionId: string;
  readonly exerciseId: string;
  readonly startedAtMillis: number;
  readonly endedAtMillis: number;
  readonly repetitions: number;
  readonly formScorePercent: number | null;
  readonly trackedDurationMillis: number;
  readonly rejectedDurationMillis: number;
  readonly scoringVersion: string;
  readonly detectorVersion: string;
  readonly consentVersion: string;
}
export interface WorkoutAcceptanceV1 {
  readonly schemaVersion: 1;
  readonly requestId: string;
  readonly sessionId: string;
  readonly status: 'accepted';
  readonly acceptedAtMillis: number;
}
export interface WorkoutSubmissionService {
  // Implementations must check current membership/ownership, consent and metric
  // plausibility; atomically deduplicate by member/session AND command key.
  submit(actorId: string, input: SubmitWorkoutSessionV1): Promise<WorkoutAcceptanceV1>;
}

/** Bounded real summary. Production acceptance requires a physically validated
 * enabled model/rule/view tuple; the initial enabled tuple list is empty.
 */
export interface SubmitWorkoutSessionV2 extends Omit<SubmitWorkoutSessionV1, 'schemaVersion'> {
  readonly schemaVersion: 2;
  readonly provenance: 'real_camera';
  readonly publishedRoutineId: string;
  readonly cameraView: 'side';
  readonly detectorId: string;
  readonly consentAcknowledgementId: string;
}

export interface WorkoutAcceptanceV2 extends Omit<WorkoutAcceptanceV1, 'schemaVersion'> {
  readonly schemaVersion: 2;
}

export interface AcknowledgeWorkoutConsentV1 extends CommandV1 {
  readonly memberId: string;
  readonly consentVersion: 'pose-local-summary-v1';
  readonly consented: true;
}

export interface WorkoutConsentAcknowledgementV1 extends CommandV1 {
  readonly memberId: string;
  readonly consentVersion: 'pose-local-summary-v1';
  readonly acknowledgementId: string;
  readonly acknowledgedAtMillis: number;
}

export interface RevokeWorkoutConsentV1 extends CommandV1 {
  readonly memberId: string;
  readonly consentVersion: 'pose-local-summary-v1';
  readonly acknowledgementId: string;
}
export interface WorkoutConsentRevocationV1 extends RevokeWorkoutConsentV1 {
  readonly revokedAtMillis: number;
}

export interface RealWorkoutSubmissionService {
  // Verified auth UID + authoritative active membership + current consent +
  // active eligible catalog/routine row + enabled detector/rule/view versions.
  // Validate chronology/plausibility, then atomically deduplicate both command
  // and member/session keys, rejecting changed payloads. No raw pose data.
  submit(actorId: string, input: SubmitWorkoutSessionV2): Promise<WorkoutAcceptanceV2>;
}
