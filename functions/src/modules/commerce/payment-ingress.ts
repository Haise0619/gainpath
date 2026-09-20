import type { DocumentStore } from '../../platform/firestore/store';
import { DomainError } from '../../platform/errors';
import { keyOf } from '../../platform/idempotency';
export interface VerifiedPaymentEvent {
  provider: string; eventId: string; billId: string; amountMinor: number; currency: string; status: 'settled' | 'failed';
}
export interface PaymentVerifier {
  readonly provider: string;
  verify(rawBody: Buffer, headers: Readonly<Record<string, string | string[] | undefined>>): Promise<VerifiedPaymentEvent>;
}
export async function receivePaymentEvent(store: DocumentStore, verifier: PaymentVerifier | undefined,
  rawBody: Buffer, headers: Readonly<Record<string, string | string[] | undefined>>) {
  if (!verifier) throw new DomainError('unavailable', 'No supported payment provider is configured.');
  if (!Buffer.isBuffer(rawBody) || rawBody.length === 0 || rawBody.length > 65536) {
    throw new DomainError('invalid-argument', 'Payment payload must contain 1-65536 bytes.');
  }
  let event: VerifiedPaymentEvent;
  try { event = await verifier.verify(rawBody, headers); }
  catch { throw new DomainError('unauthenticated', 'Payment verification failed.'); }
  if (!event || event.provider !== verifier.provider || !/^[a-z0-9-]{1,64}$/.test(event.provider)
    || typeof event.eventId !== 'string' || event.eventId.length < 1 || event.eventId.length > 256
    || typeof event.billId !== 'string' || event.billId.length < 1 || event.billId.length > 256
    || !Number.isSafeInteger(event.amountMinor) || event.amountMinor < 0 || !/^[A-Z]{3}$/.test(event.currency)
    || !['settled', 'failed'].includes(event.status)) {
    throw new DomainError('invalid-argument', 'Invalid verified payment event.');
  }
  const eventKey = keyOf(event.provider, event.eventId);
  const path = `system/paymentIngress/events/${eventKey}`;
  const payloadDigest = keyOf(rawBody.toString('base64'), event.provider, event.eventId, event.billId,
    event.amountMinor, event.currency, event.status);
  return store.transact(async tx => {
    const existing = await tx.get(path);
    if (existing && existing.payloadDigest !== payloadDigest) {
      throw new DomainError('already-exists', 'Payment event identity reused with different payload.');
    }
    if (!existing) tx.create(path, { schemaVersion: 1, event, payloadDigest,
      rawBodyBase64: rawBody.toString('base64'), receivedAtMillis: Date.now(), status: 'received', attempts: 0 });
    // This is a durable inbox acknowledgement, not settlement/entitlement confirmation.
    return { accepted: true as const, eventKey };
  });
}
