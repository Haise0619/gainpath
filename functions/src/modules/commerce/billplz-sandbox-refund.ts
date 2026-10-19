import { createHmac } from 'node:crypto';
import { DomainError } from '../../platform/errors';

export interface SandboxRefundOrder {
  id: string;
  collectionId: string;
  reference: string;
  amountMinor: number;
  // `refunded` means the disbursement was reversed, never customer refund success.
  status: 'processing' | 'enquiring' | 'executing' | 'reviewing' | 'completed' | 'refunded';
}
type CreateRefund = { reference: string; amountMinor: number; name: string; description: string };
export interface SandboxRefundGateway {
  create(input: CreateRefund): Promise<SandboxRefundOrder>;
  get(id: string): Promise<SandboxRefundOrder>;
}
type Config = { apiKey: string; signatureKey: string; collectionId: string };
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const referencePattern = /^[a-zA-Z0-9_-]{1,255}$/;
const statuses: readonly string[] = ['processing', 'enquiring', 'executing', 'reviewing', 'completed', 'refunded'];
const failure = () => new DomainError('unavailable', 'Sandbox refund provider request failed.');

/** Server-only V5 adapter: fixed sandbox host and synthetic bank details only. */
export class BillplzSandboxRefundGateway implements SandboxRefundGateway {
  private readonly config: Config;
  constructor(config: Config, private readonly fetcher: typeof fetch = fetch, private readonly clock: () => number = Date.now) {
    if (!config || typeof config.apiKey !== 'string' || !config.apiKey || /[:\r\n]/.test(config.apiKey)
      || typeof config.signatureKey !== 'string' || !config.signatureKey || /[\r\n]/.test(config.signatureKey)
      || typeof config.collectionId !== 'string' || !uuid.test(config.collectionId)) {
      throw new DomainError('failed-precondition', 'Invalid sandbox refund provider configuration.');
    }
    this.config = { apiKey: config.apiKey, signatureKey: config.signatureKey, collectionId: config.collectionId };
  }
  async create(input: CreateRefund): Promise<SandboxRefundOrder> {
    if (!input || !Number.isSafeInteger(input.amountMinor) || input.amountMinor <= 0
      || typeof input.reference !== 'string' || !referencePattern.test(input.reference)
      || typeof input.description !== 'string' || !/^[a-zA-Z0-9 ._-]{1,200}$/.test(input.description)) {
      throw new DomainError('invalid-argument', 'Invalid sandbox refund request.');
    }
    const epoch = this.epoch();
    const total = String(input.amountMinor);
    const body = new URLSearchParams({ payment_order_collection_id: this.config.collectionId,
      bank_code: 'DUMMYBANKVERIFIED', bank_account_number: '0000000000', name: 'GainPath Sandbox Refund',
      description: input.description, total, reference_id: input.reference, notification: 'false',
      recipient_notification: 'false', epoch,
      checksum: this.checksum(`${this.config.collectionId}0000000000${total}${epoch}`) });
    // No automatic retries: uncertain create outcomes require manual reconciliation by ID.
    const order = await this.request('', { method: 'POST', body: body.toString(), headers: { 'Content-Type': 'application/x-www-form-urlencoded' } });
    if (order.reference !== input.reference || order.amountMinor !== input.amountMinor) throw failure();
    return order;
  }
  async get(id: string): Promise<SandboxRefundOrder> {
    if (typeof id !== 'string' || !uuid.test(id)) throw new DomainError('invalid-argument', 'Invalid sandbox refund order ID.');
    const epoch = this.epoch();
    const query = new URLSearchParams({ epoch, checksum: this.checksum(`${id}${epoch}`) });
    const order = await this.request(`/${id}?${query}`, { method: 'GET' });
    if (order.id !== id) throw failure();
    return order;
  }
  private epoch(): string {
    const seconds = Math.floor(this.clock() / 1000);
    if (!Number.isSafeInteger(seconds) || seconds <= 0) throw failure();
    return String(seconds);
  }
  private checksum(source: string): string {
    return createHmac('sha512', this.config.signatureKey).update(source).digest('hex');
  }
  private async request(path: string, init: RequestInit): Promise<SandboxRefundOrder> {
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const timeout = new Promise<never>((_, reject) => {
        timer = setTimeout(() => { controller.abort(); reject(failure()); }, 10000);
      });
      const operation = async (): Promise<SandboxRefundOrder> => {
        const response = await this.fetcher(`https://www.billplz-sandbox.com/api/v5/payment_orders${path}`, {
          ...init, redirect: 'error', signal: controller.signal,
          headers: { ...init.headers, Authorization: `Basic ${Buffer.from(`${this.config.apiKey}:`).toString('base64')}` },
        });
        if (!response.ok) throw failure();
        const value: unknown = await response.json();
        if (!value || typeof value !== 'object' || Array.isArray(value)) throw failure();
        const order = value as Record<string, unknown>;
        if (typeof order.id !== 'string' || !uuid.test(order.id) || order.payment_order_collection_id !== this.config.collectionId
          || order.bank_code !== 'DUMMYBANKVERIFIED' || order.bank_account_number !== '0000000000'
          || typeof order.reference_id !== 'string' || !referencePattern.test(order.reference_id)
          || typeof order.total !== 'string' || !/^[1-9][0-9]*$/.test(order.total)
          || !Number.isSafeInteger(Number(order.total)) || typeof order.status !== 'string' || !statuses.includes(order.status)) throw failure();
        return { id: order.id, collectionId: this.config.collectionId, reference: order.reference_id,
          amountMinor: Number(order.total), status: order.status as SandboxRefundOrder['status'] };
      };
      return await Promise.race([operation(), timeout]);
    } catch { throw failure(); }
    finally { if (timer !== undefined) clearTimeout(timer); }
  }
}
