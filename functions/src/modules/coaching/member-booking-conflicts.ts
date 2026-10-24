import type { TransactionPort } from '../../platform/firestore/store';
import { readAll } from '../../platform/firestore/store';
import { DomainError } from '../../platform/errors';
import { SLOT, localDate } from './coach-availability-contracts';
import { validBookingTime, type BookingReservation } from './booking-validation';

// Existing member-day accounting is the contention anchor across Coaches.
// Read only its bounded, active booking IDs; never trust client-supplied times.
export async function memberBusySlots(tx: TransactionPort, org: string, memberId: string, date: string, zone: string, reservations: readonly BookingReservation[]) {
  const rows = await readAll(tx, reservations.map(r => `orgs/${org}/bookings/${r.bookingId}`));
  const blocked = new Set<number>();
  for (const [i, r] of reservations.entries()) {
    const b = rows[i];
    if (!b || b.schemaVersion !== 1 || b.bookingId !== r.bookingId || b.organizationId !== org || b.memberId !== memberId
      // Completion preserves confirmed accounting for the earlier time window.
      || (b.status !== r.status && !(r.status === 'confirmed' && b.status === 'completed'))
      || b.localDate !== date || b.timeZone !== zone || !validBookingTime(b.startAtMillis) || !validBookingTime(b.endAtMillis)
      || b.startAtMillis % SLOT || ![30,60].includes(Number(b.durationMinutes)) || b.endAtMillis-b.startAtMillis !== Number(b.durationMinutes)*60000
      || localDate(b.startAtMillis,zone) !== date || localDate(b.endAtMillis-1,zone) !== date) {
      throw new DomainError('failed-precondition','Member reservations need authorized review.');
    }
    for (let slot=b.startAtMillis;slot<b.endAtMillis;slot+=SLOT) blocked.add(slot);
  }
  return blocked;
}
