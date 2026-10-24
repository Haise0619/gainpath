import { expect, it } from 'vitest';
import { getMembershipOverviewCommand } from '../src/modules/commerce/membership-payment-callables';

it('does not silently reset externally configured overview scaling during selective deployment', () => {
  const endpoint = JSON.parse(JSON.stringify(Reflect.get(getMembershipOverviewCommand, '__endpoint')));
  expect(Object.hasOwn(endpoint, 'maxInstances')).toBe(false);
  expect(Object.hasOwn(endpoint, 'minInstances')).toBe(false);
  expect(endpoint.platform).toBe('gcfv2');
});
