import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { requiredIdentifier, InputValidationError } from '../../platform/validation';
import { allowed, object, integer } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
export interface NotificationReader { list(org: string, uid: string, afterId?: string): Promise<{ id: string; data: DocumentData }[]> }
export async function module9MemberCommand(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now, reader?: NotificationReader) {
  requireVerifiedEmail(auth);
  const d = object(raw);
  allowed(d, ['schemaVersion', 'organizationId', 'action', 'enabled', 'expectedRevision', 'notificationId', 'afterId']);
  if (d.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(d.organizationId, 'organizationId'), uid = requiredIdentifier(auth!.uid, 'actorId');
  const authorize = async (tx: Parameters<Parameters<DocumentStore['transact']>[0]>[0]) => {
    const actor = await currentBookingMembership(tx, org, uid);
    await requireBookingOrganization(tx, org);
    if (actor.role !== 'member') throw new DomainError('permission-denied', 'Member access required.');
  };
  if (d.action === 'inbox') {
    if (!reader) throw new DomainError('unavailable', 'Notification inbox unavailable.');
    const afterId = d.afterId === undefined ? undefined : requiredIdentifier(d.afterId, 'afterId');
    await store.transact(authorize);
    const rows = await reader.list(org, uid, afterId);
    await store.transact(authorize);
    if (rows.length > 31) throw new DomainError('failed-precondition', 'Notification list requires review.');
    const records = rows.slice(0, 30).map(({ id, data }) => {
      if (data.schemaVersion !== 1 || data.recipientId !== uid || typeof data.title !== 'string' || typeof data.message !== 'string'
        || !Number.isSafeInteger(data.createdAtMillis) || typeof data.read !== 'boolean') throw new DomainError('failed-precondition', 'Notification requires review.');
      return { id, title: data.title, message: data.message, bookingId: data.bookingId ?? null, createdAtMillis: data.createdAtMillis, read: data.read };
    });
    return { schemaVersion: 1, records, nextAfterId: rows.length > 30 ? rows[29].id : null };
  }
  return store.transact(async tx => {
    await authorize(tx);
    if (d.action === 'sharing') {
      const path = `orgs/${org}/coachSharing/${uid}`, existing = await tx.get(path);
      const revision = existing ? integer(existing.revision, 0) : 0;
      if (d.enabled === undefined) return { schemaVersion: 1, enabled: existing?.enabled === true, revision };
      if (typeof d.enabled !== 'boolean') throw new InputValidationError('enabled must be a boolean.');
      if (integer(d.expectedRevision, 0) !== revision) throw new DomainError('aborted', 'Sharing settings changed. Reload and try again.');
      tx.set(path, { schemaVersion: 1, organizationId: org, memberId: uid, enabled: d.enabled, revision: revision + 1, updatedAtMillis: clock() });
      return { schemaVersion: 1, enabled: d.enabled, revision: revision + 1 };
    }
    if (d.action === 'readNotification') {
      const id = requiredIdentifier(d.notificationId, 'notificationId'), path = `orgs/${org}/notifications/${id}`;
      const n = await tx.get(path);
      if (!n || n.schemaVersion !== 1 || n.recipientId !== uid) throw new DomainError('permission-denied', 'Notification unavailable.');
      tx.set(path, { ...n, read: true });
      return { schemaVersion: 1, id, read: true };
    }
    throw new InputValidationError('Unsupported Member action.');
  });
}
