import { getFirestore } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { receivePaymentEvent } from './payment-ingress';

// No generic HMAC stand-in: wire a reviewed provider-specific verifier here only
// after signature canonicalization and authenticated event identity are established.
export const paymentWebhook = onRequest(async (request, response) => {
  if (request.method !== 'POST') { response.set('Allow', 'POST').status(405).send('POST required'); return; }
  try {
    const result = await receivePaymentEvent(new FirestoreStore(getFirestore()), undefined, request.rawBody, request.headers);
    response.status(200).json(result);
  } catch (error) {
    const statuses: Record<string, number> = { unavailable: 503, unauthenticated: 401, 'invalid-argument': 400, 'already-exists': 409 };
    response.status(error instanceof DomainError ? (statuses[error.code] ?? 503) : 503)
      .json({ accepted: false, code: error instanceof DomainError ? error.code : 'unavailable' });
  }
});
