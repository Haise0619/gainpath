import { createServer } from 'node:http';
import { expect, it } from 'vitest';
import { getBookingListCommand } from '../src/modules/coaching/booking-read-callables';
import { getCoachAvailabilityCommand } from '../src/modules/coaching/coach-availability-callables';
import { getBookingListReadCommand, getCoachAvailabilityReadCommand } from '../src/modules/coaching/regional-booking-reads';

it.each([
  [getBookingListCommand, getBookingListReadCommand],
  [getCoachAvailabilityCommand, getCoachAvailabilityReadCommand],
])('retains the US endpoint while preparing an isolated regional read (%#)', (original, regional) => {
  const prior = JSON.parse(JSON.stringify(original.__endpoint));
  const next = JSON.parse(JSON.stringify(regional.__endpoint));
  expect(next.region).toEqual(['asia-southeast1']);
  delete next.region;
  expect(next).toEqual(prior);
  expect(prior.region).toBeUndefined();
});

it.each([getBookingListReadCommand, getCoachAvailabilityReadCommand])('rejects requests without App Check before the trusted handler (%#)', async command => {
  const express = require(require.resolve('express', { paths: [require.resolve('firebase-functions')] }));
  const app = express(); app.use(express.json()); app.post('/', command);
  const server = createServer(app);
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address();
    if (!address || typeof address === 'string') throw Error('Expected loopback port');
    const response = await fetch(`http://127.0.0.1:${address.port}`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ data: { schemaVersion: 1, organizationId: 'gainpath' } }),
    });
    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({ error: { status: 'UNAUTHENTICATED' } });
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
});
