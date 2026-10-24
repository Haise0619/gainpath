import { createServer } from 'node:http';
import { expect, it } from 'vitest';
import { getCoachCertificationsCommand, getCoachPublishedPhotoCommand } from '../src/modules/coaching/coach-management-callables';
import { listAdminBookingPaymentsCommand, getAdminBookingPaymentCommand } from '../src/modules/commerce/booking-payment-admin-callables';

it.each([
  ['certifications', getCoachCertificationsCommand], ['photo', getCoachPublishedPhotoCommand],
  ['payment list', listAdminBookingPaymentsCommand], ['payment detail', getAdminBookingPaymentCommand],
] as const)('retains actual HTTP App Check rejection before the %s read handler', async (_, command) => {
  expect(command.__endpoint.secretEnvironmentVariables ?? []).toEqual([]);
  const express = require(require.resolve('express', { paths: [require.resolve('firebase-functions')] }));
  const app = express(); app.use(express.json()); app.post('/', command);
  const server = createServer(app);
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address(); if (!address || typeof address === 'string') throw Error('Loopback endpoint required');
    const response = await fetch(`http://127.0.0.1:${address.port}`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ data: { schemaVersion: 1, organizationId: 'batch-org' } }),
    });
    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({ error: { status: 'UNAUTHENTICATED' } });
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
});
