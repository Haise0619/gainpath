import type { DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { keyOf } from '../../platform/idempotency';
import { allowed, integer, object } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { storedBooking } from './booking-record';

export interface BookingMessageRecord {
  sequence: number; senderRole: 'member' | 'coach'; text: string; sentAtMillis: number;
}
export async function bookingCommunication(store: DocumentStore,
  auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, clock = Date.now) {
  requireVerifiedEmail(auth);
  const input = object(raw);
  allowed(input, ['schemaVersion', 'organizationId', 'bookingId', 'requestId', 'text', 'beforeSequence']);
  if (input.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const id = requiredIdentifier(input.bookingId, 'bookingId');
  const uid = requiredIdentifier(auth!.uid, 'actorId');
  const sending = input.text !== undefined || input.requestId !== undefined;
  const requestId = sending ? requiredIdentifier(input.requestId, 'requestId') : undefined;
  const text = typeof input.text === 'string' ? input.text.trim() : '';
  if (sending && (!text || text.length > 500 || input.beforeSequence !== undefined)) throw new InputValidationError('Enter a message of 1–500 characters.');
  const before = input.beforeSequence === undefined ? undefined : integer(input.beforeSequence, 1);
  const root = `orgs/${org}/bookings/${id}`;
  return store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, uid);
    await requireBookingOrganization(tx, org);
    const b = storedBooking(await tx.get(root), org, id);
    const role = actor.role;
    if (!((role === 'member' && b.memberId === uid) || (role === 'coach' && b.coachId === uid))) {
      throw new DomainError('permission-denied', 'Only this booking’s participants may access messages.');
    }
    if (role === 'coach' && (!actor.branchIds.includes(b.branchId) || (await tx.get(`orgs/${org}/branches/${b.branchId}`))?.status !== 'active')) {
      throw new DomainError('permission-denied', 'Current booking branch access is required.');
    }
    const statePath = `${root}/communicationState/current`;
    const state = await tx.get(statePath);
    const count = state ? integer(state.count, 0, 1000000) : 0;
    if (state && state.schemaVersion !== 1) throw new DomainError('failed-precondition', 'Message history requires review.');
    const receiptPath = `orgs/${org}/commandReceipts/${keyOf('bookingMessage', uid, requestId ?? 'read')}`;
    const receipt = sending ? await tx.get(receiptPath) : undefined;
    const fingerprint = keyOf(org, id, text);
    if (receipt && receipt.fingerprint !== fingerprint) throw new DomainError('already-exists', 'This request was already used for another message.');
    if (sending && !receipt && (!['pending_hold', 'confirmed'].includes(b.status) || (b.status === 'pending_hold' && clock() >= b.holdExpiresAtMillis))) {
      throw new DomainError('failed-precondition', 'This booking no longer accepts new messages.');
    }
    if (sending && !receipt && count >= 1000000) throw new DomainError('resource-exhausted', 'Message history limit reached.');
    const end = Math.min(count, before === undefined ? count : before - 1);
    const first = Math.max(1, end - 49);
    const messages: BookingMessageRecord[] = [];
    for (let sequence = first; sequence <= end; sequence++) {
      const m = await tx.get(`${root}/messages/${sequence}`);
      if (!m || m.sequence !== sequence || !['member', 'coach'].includes(String(m.senderRole)) || typeof m.text !== 'string' || !m.text.trim() || m.text.length > 500 || !Number.isSafeInteger(m.sentAtMillis)) {
        throw new DomainError('failed-precondition', 'Message history requires review.');
      }
      messages.push({ sequence, senderRole: m.senderRole as 'member' | 'coach', text: m.text, sentAtMillis: Number(m.sentAtMillis) });
    }
    if (sending && !receipt) {
      const message: BookingMessageRecord = { sequence: count + 1, senderRole: role as 'member' | 'coach', text, sentAtMillis: integer(clock(), 1) };
      tx.create(`${root}/messages/${message.sequence}`, message);
      tx.set(statePath, { schemaVersion: 1, count: message.sequence, updatedAtMillis: message.sentAtMillis });
      tx.create(receiptPath, { schemaVersion: 1, command: 'bookingMessage', actorId: uid, fingerprint, bookingId: id, sequence: message.sequence, createdAtMillis: message.sentAtMillis });
      messages.push(message);
    }
    return { schemaVersion: 1, bookingId: id, messages, ...(first > 1 ? { nextBeforeSequence: first } : {}) };
  });
}
