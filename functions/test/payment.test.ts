import { expect, it } from 'vitest';
import { receivePaymentEvent, type PaymentVerifier } from '../src/modules/commerce/payment-ingress';
import { MemoryStore } from './memory-store';

const verified = { provider: 'test-provider', eventId: 'event/unsafe-for-path', billId: 'bill-1',
  amountMinor: 1200, currency: 'MYR', status: 'settled' as const };
// Test-only trust implementation. Production deliberately has no provider verifier.
const verifier: PaymentVerifier = { provider: 'test-provider', verify: async () => verified };
const body = Buffer.from('{"bill":"bill-1","paid":true}');
it('fails closed with no configured provider', async () => {
  const store = new MemoryStore();
  await expect(receivePaymentEvent(store, undefined, body, {})).rejects.toMatchObject({ code: 'unavailable' });
  expect(store.documents.size).toBe(0);
});
it('retains verified payload and raw bytes before acknowledging, without a bill mapping', async () => {
  const store = new MemoryStore();
  const result = await receivePaymentEvent(store, verifier, body, {});
  expect(result.accepted).toBe(true);
  expect([...store.documents.keys()][0].split('/')).toHaveLength(4);
  const saved = [...store.documents.values()][0];
  expect(saved.event).toEqual(verified);
  expect(saved.rawBodyBase64).toBe(body.toString('base64'));
  expect(saved.status).toBe('received');
  expect(await receivePaymentEvent(store, verifier, body, {})).toEqual(result);
  expect(store.documents.size).toBe(1);
});
it('rejects tampered duplicate event payloads', async () => {
  const store = new MemoryStore(); await receivePaymentEvent(store, verifier, body, {});
  await expect(receivePaymentEvent(store, verifier, Buffer.from('different'), {})).rejects.toMatchObject({ code: 'already-exists' });
});
it('never stores events from an invalid signature', async () => {
  const store = new MemoryStore();
  await expect(receivePaymentEvent(store, { provider: 'test-provider', verify: async () => { throw new Error('bad signature'); } }, body, {}))
    .rejects.toMatchObject({ code: 'unauthenticated' });
  expect(store.documents.size).toBe(0);
});
