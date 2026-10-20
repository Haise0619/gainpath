import type { DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { allowed, object } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { WORKOUT_CONSENT_VERSION } from '../workouts/workout-validation';

export interface ClientPostureSessionRecord {
  sessionId: string;
  exerciseId: string;
  completedAtMillis: number;
  overallScore: number;
}

export interface ClientPostureResult {
  schemaVersion: 1;
  memberId: string;
  authorized: boolean;
  sharingStatus: 'granted' | 'consent_not_granted' | 'consent_revoked' | 'unauthorized_relationship';
  measurementsStatus: 'available' | 'measurements_pending_validation';
  message: string;
  sessions: ClientPostureSessionRecord[];
}

export async function getClientPostureHistory(
  store: DocumentStore,
  auth: { uid: string; token: Record<string, unknown> } | undefined,
  raw: unknown
): Promise<ClientPostureResult> {
  requireVerifiedEmail(auth);
  const input = object(raw);
  allowed(input, ['schemaVersion', 'organizationId', 'memberId', 'bookingId']);
  if (input.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const memberId = requiredIdentifier(input.memberId, 'memberId');
  const coachUid = requiredIdentifier(auth!.uid, 'actorId');
  const bookingId = typeof input.bookingId === 'string' && input.bookingId.trim() ? input.bookingId.trim() : undefined;

  return store.transact(async tx => {
    const coachActor = await currentBookingMembership(tx, org, coachUid);
    await requireBookingOrganization(tx, org);

    if (coachActor.role !== 'coach') {
      throw new DomainError('permission-denied', 'Only coaches may query client posture history.');
    }

    if (coachActor.branchIds.length === 0) {
      throw new DomainError('permission-denied', 'Active coach branch assignment is required.');
    }

    // Verify coach-client booking relationship before accessing client workout consent/data
    if (!bookingId) {
      return {
        schemaVersion: 1,
        memberId,
        authorized: false,
        sharingStatus: 'unauthorized_relationship',
        measurementsStatus: 'measurements_pending_validation',
        message: 'A confirmed booking reference is required to verify the coaching relationship.',
        sessions: [],
      };
    }

    const bookingDoc = await tx.get(`orgs/${org}/bookings/${bookingId}`);
    if (
      !bookingDoc ||
      bookingDoc.schemaVersion !== 1 ||
      bookingDoc.organizationId !== org ||
      bookingDoc.coachId !== coachUid ||
      bookingDoc.memberId !== memberId ||
      (bookingDoc.status !== 'confirmed' && bookingDoc.status !== 'completed')
    ) {
      return {
        schemaVersion: 1,
        memberId,
        authorized: false,
        sharingStatus: 'unauthorized_relationship',
        measurementsStatus: 'measurements_pending_validation',
        message: 'No active or completed booking relationship found for this member and session.',
        sessions: [],
      };
    }

    const consentDoc = await tx.get(`orgs/${org}/workoutConsents/${memberId}`);
    if (!consentDoc || consentDoc.schemaVersion !== 1 || consentDoc.consentVersion !== WORKOUT_CONSENT_VERSION) {
      return {
        schemaVersion: 1,
        memberId,
        authorized: false,
        sharingStatus: 'consent_not_granted',
        measurementsStatus: 'measurements_pending_validation',
        message: 'Member has not granted cloud workout sharing consent.',
        sessions: [],
      };
    }

    if (consentDoc.revokedAtMillis !== null) {
      return {
        schemaVersion: 1,
        memberId,
        authorized: false,
        sharingStatus: 'consent_revoked',
        measurementsStatus: 'measurements_pending_validation',
        message: 'Member has revoked workout sharing consent.',
        sessions: [],
      };
    }

    return {
      schemaVersion: 1,
      memberId,
      authorized: true,
      sharingStatus: 'granted',
      measurementsStatus: 'measurements_pending_validation',
      message: 'Cloud measurements pending physical model validation gate.',
      sessions: [],
    };
  });
}
