import { createHmac } from 'node:crypto';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { BillplzSandboxRefundGateway } from '../src/modules/commerce/billplz-sandbox-refund';

const id = 'cc92738f-dfda-4969-91dc-22a44afc7e26';
const collectionId = '8f4e331f-ac71-435e-a870-72fe520b4563';
const config = { apiKey: 'server-secret', signatureKey: 'literal-signature-secret', collectionId };
const input = { reference: 'refund-booking-1', amountMinor: 1200, name: 'Actual payer private name', description: 'Sandbox refund booking 1' };
const response = { id, payment_order_collection_id: collectionId, bank_code: 'DUMMYBANKVERIFIED', bank_account_number: '0000000000', reference_id: input.reference, total: '1200', status: 'enquiring' };
const epoch = '1700000000';
const sign = (source: string) => createHmac('sha512', config.signatureKey).update(source).digest('hex');
const transport = (value: unknown) => vi.fn(async () => new Response(JSON.stringify(value))) as unknown as typeof fetch;
afterEach(() => vi.useRealTimers());

describe('Sandbox Payment Order refunds', () => {
  it('binds create/get to sandbox, dummy recipient and exact V5 checksums', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify(response))) as unknown as typeof fetch;
    const gateway = new BillplzSandboxRefundGateway(config, fetcher, () => 1700000000000);
    expect(await gateway.create(input)).toEqual({ id, collectionId, reference: input.reference, amountMinor: 1200, status: 'enquiring' });
    await gateway.get(id);
    const calls = vi.mocked(fetcher).mock.calls;
    expect(calls[0][0]).toBe('https://www.billplz-sandbox.com/api/v5/payment_orders');
    const init = calls[0][1]!;
    const body = new URLSearchParams(String(init.body));
    expect(Object.fromEntries(body)).toMatchObject({ payment_order_collection_id: collectionId, bank_code: 'DUMMYBANKVERIFIED', bank_account_number: '0000000000', total: '1200', reference_id: input.reference, epoch, notification: 'false', recipient_notification: 'false', checksum: sign(`${collectionId}00000000001200${epoch}`) });
    expect(body.get('name')).toBe('GainPath Sandbox Refund');
    expect(String(init.body)).not.toContain('Actual');
    expect(init.redirect).toBe('error');
    expect(init.headers).toMatchObject({ Authorization: `Basic ${Buffer.from('server-secret:').toString('base64')}` });
    const getUrl = new URL(String(calls[1][0]));
    expect(getUrl.pathname).toBe(`/api/v5/payment_orders/${id}`);
    expect(getUrl.searchParams.get('checksum')).toBe(sign(`${id}${epoch}`));
    expect(getUrl.searchParams.get('epoch')).toBe(epoch);
    expect(getUrl.toString()).not.toContain(config.apiKey);
  });
  it('accepts integer total, single zero dummy bank account and normalized dummy bank code with V5 status', async () => {
    const gateway = new BillplzSandboxRefundGateway(config, transport({ ...response, total: 1200, bank_code: 'dummybankverified', bank_account_number: '0', status: 'completed' }));
    expect(await gateway.create(input)).toEqual({ id, collectionId, reference: input.reference, amountMinor: 1200, status: 'completed' });
  });
  it.each([
    { total: '1201' }, { total: 1201 }, { total: '01200' }, { total: '1.2e3' },
    { total: 0 }, { total: '0' }, { total: -100 }, { total: '-100' },
    { total: 1200.5 }, { total: '1200.5' }, { total: ' 1200 ' }, { total: '1200sen' },
    { total: Number.MAX_SAFE_INTEGER + 1 }, { total: '9007199254740992' },
    { reference_id: 'different' }, { payment_order_collection_id: id },
    { bank_code: 'MBBEMYKL' }, { bank_account_number: '1234567890' },
    { id: '../escape' }, { status: 'unknown' }, { status: 'paid' }, { status: 'settled' }, { status: 'success' },
  ])('rejects mismatched or malformed create response %j', async patch => {
    await expect(new BillplzSandboxRefundGateway(config, transport({ ...response, ...patch })).create(input)).rejects.toThrow('Sandbox refund provider request failed.');
  });
  it('does not duplicate error logs on response validation failure', async () => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const gateway = new BillplzSandboxRefundGateway(config, transport({ ...response, total: 'bad' }));
      await expect(gateway.create(input)).rejects.toThrow();
      expect(errorSpy).toHaveBeenCalledTimes(1);
      expect(errorSpy.mock.calls[0][0]).toBe('[BILLPLZ_V5_VALIDATION_FAILED]');
    } finally {
      errorSpy.mockRestore();
    }
  });
  it('logs request exception exactly once on unexpected transport failure', async () => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const fetcher = vi.fn(async () => { throw new TypeError('Network connection refused'); }) as unknown as typeof fetch;
      const gateway = new BillplzSandboxRefundGateway(config, fetcher);
      await expect(gateway.create(input)).rejects.toThrow();
      expect(errorSpy).toHaveBeenCalledTimes(1);
      expect(errorSpy.mock.calls[0][0]).toBe('[BILLPLZ_V5_REQUEST_EXCEPTION]');
      expect(errorSpy.mock.calls[0][1]).toBe('TypeError');
    } finally {
      errorSpy.mockRestore();
    }
  });
  it.each(['processing', 'enquiring', 'executing', 'reviewing', 'completed', 'refunded'] as const)(
    'accepts official Billplz V5 payment order status: %s',
    async (status) => {
      const gateway = new BillplzSandboxRefundGateway(config, transport({ ...response, total: 1200, status }));
      const order = await gateway.get(id);
      expect(order.status).toBe(status);
    }
  );
  it('binds GET response ID and never converts refunded status to success', async () => {
    await expect(new BillplzSandboxRefundGateway(config, transport({ ...response, id: collectionId })).get(id)).rejects.toThrow();
    expect((await new BillplzSandboxRefundGateway(config, transport({ ...response, status: 'refunded' })).get(id)).status).toBe('refunded');
  });
  it('rejects unsafe inputs before transport', async () => {
    const fetcher = transport(response);
    const gateway = new BillplzSandboxRefundGateway(config, fetcher);
    for (const bad of ['https://example.com', '../escape', `${id}?secret=x`]) await expect(gateway.get(bad)).rejects.toThrow();
    for (const amountMinor of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) await expect(gateway.create({ ...input, amountMinor })).rejects.toThrow();
    await expect(gateway.create({ ...input, reference: '' })).rejects.toThrow();
    expect(fetcher).not.toHaveBeenCalled();
    expect(() => new BillplzSandboxRefundGateway({ ...config, apiKey: 'bad:key' })).toThrow();
    expect(() => new BillplzSandboxRefundGateway({ ...config, signatureKey: '' })).toThrow();
    expect(() => new BillplzSandboxRefundGateway({ ...config, collectionId: 'https://live.example' })).toThrow();
  });
  it('sanitizes errors without retrying', async () => {
    const fetcher = vi.fn(async () => { throw new Error('server-secret bank account private'); }) as unknown as typeof fetch;
    await expect(new BillplzSandboxRefundGateway(config, fetcher).create(input)).rejects.toThrow(/^Sandbox refund provider request failed\.$/);
    expect(fetcher).toHaveBeenCalledTimes(1);
    await expect(new BillplzSandboxRefundGateway(config, (async () => new Response('private', { status: 422 })) as typeof fetch).create(input)).rejects.toThrow(/^Sandbox refund provider request failed\.$/);
  });
  it('times out a noncooperative transport after 10 seconds without retry', async () => {
    vi.useFakeTimers();
    const fetcher = vi.fn(() => new Promise<Response>(() => {})) as unknown as typeof fetch;
    const pending = new BillplzSandboxRefundGateway(config, fetcher).create(input);
    const rejected = expect(pending).rejects.toThrow('Sandbox refund provider request failed.');
    await vi.advanceTimersByTimeAsync(10000);
    await rejected;
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(vi.mocked(fetcher).mock.calls[0][1]?.signal?.aborted).toBe(true);
  });
});
