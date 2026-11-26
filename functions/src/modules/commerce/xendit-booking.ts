import { DomainError } from '../../platform/errors';
import { keyOf } from '../../platform/idempotency';
import type { BookingCheckoutInput, BillplzGateway, SandboxBill } from './billplz-sandbox';

const channels = new Map([
  ['cimbclicks', 'CIMB_FPX'],
  ['tng', 'TOUCHNGO'],
  ['grabpay', 'GRABPAY'],
  ['shopeepay', 'SHOPEEPAY'],
  ['visa_mastercard', 'CARDS'],
]);

export const xenditBookingReference = (org: string, bookingId: string) =>
  keyOf('xendit-booking', org, bookingId);

export function isBookingPaymentProvider(provider: unknown): boolean {
  return provider === 'billplz' || provider === 'xendit';
}

function inspectCheckoutUrl(value: unknown) {
  const present = value != null && value !== '';
  if (!present) return { present, reason: 'missing' };
  if (typeof value !== 'string') return { present, reason: 'not_a_string' };
  try {
    const url = new URL(value);
    const short = ['dev.xen.to', 'xen.to'].includes(url.hostname);
    const staging = url.hostname === 'checkout-staging.xendit.co';
    const hosted = staging || url.hostname === 'checkout.xendit.co';
    const domain = short || hosted ? url.hostname : 'unrecognized';
    const pathType = /^\/sessions\/ps-[a-f0-9]{24}\/?$/.test(url.pathname)
      ? 'session' : url.pathname.startsWith('/sessions/')
        ? 'other_session_path' : url.pathname.length > 1 ? 'nonempty' : 'empty';
    const reason = url.protocol !== 'https:' ? 'non_https'
      : url.username || url.password || url.port ? 'credentials_or_port'
      : !short && !hosted ? 'unrecognized_domain'
      : ((short || staging) && pathType === 'empty')
        || (hosted && !staging && pathType !== 'session')
        ? 'unexpected_path' : 'valid';
    return { present, domain, pathType, reason };
  } catch {
    return { present, reason: 'invalid_url' };
  }
}

const unavailable = () => new DomainError('unavailable', 'Payment is temporarily unavailable.');

export class XenditBookingGateway implements BillplzGateway {
  readonly provider = 'xendit';
  constructor(
    private readonly apiKey: string,
    private readonly returnUrl: string,
    private readonly enabledChannels: ReadonlySet<string>,
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  acceptsSelection(code: string): boolean {
    const channel = channels.get(code);
    return channel !== undefined && this.enabledChannels.has(channel);
  }

  async create(input: BookingCheckoutInput): Promise<SandboxBill> {
    const channel = channels.get(input.selectedPaymentMethodCode ?? '');
    const allowed = input.chooseMethodAtCheckout && input.selectedPaymentMethodCode === undefined
      ? [...channels.values()].filter(code => this.enabledChannels.has(code))
      : channel && this.enabledChannels.has(channel) ? [channel] : [];
    if (allowed.length === 0) {
      throw new DomainError('invalid-argument', 'Choose an available payment method.');
    }
    const reference = xenditBookingReference(input.organizationId, input.reference);
    let session = await this.request('/sessions', {
      method: 'POST',
      body: JSON.stringify({
        reference_id: reference, session_type: 'PAY', mode: 'PAYMENT_LINK',
        capture_method: 'AUTOMATIC', allow_save_payment_method: 'DISABLED',
        country: 'MY', currency: 'MYR', amount: input.amountMinor / 100,
        allowed_payment_channels: allowed,
        description: input.description,
        success_return_url: this.returnUrl, cancel_return_url: this.returnUrl,
      }),
    }, channel);
    if (session.reference_1 === reference && session.amount === input.amountMinor
      && session.state === 'due' && !session.url) {
      const originalId = session.id;
      session = await this.request(`/sessions/${originalId}`, { method: 'GET' }, channel);
      if (session.id !== originalId) throw unavailable();
    }
    if (session.reference_1 !== reference || session.amount !== input.amountMinor
      || session.state !== 'due' || !session.url) {
      console.warn('Xendit checkout response cannot be used', {
        channel, referenceMatches: session.reference_1 === reference,
        amountMatches: session.amount === input.amountMinor,
        state: session.state, hasValidCheckoutUrl: Boolean(session.url),
      });
      throw unavailable();
    }
    return session;
  }

  async get(id: string): Promise<SandboxBill> {
    if (!/^ps-[a-f0-9]{24}$/.test(id)) throw unavailable();
    const session = await this.request(`/sessions/${id}`, { method: 'GET' });
    if (session.id !== id) throw unavailable();
    return session;
  }

  private async request(path: string, init: RequestInit, channel?: string): Promise<SandboxBill> {
    if (!/^xnd_development_[A-Za-z0-9_-]+$/.test(this.apiKey)) throw unavailable();
    try {
      const response = await this.fetcher(`https://api.xendit.co${path}`, {
        ...init, redirect: 'error', signal: AbortSignal.timeout(10000),
        headers: {
          Authorization: `Basic ${Buffer.from(`${this.apiKey}:`).toString('base64')}`,
          'Content-Type': 'application/json',
        },
      });
      if (!response.ok) {
        const body = await response.json().catch(() => null) as { error_code?: unknown } | null;
        const code = body?.error_code;
        console.warn('Xendit session request rejected', {
          channel, method: init.method, status: response.status,
          providerCode: typeof code === 'string' && /^[A-Z][A-Z0-9_]{1,63}$/.test(code) ? code : undefined,
        });
        throw unavailable();
      }
      const s = await response.json() as Record<string, unknown>;
      const amount = typeof s.amount === 'number' ? Math.round(s.amount * 100) : 0;
      const paid = s.status === 'COMPLETED';
      if (typeof s.payment_session_id !== 'string' || !/^ps-[a-f0-9]{24}$/.test(s.payment_session_id)
        || typeof s.reference_id !== 'string' || !/^[a-f0-9]{64}$/.test(s.reference_id)
        || s.country !== 'MY' || s.currency !== 'MYR' || s.session_type !== 'PAY'
        || s.mode !== 'PAYMENT_LINK' || (s.capture_method != null && s.capture_method !== 'AUTOMATIC')
        || !Number.isSafeInteger(amount) || amount <= 0 || amount / 100 !== s.amount
        || !['ACTIVE', 'COMPLETED', 'EXPIRED', 'CANCELED'].includes(String(s.status))) {
        console.warn('Xendit session response failed validation', { channel, method: init.method });
        throw unavailable();
      }
      const link = inspectCheckoutUrl(s.payment_link_url);
      if (channel && link.reason !== 'valid') {
        console.warn('Xendit checkout URL failed validation', { channel, ...link });
      }
      return {
        id: s.payment_session_id, collection_id: 'xendit', amount, paid, paid_amount: paid ? amount : 0,
        state: paid ? 'paid' : s.status === 'ACTIVE' ? 'due' : 'deleted',
        url: link.reason === 'valid' && typeof s.payment_link_url === 'string' ? s.payment_link_url : '', reference_1: s.reference_id,
      };
    } catch (error) {
      if (!(error instanceof DomainError)) {
        console.warn('Xendit session response unavailable', { channel, method: init.method });
      }
      throw unavailable();
    }
  }
}
