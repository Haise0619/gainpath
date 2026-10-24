import { expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds } from './booking-fixture';
import { coachRatings } from '../src/modules/coaching/coach-rating-service';
it('aggregates persisted legacy and new reviews, including honest unrated state', async () => {
  const store = new MemoryStore(); for (const [p,d] of Object.entries(seeds)) store.documents.set(p, structuredClone(d));
  const input = { schemaVersion: 1, organizationId: 'org-1', coachIds: ['coach-1'] };
  const auth = { uid: 'member-1', token: { email_verified: true } };
  expect(await coachRatings(store, auth, input, { aggregate: async () => ({ count: 2, total: 9 }) })).toMatchObject({ records: [{ coachId: 'coach-1', averageRating: 4.5, reviewCount: 2 }] });
  expect(await coachRatings(store, auth, input, { aggregate: async () => ({ count: 0, total: 0 }) })).toMatchObject({ records: [{ averageRating: null, reviewCount: 0 }] });
  await expect(coachRatings(store, undefined, input, { aggregate: async () => ({ count: 0, total: 0 }) })).rejects.toThrow('Sign in');
});
