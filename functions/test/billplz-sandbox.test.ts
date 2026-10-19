import { createHmac } from 'node:crypto';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { BillplzSandboxGateway, verifyBillplzCallback } from '../src/modules/commerce/billplz-sandbox';
const config = { apiKey: 'test-secret', collectionId: 'collection1', callbackUrl: 'https://example.com/callback', redirectUrl: 'https://example.com/return' };
const input = { amountMinor: 1200, name: 'Member', email: 'member@example.com', reference: 'order1', organizationId: 'org1', description: 'Membership' };
const bill = { id: 'bill1', collection_id: 'collection1', amount: 1200, paid: false, paid_amount: 0, state: 'due', url: 'https://www.billplz-sandbox.com/bills/bill1', reference_1: 'order1', reference_2: 'org1' };
function signed(fields: Record<string, string>, key = 'abcdef012345') {
  // Independently specified canonical source, including paid_amount sorting before paid.
  const source = 'amount1200|collection_idcollection1|idbill1|paid_amount0|paidfalse';
  return new URLSearchParams({ ...fields, x_signature: createHmac('sha256', key).update(source).digest('hex') }).toString();
}
const fields = { paid: 'false', id: 'bill1', paid_amount: '0', collection_id: 'collection1', amount: '1200' };
afterEach(() => vi.useRealTimers());
describe('Billplz callback verification', () => {
  it('verifies decoded, reordered fields with the literal signature key', () => {
    expect(verifyBillplzCallback(Buffer.from(signed(fields)), 'abcdef012345')).toEqual(fields);
    expect(verifyBillplzCallback(Buffer.from(signed(fields).replace('bill1', 'bill%31')), 'abcdef012345')).toEqual(fields);
  });
  it.each(['&id=other', '&paid[]=false', '&x_signature=bad'])('rejects duplicate or array fields: %s', suffix => {
    expect(() => verifyBillplzCallback(Buffer.from(signed(fields) + suffix), 'abcdef012345')).toThrow();
  });
  it('rejects tampering, missing signatures and excessive payloads', () => {
    for (const raw of [signed(fields).replace('1200', '1201'), 'id=bill1', 'a'.repeat(65537)]) {
      expect(() => verifyBillplzCallback(Buffer.from(raw), 'abcdef012345')).toThrow();
    }
  });
});
describe('Billplz sandbox gateway', () => {
  it('posts exact sandbox form and reads a bill using Basic authentication', async () => {
    const requests: Array<{url: string; init: RequestInit}> = [];
    const fetcher = (async (url, init) => { requests.push({url: String(url), init: init!}); return new Response(JSON.stringify(bill)); }) as typeof fetch;
    const gateway = new BillplzSandboxGateway(config, fetcher);
    expect(await gateway.create(input)).toEqual(bill);
    expect(await gateway.get('bill1')).toEqual(bill);
    expect(requests[0].url).toBe('https://www.billplz-sandbox.com/api/v3/bills');
    expect(new Headers(requests[0].init.headers).get('authorization')).toBe(`Basic ${Buffer.from('test-secret:').toString('base64')}`);
    expect(Object.fromEntries(new URLSearchParams(String(requests[0].init.body)))).toEqual({ collection_id: 'collection1', email: input.email, name: 'Member', amount: '1200', callback_url: config.callbackUrl, redirect_url: config.redirectUrl, description: 'Membership', reference_1: 'order1', reference_2: 'org1' });
    expect(requests[0].init.redirect).toBe('error');
    expect(requests[1].url).toBe('https://www.billplz-sandbox.com/api/v3/bills/bill1');
  });
  it.each([{amount: 1.2}, {collection_id: 'other'}, {id: '../bad'}, {paid: 'false'}, {paid_amount: -1}, {url: 'https://billplz.com/bills/a'}, {url: 'http://billplz-sandbox.com/bills/a'}, {url: 'https://user:pass@billplz-sandbox.com/bills/a'}])('rejects untrusted provider data %j', async patch => {
    const gateway = new BillplzSandboxGateway(config, (async () => new Response(JSON.stringify({...bill, ...patch}))) as typeof fetch);
    await expect(gateway.create(input)).rejects.toMatchObject({ code: 'unavailable' });
  });
  it('does not retry or leak upstream errors', async () => {
    let calls = 0;
    const gateway = new BillplzSandboxGateway(config, (async () => { calls++; throw new Error('test-secret https://secret.example'); }) as typeof fetch);
    await expect(gateway.create(input)).rejects.toMatchObject({code: 'unavailable', message: 'Sandbox payment provider request failed.'});
    expect(calls).toBe(1);
  });
  it('bounds hanging requests', async () => {
    vi.useFakeTimers();
    const gateway = new BillplzSandboxGateway(config, (async () => new Promise(() => {})) as typeof fetch);
    const pending = gateway.create(input);
    const assertion = expect(pending).rejects.toMatchObject({code: 'unavailable'});
    await vi.advanceTimersByTimeAsync(15000);
    await assertion;
  });
  it('rejects unsafe configuration and IDs before fetching', async () => {
    expect(() => new BillplzSandboxGateway({...config, callbackUrl: 'http://example.com'})).toThrow();
    const gateway = new BillplzSandboxGateway(config);
    await expect(gateway.get('../secret')).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(gateway.create({...input, amountMinor: 1.5})).rejects.toMatchObject({code: 'invalid-argument'});
  });
});
