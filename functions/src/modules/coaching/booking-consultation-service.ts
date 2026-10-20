import type { DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { keyOf } from '../../platform/idempotency';
import { allowed, integer, object } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { storedBooking } from './booking-record';

export async function bookingConsultationNotes(store: DocumentStore,
  auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, clock = Date.now) {
  requireVerifiedEmail(auth);
  const input = object(raw);
  allowed(input, ['schemaVersion', 'organizationId', 'bookingId', 'requestId', 'text']);
  if (input.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const id = requiredIdentifier(input.bookingId, 'bookingId');
  const uid = requiredIdentifier(auth!.uid, 'actorId');
  const publishing = input.text !== undefined || input.requestId !== undefined;
  const requestId = publishing ? requiredIdentifier(input.requestId, 'requestId') : undefined;
  const text = typeof input.text === 'string' ? input.text.trim() : '';
  if (publishing && (!text || text.length > 5000)) throw new InputValidationError('Enter notes of 1–5000 characters.');
  const now = integer(clock(), 1);
  const root = `orgs/${org}/bookings/${id}`;
  return store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, uid);
    await requireBookingOrganization(tx, org);
    const booking = storedBooking(await tx.get(root), org, id);
    const coach = actor.role === 'coach' && booking.coachId === uid;
    const member = actor.role === 'member' && booking.memberId === uid;
    if ((!coach && !member) || (publishing && !coach)) {
      throw new DomainError('permission-denied', 'Only the assigned Coach can publish; only participants can read notes.');
    }
    if (coach && (!actor.branchIds.includes(booking.branchId) ||
        (await tx.get(`orgs/${org}/branches/${booking.branchId}`))?.status !== 'active')) {
      throw new DomainError('permission-denied', 'Current booking branch access is required.');
    }
    const notePath = `${root}/consultation/current`;
    const existing = await tx.get(notePath);
    if (existing && (existing.schemaVersion !== 1 || existing.bookingId !== id ||
        existing.organizationId !== org || existing.coachId !== booking.coachId ||
        existing.memberId !== booking.memberId || typeof existing.text !== 'string' ||
        !existing.text.trim() || existing.text.length > 5000 ||
        !Number.isSafeInteger(existing.publishedAtMillis) ||
        Number(existing.publishedAtMillis) < booking.endAtMillis || booking.status !== 'completed')) {
      throw new DomainError('failed-precondition', 'Consultation notes require authorized review.');
    }
    const receiptPath = `orgs/${org}/commandReceipts/${keyOf('consultationNotes', uid, requestId ?? 'read')}`;
    const receipt = publishing ? await tx.get(receiptPath) : undefined;
    const fingerprint = keyOf(org, id, text);
    if (receipt && (receipt.fingerprint !== fingerprint || receipt.command !== 'consultationNotes' || receipt.actorId !== uid)) {
      throw new DomainError('already-exists', 'This request was already used for different notes.');
    }
    if (receipt && (!existing || existing.text !== text || receipt.bookingId !== id || receipt.publishedAtMillis !== existing.publishedAtMillis)) {
      throw new DomainError('failed-precondition', 'Consultation receipt requires authorized review.');
    }
    const eligible = coach && !existing && booking.status === 'confirmed' && now >= booking.endAtMillis;
    if (publishing && !receipt && !eligible) {
      throw new DomainError('failed-precondition', 'Notes can be published once, after a confirmed session ends.');
    }
    let note = existing ? { text: existing.text as string, publishedAtMillis: Number(existing.publishedAtMillis) } : null;
    if (publishing && !receipt) {
      note = { text, publishedAtMillis: now };
      tx.create(notePath, { schemaVersion: 1, organizationId: org, bookingId: id,
        coachId: booking.coachId, memberId: booking.memberId, ...note });
      tx.set(root, { ...booking, status: 'completed' });
      tx.create(receiptPath, { schemaVersion: 1, command: 'consultationNotes', actorId: uid,
        bookingId: id, fingerprint, publishedAtMillis: now });
    }
    return { schemaVersion: 1, bookingId: id, status: note ? 'completed' : booking.status,
      canPublish: publishing ? false : eligible, note };
  });
}
