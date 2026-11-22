import { describe, expect, it, vi } from 'vitest';
import { XenditBookingGateway, xenditBookingReference } from '../src/modules/commerce/xendit-booking';

describe('Xendit booking checkout', () => {
  it.each([
    ['tng', 'TOUCHNGO', 'https://checkout-staging.xendit.co/latest/test-checkout'],
    ['visa_mastercard', 'CARDS', 'https://dev.xen.to/checkout'],
  ])('maps %s to %s', async (code, channel, url) => {
    const request = vi.fn<typeof fetch>().mockResolvedValue(Response.json({
      payment_session_id: 'ps-661f87c614802d6c402cd82d',
      reference_id: xenditBookingReference('gainpath', 'booking-1'),
      country: 'MY', currency: 'MYR', amount: 120, status: 'ACTIVE',
      session_type: 'PAY', mode: 'PAYMENT_LINK', payment_link_url: url,
    }));
    const gateway = new XenditBookingGateway('xnd_development_example', 'https://gainpath.example/return', new Set([channel]), request);
    const checkout = await gateway.create({ amountMinor: 12000, name: 'Member', email: 'member@example.com', reference: 'booking-1',
      organizationId: 'gainpath', description: 'Coaching session', selectedPaymentMethodCode: code });
    expect(checkout.url).toBe(url);
    expect(request).toHaveBeenCalledTimes(1);
    expect(JSON.parse(String(request.mock.calls[0][1]?.body)).allowed_payment_channels).toEqual([channel]);
  });
  it.each(['valid', 'missing', 'wrong_session', 'expired'])(
    'checks the original Touch n Go session once when create omits its link (%s)',
    async outcome => {
      const session = {
        payment_session_id: 'ps-661f87c614802d6c402cd82d',
        reference_id: xenditBookingReference('gainpath', 'booking-1'),
        country: 'MY', currency: 'MYR', amount: 100, status: 'ACTIVE',
        session_type: 'PAY', mode: 'PAYMENT_LINK', payment_link_url: null,
      };
      const url = 'https://dev.xen.to/checkout';
      const request = vi.fn<typeof fetch>()
        .mockResolvedValueOnce(Response.json(session))
        .mockResolvedValueOnce(Response.json({
          ...session,
          payment_session_id: outcome === 'wrong_session' ? 'ps-661f87c614802d6c402cd82e' : session.payment_session_id,
          status: outcome === 'expired' ? 'EXPIRED' : session.status,
          payment_link_url: outcome === 'missing' ? null : url,
        }));
      const gateway = new XenditBookingGateway('xnd_development_example',
        'https://gainpath.example/return', new Set(['TOUCHNGO']), request);
      const checkout = gateway.create({ amountMinor: 10000, name: 'Member', email: 'member@example.com',
        reference: 'booking-1', organizationId: 'gainpath', description: 'Coaching session',
        selectedPaymentMethodCode: 'tng' });
      if (outcome === 'valid') await expect(checkout).resolves.toMatchObject({ url, paid: false });
      else await expect(checkout).rejects.toThrow('Payment is temporarily unavailable.');
      expect(request.mock.calls.map(([url, init]) => [url, init?.method])).toEqual([
        ['https://api.xendit.co/sessions', 'POST'],
        [`https://api.xendit.co/sessions/${session.payment_session_id}`, 'GET'],
      ]);
    },
  );

  it('opens only the selected channel and verifies completion through the provider', async () => {
    const reference = xenditBookingReference('gainpath', 'booking-1');
    const session = {
      payment_session_id: 'ps-661f87c614802d6c402cd82d', reference_id: reference,
      country: 'MY', currency: 'MYR', amount: 125.50, status: 'ACTIVE',
      session_type: 'PAY', mode: 'PAYMENT_LINK', capture_method: 'AUTOMATIC',
      payment_link_url: 'https://checkout-staging.xendit.co/sessions/ps-661f87c614802d6c402cd82d',
    };
    const request = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(Response.json({ ...session, capture_method: undefined }))
      .mockResolvedValueOnce(Response.json({ ...session, status: 'COMPLETED', payment_id: 'py-test' }));
    const gateway = new XenditBookingGateway('xnd_development_example', 'https://gainpath.example/return', new Set(['CIMB_FPX']), request);
    const checkout = await gateway.create({ amountMinor: 12550, name: 'Member', email: 'member@example.com',
      reference: 'booking-1', organizationId: 'gainpath', description: 'Coaching session', selectedPaymentMethodCode: 'cimbclicks' });
    expect(JSON.parse(String(request.mock.calls[0][1]?.body))).toMatchObject({
      amount: 125.5, country: 'MY', currency: 'MYR', allowed_payment_channels: ['CIMB_FPX'],
    });
    expect(checkout).toMatchObject({ paid: false, amount: 12550, reference_1: reference, url: session.payment_link_url });
    expect(await gateway.get(checkout.id)).toMatchObject({ paid: true, paid_amount: 12550 });
    await expect(gateway.create({ amountMinor: 12550, name: 'Member', email: 'member@example.com',
      reference: 'booking-1', organizationId: 'gainpath', description: 'Coaching session', selectedPaymentMethodCode: 'tng' })).rejects.toThrow();
    expect(request).toHaveBeenCalledTimes(2);
  });
});
