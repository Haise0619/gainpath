import { createHmac, timingSafeEqual } from 'node:crypto';
import { DomainError } from '../../platform/errors';

export interface SandboxBill {
  id: string; collection_id: string; amount: number; paid: boolean; paid_amount: number;
  state: 'due' | 'paid' | 'deleted'; url: string; reference_1?: string; reference_2?: string;
}
type CreateBill = { amountMinor: number; name: string; email: string; reference: string; organizationId: string; description: string };
export interface BillplzGateway {
  create(input: CreateBill): Promise<SandboxBill>;
  get(id: string): Promise<SandboxBill>;
}
type Config = { apiKey: string; collectionId: string; callbackUrl: string; redirectUrl?: string };
const idPattern = /^[a-zA-Z0-9_-]{1,128}$/;
function secureUrl(value: unknown, sandbox = false): boolean {
  if (typeof value !== 'string') return false;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password && (!url.port || url.port === '443')
      && (!sandbox || ['www.billplz-sandbox.com', 'billplz-sandbox.com'].includes(url.hostname));
  } catch { return false; }
}
const providerFailure = () => new DomainError('unavailable', 'Sandbox payment provider request failed.');
export class BillplzSandboxGateway implements BillplzGateway {
  private readonly config: Config;
  constructor(config: Config, private readonly fetcher: typeof fetch = fetch) {
    if (!config || typeof config.apiKey !== 'string' || !config.apiKey || /[:\r\n]/.test(config.apiKey)
      || !idPattern.test(config.collectionId) || !secureUrl(config.callbackUrl)
      || (config.redirectUrl !== undefined && !secureUrl(config.redirectUrl))) {
      throw new DomainError('failed-precondition', 'Invalid sandbox payment provider configuration.');
    }
    this.config = { ...config };
  }
  async create(input: CreateBill): Promise<SandboxBill> {
    if (!input || !Number.isSafeInteger(input.amountMinor) || input.amountMinor <= 0
      || [input.name, input.email, input.reference, input.organizationId, input.description].some(v => typeof v !== 'string' || !v.trim() || v.length > 2048)) {
      throw new DomainError('invalid-argument', 'Invalid sandbox bill request.');
    }
    const body = new URLSearchParams({ collection_id: this.config.collectionId, email: input.email,
      name: input.name, amount: String(input.amountMinor), callback_url: this.config.callbackUrl,
      description: input.description, reference_1: input.reference, reference_2: input.organizationId });
    if (this.config.redirectUrl) body.set('redirect_url', this.config.redirectUrl);
    const bill = await this.request('/bills', { method: 'POST', body: body.toString(), headers: { 'Content-Type': 'application/x-www-form-urlencoded' } });
    if (bill.amount !== input.amountMinor || bill.reference_1 !== input.reference || bill.reference_2 !== input.organizationId) throw providerFailure();
    return bill;
  }
  async get(id: string): Promise<SandboxBill> {
    if (typeof id !== 'string' || !idPattern.test(id)) throw new DomainError('invalid-argument', 'Invalid sandbox bill ID.');
    const bill = await this.request(`/bills/${id}`, { method: 'GET' });
    if (bill.id !== id) throw providerFailure();
    return bill;
  }
  private async request(path: string, init: RequestInit): Promise<SandboxBill> {
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      // A timeout also bounds custom transports that do not honour AbortSignal.
      const timeout = new Promise<never>((_, reject) => { timer = setTimeout(() => { controller.abort(); reject(providerFailure()); }, 10000); });
      const operation = async () => {
        const response = await this.fetcher(`https://www.billplz-sandbox.com/api/v3${path}`, {
          ...init, redirect: 'error', signal: controller.signal,
          headers: { ...init.headers, Authorization: `Basic ${Buffer.from(`${this.config.apiKey}:`).toString('base64')}` },
        });
        if (!response.ok) throw providerFailure();
        const value: unknown = await response.json();
        if (!value || typeof value !== 'object' || Array.isArray(value)) throw providerFailure();
        const b = value as Record<string, unknown>;
        if (typeof b.id !== 'string' || !idPattern.test(b.id) || b.collection_id !== this.config.collectionId
          || !Number.isSafeInteger(b.amount) || (b.amount as number) <= 0 || !Number.isSafeInteger(b.paid_amount) || (b.paid_amount as number) < 0
          || typeof b.paid !== 'boolean' || !['due', 'paid', 'deleted'].includes(String(b.state)) || !secureUrl(b.url, true)
          || (b.reference_1 !== undefined && typeof b.reference_1 !== 'string')
          || (b.reference_2 !== undefined && typeof b.reference_2 !== 'string')) throw providerFailure();
        return { id: b.id, collection_id: b.collection_id, amount: b.amount, paid: b.paid, paid_amount: b.paid_amount,
          state: b.state, url: b.url, ...(b.reference_1 !== undefined ? {reference_1: b.reference_1} : {}),
          ...(b.reference_2 !== undefined ? {reference_2: b.reference_2} : {}) } as SandboxBill;
      };
      return await Promise.race([operation(), timeout]);
    } catch { throw providerFailure(); }
    finally { if (timer !== undefined) clearTimeout(timer); }
  }
}

export function verifyBillplzCallback(rawBody: Buffer, signatureKey: string): Record<string, string> {
  const failure = () => new DomainError('unauthenticated', 'Payment verification failed.');
  if (!Buffer.isBuffer(rawBody) || rawBody.length === 0 || rawBody.length > 65536 || typeof signatureKey !== 'string' || !signatureKey) throw failure();
  const fields: Record<string, string> = Object.create(null) as Record<string, string>;
  let signature: string | undefined;
  try {
    const raw = new TextDecoder('utf-8', { fatal: true }).decode(rawBody);
    // URLSearchParams tolerates invalid escapes; payment payloads must not.
    if (/%(?![0-9a-fA-F]{2})/.test(raw)) throw failure();
    for (const [key, value] of new URLSearchParams(raw)) {
      if (!/^[a-zA-Z][a-zA-Z0-9_]*$/.test(key) || Object.hasOwn(fields, key) || (key === 'x_signature' && signature !== undefined)) throw failure();
      if (key === 'x_signature') signature = value;
      else fields[key] = value;
    }
    if (!signature || !/^[a-fA-F0-9]{64}$/.test(signature) || Object.keys(fields).length === 0
      || (fields.paid !== undefined && fields.paid !== 'true' && fields.paid !== 'false')) throw failure();
    const source = Object.entries(fields).map(([key, value]) => `${key}${value}`)
      .sort((a, b) => a.toLowerCase() < b.toLowerCase() ? -1 : a.toLowerCase() > b.toLowerCase() ? 1 : 0).join('|');
    const expected = createHmac('sha256', signatureKey).update(source).digest();
    if (!timingSafeEqual(expected, Buffer.from(signature, 'hex'))) throw failure();
    return fields;
  } catch { throw failure(); }
}
