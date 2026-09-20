import type { CommandV1 } from '../../platform/command';

/** Contract seam only. No production acceptance handler is exported yet. */
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
