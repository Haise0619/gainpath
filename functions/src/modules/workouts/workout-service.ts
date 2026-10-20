import { requireActiveMembership, requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { requiredIdentifier } from '../../platform/validation';
import type { WorkoutAcceptanceV2, WorkoutConsentAcknowledgementV1, WorkoutConsentRevocationV1 } from './contracts';
import { parseAcknowledgeWorkoutConsent, parseRevokeWorkoutConsent, parseSubmitWorkoutSession, WORKOUT_CONSENT_VERSION } from './workout-validation';

export interface WorkoutAuth { uid: string; token: Record<string, unknown>; }
export interface WorkoutModelTuple {
  readonly organizationId: string;
  readonly exerciseId: string;
  readonly detectorId: string;
  readonly detectorVersion: string;
  readonly scoringVersion: string;
  readonly cameraView: string;
}
// Deliberately empty until physical model/rule quality acceptance and a reviewed
// policy change. Callables never take tuple policy from request/env/Firestore.
export const ENABLED_WORKOUT_TUPLES: readonly WorkoutModelTuple[] = Object.freeze([]);
function actorOf(auth: WorkoutAuth | undefined, memberId: string): string {
  requireVerifiedEmail(auth);
  const actor = requiredIdentifier(auth!.uid, 'actorId');
  if (actor !== memberId) throw new DomainError('permission-denied', 'Workout member must be the signed-in account.');
  return actor;
}
async function requireMember(tx: TransactionPort, actor: string, org: string): Promise<void> {
  const [user, member] = await Promise.all([tx.get(`users/${actor}`), tx.get(`orgs/${org}/members/${actor}`)]);
  if (user?.organizationId !== org || requireActiveMembership(member).role !== 'member') {
    throw new DomainError('permission-denied', 'An active member of this organization is required.');
  }
}
function nowOf(clock: () => number): number {
  const now = clock();
  if (!Number.isSafeInteger(now) || now <= 0 || now > 8639999996400000) {
    throw new DomainError('failed-precondition', 'Workout server clock is unavailable.');
  }
  return now;
}
function requireConsent(state: DocumentData | undefined, org: string, member: string,
  acknowledgementId: string, latestTime: number): void {
  if (!state || state.schemaVersion !== 1 || state.organizationId !== org || state.memberId !== member ||
      state.consentVersion !== WORKOUT_CONSENT_VERSION || state.acknowledgementId !== acknowledgementId ||
      state.revokedAtMillis !== null || !Number.isSafeInteger(state.acknowledgedAtMillis) ||
      Number(state.acknowledgedAtMillis) <= 0 || Number(state.acknowledgedAtMillis) > latestTime) {
    throw new DomainError('failed-precondition', 'Current workout consent before capture is required.');
  }
}
function checkFingerprint(receipt: DocumentData, fingerprint: string): void {
  if (receipt.fingerprint !== fingerprint) throw new DomainError('already-exists', 'requestId belongs to a different workout command.');
}

export async function acknowledgeWorkoutConsent(store: DocumentStore, auth: WorkoutAuth | undefined,
  raw: unknown, clock: () => number = Date.now): Promise<WorkoutConsentAcknowledgementV1> {
  requireVerifiedEmail(auth);
  const input = parseAcknowledgeWorkoutConsent(raw), actor = actorOf(auth, input.memberId);
  const org = `orgs/${input.organizationId}`, statePath = `${org}/workoutConsents/${actor}`;
  const receiptPath = `${org}/commandReceipts/${keyOf('acknowledgeWorkoutConsent', actor, input.requestId)}`;
  const fingerprint = keyOf(input), now = nowOf(clock);
  return store.transact(async tx => {
    await requireMember(tx, actor, input.organizationId);
    const [state, receipt] = await Promise.all([tx.get(statePath), tx.get(receiptPath)]);
    if (receipt) {
      checkFingerprint(receipt, fingerprint);
      const result = receipt.result as unknown as WorkoutConsentAcknowledgementV1;
      requireConsent(state, input.organizationId, actor, result.acknowledgementId, now);
      return result;
    }
    const result: WorkoutConsentAcknowledgementV1 = { schemaVersion: 1, requestId: input.requestId,
      organizationId: input.organizationId, memberId: actor, consentVersion: WORKOUT_CONSENT_VERSION,
      acknowledgementId: keyOf('workoutConsent', input.organizationId, actor, input.requestId), acknowledgedAtMillis: now };
    tx.set(statePath, { ...result, revokedAtMillis: null });
    tx.create(receiptPath, { fingerprint, result, createdAtMillis: now });
    return result;
  });
}

export async function revokeWorkoutConsent(store: DocumentStore, auth: WorkoutAuth | undefined,
  raw: unknown, clock: () => number = Date.now): Promise<WorkoutConsentRevocationV1> {
  requireVerifiedEmail(auth);
  const input = parseRevokeWorkoutConsent(raw), actor = actorOf(auth, input.memberId);
  const org = `orgs/${input.organizationId}`, statePath = `${org}/workoutConsents/${actor}`;
  const receiptPath = `${org}/commandReceipts/${keyOf('revokeWorkoutConsent', actor, input.requestId)}`;
  const fingerprint = keyOf(input), now = nowOf(clock);
  return store.transact(async tx => {
    await requireMember(tx, actor, input.organizationId);
    const [state, receipt] = await Promise.all([tx.get(statePath), tx.get(receiptPath)]);
    if (receipt) { checkFingerprint(receipt, fingerprint); return receipt.result as unknown as WorkoutConsentRevocationV1; }
    if (!state || state.acknowledgementId !== input.acknowledgementId || state.consentVersion !== WORKOUT_CONSENT_VERSION ||
        state.organizationId !== input.organizationId || state.memberId !== actor || state.schemaVersion !== 1) {
      throw new DomainError('failed-precondition', 'Only the current workout consent can be revoked.');
    }
    if (state.revokedAtMillis !== null && (!Number.isSafeInteger(state.revokedAtMillis) || Number(state.revokedAtMillis) <= 0)) {
      throw new DomainError('failed-precondition', 'Invalid current consent state.');
    }
    const result: WorkoutConsentRevocationV1 = { ...input, revokedAtMillis: state.revokedAtMillis === null ? now : Number(state.revokedAtMillis) };
    tx.set(statePath, { ...state, revokedAtMillis: result.revokedAtMillis });
    tx.create(receiptPath, { fingerprint, result, createdAtMillis: now });
    return result;
  });
}

export async function submitWorkoutSession(store: DocumentStore, auth: WorkoutAuth | undefined,
  raw: unknown, options: { clock?: () => number; enabledTuples?: readonly WorkoutModelTuple[] } = {}): Promise<WorkoutAcceptanceV2> {
  requireVerifiedEmail(auth);
  const input = parseSubmitWorkoutSession(raw), actor = actorOf(auth, input.memberId);
  const now = nowOf(options.clock ?? Date.now);
  const policy = options.enabledTuples ?? ENABLED_WORKOUT_TUPLES;
  const org = `orgs/${input.organizationId}`;
  const receiptPath = `${org}/commandReceipts/${keyOf('submitWorkoutSession', actor, input.requestId)}`;
  const sessionPath = `${org}/workoutSessions/${keyOf(actor, input.sessionId)}`;
  const commandFingerprint = keyOf(input);
  const { requestId: _, ...sessionInput } = input;
  const sessionFingerprint = keyOf(sessionInput);
  return store.transact(async tx => {
    await requireMember(tx, actor, input.organizationId);
    const [consent, exercise, routine, receipt, session] = await Promise.all([
      tx.get(`${org}/workoutConsents/${actor}`), tx.get(`${org}/exerciseVideos/${input.exerciseId}`),
      tx.get(`${org}/content/${input.publishedRoutineId}`), tx.get(receiptPath), tx.get(sessionPath),
    ]);
    requireConsent(consent, input.organizationId, actor, input.consentAcknowledgementId, input.startedAtMillis);
    if (!policy.some(tuple => tuple.organizationId === input.organizationId && tuple.exerciseId === input.exerciseId &&
        tuple.detectorId === input.detectorId && tuple.detectorVersion === input.detectorVersion &&
        tuple.scoringVersion === input.scoringVersion && tuple.cameraView === input.cameraView)) {
      throw new DomainError('failed-precondition', 'This workout model/rule/view is not enabled after physical validation.');
    }
    if (input.endedAtMillis > now || input.repetitions * 600 > input.trackedDurationMillis) {
      throw new DomainError('failed-precondition', 'Workout chronology or repetition evidence is implausible.');
    }
    const rows = routine?.exercises;
    if (exercise?.isActive !== true || routine?.schemaVersion !== 1 || routine.kind !== 'routine' ||
        routine.status !== 'published' || !Array.isArray(rows) || rows.length < 1 || rows.length > 50 ||
        !rows.some(row => row && typeof row === 'object' && row.exerciseId === input.exerciseId &&
          Number.isSafeInteger(row.sets) && row.sets >= 1 && row.sets <= 50 &&
          Number.isSafeInteger(row.reps) && row.reps >= 1 && row.reps <= 100)) {
      throw new DomainError('failed-precondition', 'The published routine exercise is missing or inactive.');
    }
    if (receipt) {
      checkFingerprint(receipt, commandFingerprint);
      if (!session || session.fingerprint !== sessionFingerprint) throw new DomainError('failed-precondition', 'Workout receipt is inconsistent.');
      return receipt.result as unknown as WorkoutAcceptanceV2;
    }
    if (session && session.fingerprint !== sessionFingerprint) {
      throw new DomainError('already-exists', 'sessionId belongs to a different workout summary.');
    }
    if (session && (session.status !== 'accepted' || !Number.isSafeInteger(session.acceptedAtMillis))) {
      throw new DomainError('failed-precondition', 'Workout acceptance is inconsistent.');
    }
    const result: WorkoutAcceptanceV2 = { schemaVersion: 2, requestId: input.requestId, sessionId: input.sessionId,
      status: 'accepted', acceptedAtMillis: session ? Number(session.acceptedAtMillis) : now };
    if (!session) tx.create(sessionPath, { ...input, fingerprint: sessionFingerprint, status: 'accepted', acceptedAtMillis: now });
    tx.create(receiptPath, { fingerprint: commandFingerprint, result, createdAtMillis: now });
    return result;
  });
}
