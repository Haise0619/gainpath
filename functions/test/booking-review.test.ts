import { describe, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now, start } from './booking-fixture';
import { submitBookingReview } from '../src/modules/coaching/booking-review-service';

describe('submitBookingReview', () => {
  const org = 'org-1';
  const memberUid = 'member-1';
  const coachUid = 'coach-1';
  const bookingId = 'booking-1';

  function setupStore(status = 'completed') {
    const store = new MemoryStore();
    Object.entries(seeds).forEach(([p, d]) => store.documents.set(p, structuredClone(d)));

    store.documents.set(`orgs/${org}/bookings/${bookingId}`, {
      schemaVersion: 1,
      bookingId,
      organizationId: org,
      memberId: memberUid,
      coachId: coachUid,
      branchId: 'branch-1',
      requestId: 'hold-1',
      createdBy: memberUid,
      createdAtMillis: now - 7200000,
      startAtMillis: start,
      endAtMillis: start + 3600000,
      durationMinutes: 60,
      status,
      holdExpiresAtMillis: now - 1800000,
      localDate: '2026-10-02',
      timeZone: 'Asia/Kuala_Lumpur',
      policyVersion: 'booking-v1',
    });
    store.documents.set(`orgs/${org}/bookings/${bookingId}/consultation/current`, { schemaVersion: 1, bookingId, memberId: memberUid, coachId: coachUid });
    return store;
  }

  const memberAuth = { uid: memberUid, token: { email_verified: true } };

  it('rejects caller without verified email', async () => {
    const store = setupStore();
    await expect(
      submitBookingReview(store, { uid: memberUid, token: { email_verified: false } }, {
        schemaVersion: 1,
        organizationId: org,
        bookingId,
        requestId: 'req-1',
        stars: 5,
      })
    ).rejects.toThrow('Verify the account email before continuing.');
  });

  it('rejects review on non-completed booking', async () => {
    const store = setupStore('confirmed');
    await expect(
      submitBookingReview(store, memberAuth, {
        schemaVersion: 1,
        organizationId: org,
        bookingId,
        requestId: 'req-1',
        stars: 5,
      })
    ).rejects.toThrow('Only completed sessions can be reviewed.');
  });

  it('successfully creates review and mirrors to coach reviews', async () => {
    const store = setupStore('completed');
    const res = await submitBookingReview(store, memberAuth, {
      schemaVersion: 1,
      organizationId: org,
      bookingId,
      requestId: 'req-1',
      stars: 5,
      reviewText: 'Great form tips and cueing!',
    });

    expect(res.stars).toBe(5);
    expect(res.bookingId).toBe(bookingId);
    expect(store.documents.has(`orgs/${org}/bookings/${bookingId}/review/current`)).toBe(true);
    expect(store.documents.has(`orgs/${org}/coaches/${coachUid}/reviews/${bookingId}`)).toBe(true);
  });

  it('rejects duplicate review on same booking', async () => {
    const store = setupStore('completed');
    await submitBookingReview(store, memberAuth, {
      schemaVersion: 1,
      organizationId: org,
      bookingId,
      requestId: 'req-1',
      stars: 5,
      reviewText: 'Great session',
    });

    await expect(
      submitBookingReview(store, memberAuth, {
        schemaVersion: 1,
        organizationId: org,
        bookingId,
        requestId: 'req-2',
        stars: 4,
      })
    ).rejects.toThrow('already been reviewed');
  });
});
