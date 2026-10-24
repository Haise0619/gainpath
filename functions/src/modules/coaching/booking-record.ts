import type { DocumentData } from '../../platform/firestore/store';
import { DomainError } from '../../platform/errors';
import { allowed, dateEpoch, localDate, SLOT } from './coach-availability-contracts';
import { validBookingId, validBookingPolicyVersion, validBookingTime, validBookingZone } from './booking-validation';

export const bookingReview = () => new DomainError('failed-precondition', 'Stored booking resources need authorized review.');
export type BookingState = 'pending_hold' | 'confirmed' | 'cancelled' | 'expired' | 'completed' | 'refunded';
export type BookingResolution = 'member_cancelled' | 'hold_expired' | 'coach_cancelled' | 'member_confirmed_cancelled';
export interface StoredBooking extends DocumentData {
  schemaVersion: 1; bookingId: string; organizationId: string; memberId: string; coachId: string; branchId: string; requestId: string; createdBy: string;
  startAtMillis: number; endAtMillis: number; durationMinutes: 30 | 60; status: BookingState;
  holdExpiresAtMillis: number; localDate: string; timeZone: string; policyVersion: string; createdAtMillis: number;
  resolvedAtMillis?: number; resolution?: BookingResolution;
  cancellationReason?: string; cancelledBy?: string;
}
export function storedBooking(data: DocumentData | undefined, org: string, id: string): StoredBooking {
  if (!data) throw new DomainError('not-found', 'Booking unavailable.');
  const d = data;
  try {
    allowed(d, ['schemaVersion', 'bookingId', 'organizationId', 'memberId', 'coachId', 'branchId', 'requestId', 'startAtMillis', 'endAtMillis', 'durationMinutes', 'status', 'holdExpiresAtMillis', 'localDate', 'timeZone', 'policyVersion', 'createdAtMillis', 'createdBy', 'resolvedAtMillis', 'resolution', 'cancellationReason', 'cancelledBy']);
    if (d.schemaVersion !== 1 || d.bookingId !== id || d.organizationId !== org
      || !['bookingId', 'organizationId', 'memberId', 'coachId', 'branchId', 'requestId', 'createdBy'].every(k => validBookingId(d[k]))
      || !['startAtMillis', 'endAtMillis', 'holdExpiresAtMillis', 'createdAtMillis'].every(k => validBookingTime(d[k]))
      || (d.durationMinutes !== 30 && d.durationMinutes !== 60)
      || Number(d.startAtMillis) % SLOT || Number(d.endAtMillis) - Number(d.startAtMillis) !== Number(d.durationMinutes) * 60000
      || Number(d.createdAtMillis) > Number(d.holdExpiresAtMillis) || Number(d.holdExpiresAtMillis) > Number(d.startAtMillis)
      || typeof d.status !== 'string' || !['pending_hold', 'confirmed', 'cancelled', 'expired', 'completed', 'refunded'].includes(d.status)
      || !validBookingZone(d.timeZone) || !validBookingPolicyVersion(d.policyVersion)) throw bookingReview();
    dateEpoch(d.localDate);
    if (localDate(Number(d.startAtMillis), d.timeZone) !== d.localDate || localDate(Number(d.endAtMillis) - 1, d.timeZone) !== d.localDate) throw bookingReview();
    if (d.resolvedAtMillis !== undefined || d.resolution !== undefined || d.status === 'expired') {
      if (!validBookingTime(d.resolvedAtMillis) || d.resolvedAtMillis < Number(d.createdAtMillis)) throw bookingReview();
      if (d.status === 'cancelled') {
        if (d.resolution === 'member_cancelled') {
          if (d.resolvedAtMillis >= Number(d.holdExpiresAtMillis)) throw bookingReview();
        } else if (d.resolution === 'member_confirmed_cancelled') {
          if (Number(d.startAtMillis) - d.resolvedAtMillis < 12 * 3600000 || d.cancelledBy !== d.memberId || typeof d.cancellationReason !== 'string' || !d.cancellationReason.trim() || d.cancellationReason.length > 500) throw bookingReview();
        } else if (d.resolution === 'coach_cancelled') {
          if (d.resolvedAtMillis > Number(d.startAtMillis)) throw bookingReview();
          if (d.cancellationReason !== undefined && (typeof d.cancellationReason !== 'string' || !d.cancellationReason.trim() || d.cancellationReason.length > 500)) throw bookingReview();
          if (d.cancelledBy !== undefined && !validBookingId(d.cancelledBy)) throw bookingReview();
        } else {
          throw bookingReview();
        }
      } else if (d.status === 'expired') {
        if (d.resolution !== 'hold_expired' || d.resolvedAtMillis < Number(d.holdExpiresAtMillis)) throw bookingReview();
      } else {
        throw bookingReview();
      }
    }
    return d as StoredBooking;
  } catch { throw bookingReview(); }
}
