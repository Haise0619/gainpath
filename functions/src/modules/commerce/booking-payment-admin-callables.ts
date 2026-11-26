import { XenditRefundGateway } from './xendit-refund';
import { xenditKey } from './xendit-payment-config';
import { getFirestore, FieldPath } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { coachCommandError } from '../coaching/coach-profile-callables';
import { readCoachIdentity } from '../coaching/coach-identity-reader';
import { BillplzSandboxGateway } from './billplz-sandbox';
import { BillplzSandboxRefundGateway } from './billplz-sandbox-refund';
import { getAdminBookingPayment, listAdminBookingPayments, manageAdminBookingPayment, type PaymentAdminDependencies } from './booking-payment-admin';
const apiKey = defineSecret('BILLPLZ_SANDBOX_API_KEY');
const signature = defineSecret('BILLPLZ_SANDBOX_X_SIGNATURE_KEY');
const collection = defineString('BILLPLZ_SANDBOX_COLLECTION_ID', { default: '' });
const org = defineString('BILLPLZ_SANDBOX_ORGANIZATION_ID', { default: 'gainpath' });
const enabled = defineString('BILLPLZ_SANDBOX_ENABLED', { default: 'false' });
const xenditEnabled = defineString('XENDIT_BOOKING_ENABLED', { default: 'false' });
// Deliberately disabled until a separate Sandbox Payment Order collection is approved/configured.
const refundCollection = defineString('BILLPLZ_SANDBOX_REFUND_COLLECTION_ID', { default: '' });
const refundConfigured = () => /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(refundCollection.value());
function check(raw: unknown) { if (enabled.value() !== 'true' && xenditEnabled.value() !== 'true')
    throw new DomainError('unavailable', 'Sandbox payments are disabled.'); if (!raw || typeof raw !== 'object' || (raw as Record<string, unknown>).organizationId !== org.value())
    throw new DomainError('permission-denied', 'Organization unavailable.'); }
function deps(withSecrets = false): PaymentAdminDependencies {
    const db = getFirestore();
    const unavailable = async () => { throw new DomainError('unavailable', 'Provider access unavailable for this command.'); };
    const project = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
    const legacyEnabled = enabled.value() === 'true';
    return {
        collectionId: collection.value(), refundCollectionId: refundCollection.value(), readIdentity: readCoachIdentity,
        refundExecutionConfigured: legacyEnabled && refundConfigured(),
        ...(withSecrets ? { xenditRefunds: new XenditRefundGateway(xenditKey.value()) } : {}),
        bills: withSecrets && legacyEnabled ? new BillplzSandboxGateway({ apiKey: apiKey.value(), collectionId: collection.value(), callbackUrl: `https://us-central1-${project}.cloudfunctions.net/paymentWebhook` }) : { create: unavailable, get: unavailable },
        ...(withSecrets && legacyEnabled && refundConfigured() ? { refunds: new BillplzSandboxRefundGateway({ apiKey: apiKey.value(), signatureKey: signature.value(), collectionId: refundCollection.value() }) } : {}),
        reader: {
            list: async (organization, afterId) => { const ledger = db.collection(`orgs/${organization}/transactions`);
                let query = ledger.orderBy('createdAtMillis', 'desc').orderBy(FieldPath.documentId(), 'desc').limit(21);
                if (afterId) {
                    const cursor = await ledger.doc(afterId).get();
                    if (!cursor.exists || typeof cursor.get('createdAtMillis') !== 'number') {
                        throw new DomainError('invalid-argument', 'Transaction page changed. Refresh the list.');
                    }
                    query = query.startAfter(cursor);
                }
                const rows = await query.get();
                return rows.docs.map(r => ({ id: r.id, data: r.data() })); },
            events: async (organization, id) => { const rows = await db.collection(`orgs/${organization}/transactions/${id}/events`).orderBy('atMillis', 'desc').limit(100).get(); return rows.docs.map(r => ({ id: r.id, data: r.data() })); }
        }
    };
}
export const listAdminBookingPaymentsCommand = onCall({ enforceAppCheck: true, preserveExternalChanges: true }, async (r) => { try {
    check(r.data);
    return await listAdminBookingPayments(new FirestoreStore(getFirestore()), r.auth, r.data, deps());
}
catch (e) {
    throw coachCommandError(e);
} });
export const getAdminBookingPaymentCommand = onCall({ enforceAppCheck: true, preserveExternalChanges: true }, async (r) => { try {
    check(r.data);
    return await getAdminBookingPayment(new FirestoreStore(getFirestore()), r.auth, r.data, deps());
}
catch (e) {
    throw coachCommandError(e);
} });
export const manageAdminBookingPaymentCommand = onCall({ enforceAppCheck: true, secrets: [apiKey, signature, xenditKey] }, async (r) => { try {
    check(r.data);
    return await manageAdminBookingPayment(new FirestoreStore(getFirestore()), r.auth, r.data, deps(true));
}
catch (e) {
    throw coachCommandError(e);
} });
