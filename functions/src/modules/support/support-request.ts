import { FieldPath, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { currentBookingMembership, requireBookingOrganization } from '../coaching/booking-validation';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { keyOf } from '../../platform/idempotency';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';

const categories = ['Membership', 'Coach Booking', 'Payment & Refund', 'App Issue', 'Other'];
const denied = () => new DomainError('permission-denied', 'Support request unavailable.');
const invalid = (message: string) => new DomainError('invalid-argument', message);
const pageSize = 30;

function message(value: unknown, max: number) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) {
    throw invalid('Enter a valid title or message.');
  }
  return value.trim();
}

export const supportRequestCommand = onCall({
  region: 'asia-southeast1', enforceAppCheck: true, preserveExternalChanges: true,
}, async request => {
  try {
    requireVerifiedEmail(request.auth);
    const uid = requiredIdentifier(request.auth!.uid, 'actorId');
    const input = request.data;
    if (!input || input.schemaVersion !== 1) throw invalid('Unsupported support request.');
    const org = requiredIdentifier(input.organizationId, 'organizationId');
    const db = getFirestore();
    const root = db.collection('orgs').doc(org);
    const tickets = root.collection('supportRequests');
    const action = input.action;

    return await db.runTransaction(async tx => {
      const facts = {
        get: async (path: string) => (await tx.get(db.doc(path))).data(),
        create: () => { throw Error('Read-only authorization'); },
        set: () => { throw Error('Read-only authorization'); },
      };
      const actor = await currentBookingMembership(facts, org, uid);
      await requireBookingOrganization(facts, org);
      const admin = actor.role === 'admin';
      if (!admin && actor.role !== 'member') throw denied();

      if (action === 'list') {
        let query = admin
          ? tickets.orderBy('updatedAtMillis', 'desc').orderBy(FieldPath.documentId(), 'desc')
          : tickets.where('memberId', '==', uid).orderBy(FieldPath.documentId());
        if (input.afterId != null) {
          const after = await tx.get(tickets.doc(requiredIdentifier(input.afterId, 'afterId')));
          if (!after.exists || (!admin && after.get('memberId') !== uid)) throw denied();
          query = query.startAfter(after);
        }
        const docs = (await tx.get(query.limit(pageSize + 1))).docs;
        return {
          tickets: docs.slice(0, pageSize).map(doc => ({
            ...doc.data(), id: doc.id,
            unread: doc.get(admin ? 'unreadByAdmin' : 'unreadByMember') === true,
          })),
          nextId: docs.length > pageSize ? docs[pageSize - 1].id : null,
        };
      }

      if (action === 'references') {
        if (admin) throw denied();
        const result = [];
        for (const [kind, collection] of [['Booking', 'bookings'], ['Payment', 'transactions']]) {
          const docs = (await tx.get(root.collection(collection).where('memberId', '==', uid).limit(30))).docs;
          for (const doc of docs) {
            const row = doc.data();
            if (row.organizationId !== org) continue;
            const description = [row.planName ?? row.coachName, row.localDate ?? row.startLabel]
              .filter(value => typeof value === 'string' && value.trim()).join(' · ');
            result.push({ kind, id: doc.id, label: description || doc.id });
          }
        }
        return { references: result };
      }

      const now = Date.now();
      if (action === 'create') {
        if (admin) throw denied();
        const title = message(input.title, 120);
        const body = message(input.body, 4000);
        const category = String(input.category);
        if (!categories.includes(category)) throw invalid('Choose a support category.');
        const requestId = requiredIdentifier(input.requestId, 'requestId');
        const ref = tickets.doc(keyOf(uid, requestId));
        const existing = await tx.get(ref);
        if (existing.exists) return { id: ref.id };

        let reference = null;
        if (input.reference != null) {
          const kind = input.reference.kind;
          const id = requiredIdentifier(input.reference.id, 'referenceId');
          if (kind !== 'Booking' && kind !== 'Payment') throw invalid('Invalid reference.');
          const target = (await tx.get(root.collection(kind === 'Booking' ? 'bookings' : 'transactions').doc(id))).data();
          if (!target || target.organizationId !== org || target.memberId !== uid) throw denied();
          reference = { kind, id };
        }
        const member = await tx.get(root.collection('members').doc(uid));
        const name = member.get('displayName');
        tx.create(ref, {
          memberId: uid, memberName: typeof name === 'string' ? name.slice(0, 120) : '',
          title, category, reference, status: 'Open', createdAtMillis: now,
          updatedAtMillis: now, unreadByAdmin: true, unreadByMember: false,
        });
        tx.create(ref.collection('messages').doc('initial'), { body, role: 'Member', createdAtMillis: now });
        return { id: ref.id };
      }

      const ref = tickets.doc(requiredIdentifier(input.ticketId, 'ticketId'));
      const ticket = await tx.get(ref);
      if (!ticket.exists || (!admin && ticket.get('memberId') !== uid)) throw denied();
      const messages = ref.collection('messages');
      if (action === 'detail') {
        let query = messages.orderBy('createdAtMillis', 'desc').orderBy(FieldPath.documentId(), 'desc');
        if (input.beforeId != null) {
          const before = await tx.get(messages.doc(requiredIdentifier(input.beforeId, 'beforeId')));
          if (!before.exists) throw denied();
          query = query.startAfter(before);
        }
        const docs = (await tx.get(query.limit(pageSize + 1))).docs;
        const unread = admin ? 'unreadByAdmin' : 'unreadByMember';
        if (input.beforeId == null && ticket.get(unread) === true) tx.update(ref, { [unread]: false });
        return {
          ticket: { ...ticket.data(), id: ref.id },
          messages: docs.slice(0, pageSize).map(doc => doc.data()).reverse(),
          beforeId: docs.length > pageSize ? docs[pageSize - 1].id : null,
        };
      }

      if (!['reply', 'resolve', 'reopen'].includes(action)) throw invalid('Unsupported support action.');
      if (!admin && action !== 'reply') throw denied();
      const requestId = requiredIdentifier(input.requestId, 'requestId');
      const entry = messages.doc(keyOf(uid, requestId));
      if ((await tx.get(entry)).exists) return { id: ref.id };
      const status = ticket.get('status');
      let nextStatus: string;
      let body: string;
      if (action === 'reply') {
        if (status === 'Resolved') throw new DomainError('failed-precondition', 'This request is closed.');
        body = message(input.body, 4000);
        nextStatus = admin && input.waitForMember === true ? 'Waiting for member' : 'Open';
      } else {
        nextStatus = action === 'resolve' ? 'Resolved' : 'Open';
        if ((status === 'Resolved') === (action === 'resolve')) return { id: ref.id };
        body = action === 'resolve' ? 'Request marked as resolved.' : 'Request reopened.';
      }
      tx.create(entry, { body, role: admin ? 'Admin' : 'Member', createdAtMillis: now });
      tx.update(ref, {
        status: nextStatus, updatedAtMillis: now,
        unreadByAdmin: !admin, unreadByMember: admin,
      });
      return { id: ref.id };
    });
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('internal', 'Support could not complete this request. Please try again.');
  }
});
