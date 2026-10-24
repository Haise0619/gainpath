import { createServer } from 'node:http';
import { expect, it } from 'vitest';
import { getCoachRatingsCommand } from '../src/modules/coaching/coach-rating-callable';
import { getCoachRatingsPilotCommand } from '../src/modules/coaching/coach-rating-pilot-callable';

it('declares an isolated Singapore callable while retaining the US handler runtime settings', () => {
  const original = JSON.parse(JSON.stringify(getCoachRatingsCommand.__endpoint));
  const pilot = JSON.parse(JSON.stringify(getCoachRatingsPilotCommand.__endpoint));
  expect(pilot.region).toEqual(['asia-southeast1']);
  delete pilot.region;
  expect(pilot).toEqual(original);
  expect(original.region).toBeUndefined(); // Existing US default stays unchanged.
});
it.each([getCoachRatingsCommand, getCoachRatingsPilotCommand])('retains the actual callable App Check rejection boundary (%#)', async command => {
  // Use the same Express request parsing as the Functions host. Resolve its
  // installed dependency without adding a separate application dependency.
  const express = require(require.resolve('express', { paths: [require.resolve('firebase-functions')] }));
  const app = express();
  app.use(express.json());
  app.post('/', command);
  const server = createServer(app);
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const address = server.address();
    if (!address || typeof address === 'string') throw Error('Expected loopback port');
    const response = await fetch(`http://127.0.0.1:${address.port}`, {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ data: { schemaVersion: 1, organizationId: 'org', coachIds: ['coach'] } }),
    });
    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({ error: { status: 'UNAUTHENTICATED' } });
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
});
